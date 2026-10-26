# Módulo performance (avaliação de desempenho)

Spec: `docs/specs/16-avaliacao-desempenho.md`. Pasta: `force-app/performance`. Branch: `feat/performance`.
Org de trabalho: `rh-w2` (com a trava `.locks/rh-w2`). Projeto demonstrativo, com empresa e dados fictícios.

## O que foi entregue

Ciclo de avaliação completo: criação do ciclo pelo RH, lançamento (idempotente, em lote acima de 200 colaboradores),
metas com peso, autoavaliação, avaliação do gestor, calibração, liberação e compartilhamento. Quatro LWCs com Jest,
páginas e abas, notificação ao abrir o ciclo e ao liberar os resultados.

### Classes Apex (18 de produção, 4 triggers)

| Classe | Papel |
|---|---|
| `ReviewCycleService` | Validação do ciclo, `launch`, `advance`, `release`, `createRecords` (sem sharing, contexto de sistema da spec 02, `requireHr()` em cada ponto de entrada) |
| `ReviewLaunchBatch` | Lançamento em lotes de 200; o ciclo só abre no `finish`, se não houve erro |
| `PerformanceReviewService` | Avaliação do gestor (`saveManagerReview`), `calibrate`, travas de Performance_Review__c; situação gravada na classe interna `Privileged` |
| `SelfAssessmentService` | `save`, `submitAssessment` e as regras A3 e A4 (no trigger) |
| `GoalService` | Metas (criar, editar, nota, cancelar) e validações |
| `PerformanceSharingService` | Shares `Manager_Chain__c` e `Employee_Release__c` em lote |
| `ReviewCycleSelector`, `GoalSelector`, `SelfAssessmentSelector`, `PerformanceReviewSelector` | Leitura `WITH USER_MODE`; métodos "ForValidation" e "ForService" em modo sistema, documentados |
| `ReviewCycleController`, `PerformanceReviewController`, `GoalController`, `SelfAssessmentController` | Controllers finos (`@AuraEnabled`) |
| `ReviewErrors` | Exceção de negócio e conversão para `AuraHandledException` |
| Triggers e handlers | `ReviewCycleTrigger`, `GoalTrigger`, `SelfAssessmentTrigger`, `PerformanceReviewTrigger` (um por objeto, sem lógica, delegam aos serviços) |

Testes: `PerformanceCycleFlowTest`, `ReviewCycleServiceTest`, `SelfAssessmentGoalRulesTest`,
`PerformanceReviewServiceTest`, `PerformanceSharingServiceTest`, `PerformanceControllersTest`,
`PerformanceNoAccessTest`, mais o apoio `PerformanceTestSupport`.

### LWCs

`performanceMyCycle` (colaborador), `performanceTeamReviews` (gestor, abre o formulário), `performanceReviewForm`
(leitura de metas e autoavaliação mais formulário do gestor; aceita `reviewId` e `recordId`), `performanceCycleAdmin`
(painel do RH com contagens, avançar fase, calibrar, liberar e criar ciclo). Páginas de aplicativo
`RH_Desempenho_Meu_Ciclo`, `RH_Desempenho_Equipe` e `RH_Desempenho_Admin`, cada uma com aba de mesmo nome.

### Metadados novos

Campo `Performance_Review__c.Final_Rating__c` (Number 1,0) e tipo de notificação `HR_Performance_Update`. Os três
permission sets ganharam `classAccesses`, `tabSettings` e a FLS do campo novo (somente leitura).

## Critérios de aceite

- [x] Ciclo completo em teste: lançar, metas com 100%, autoavaliação, avaliação do gestor, calibração, liberação;
      colaborador só lê a avaliação depois da liberação (`PerformanceCycleFlowTest.fullCycleFromLaunchToRelease`).
- [x] A3, A4, A5 com testes negativos (`SelfAssessmentGoalRulesTest`, `PerformanceReviewServiceTest`).
- [x] Lançamento idempotente e com 200 colaboradores (`ReviewCycleServiceTest.createRecordsIsIdempotent`,
      `createRecordsHandlesTwoHundredEmployees`) e caminho de lote (`launchAboveLimitRunsInBatch...`).
- [x] Segurança: colaborador não lê `Calibrated_Rating__c` (consulta `WITH USER_MODE` falha e `stripInaccessible` remove
      o campo); gestor de outra equipe não vê avaliações; colega não vê; usuário sem permission set não recebe dado.
- [x] Jest para os 4 LWCs (38 testes).
- [x] Gates da spec 03: deploy sem erro em rh-w2, testes Apex 100% passando, cobertura por classe acima de 85%
      (mínimo 90%), Jest, Code Analyzer sem violação de severidade 1 ou 2, sem travessão, sem emoji.
- [ ] Revisão com a skill `sf-code-reviewer`: feita como revisão manual contra a mesma lista (bulkificação, SOQL em
      loop, injeção, CRUD/FLS, sharing, limites, cobertura); a skill não foi invocada como ferramenta nesta sessão.

## Números

- Apex: 57 testes, 57 passando (rh-w2). Cobertura por classe do módulo: 90% a 100% (menores: `GoalController` 90%,
  `ReviewErrors` 92%, `PerformanceReviewController` 96%).
- Jest: 4 suítes, 38 testes passando.
- Code Analyzer (`pmd:Recommended`): zero severidade 1 ou 2. Restam avisos de severidade 3 e 4 (ApexDoc,
  complexidade ciclomática e lista de parâmetros dos controllers e do serviço), sem impacto funcional.
- ESLint dos LWCs limpo (com `--no-eslintrc -c .eslintrc.json`, porque o worktree aninhado duplica o plugin `import`).

## Decisões tomadas

1. **Concluir o ciclo só pela liberação.** `advance` cobre Autoavaliação para Avaliação do gestor e para Calibração;
   de Calibração o ciclo só sai por `release` (que o conclui). A spec lista "Concluido" na cadeia de A2, mas A7 diz que a
   liberação é quem conclui; liberar zero avaliações é recusado.
2. **Situação do ciclo só muda pelo painel.** O trigger recusa edição direta de `Status__c` do ciclo (flag estática
   fechada fora de `setStatus`). Todo ciclo nasce Planejado; escala de 2 a 9 (o campo é Number 1,0) e travada após o lançamento.
3. **Nota final.** O colaborador precisa ver a "nota final = calibrada, se houver", mas não pode ler
   `Calibrated_Rating__c` (campo [S]). Em vez de ler em modo sistema na tela, foi criado `Final_Rating__c`, gravado
   apenas na liberação (calibrada ou, na falta dela, a do gestor), legível por colaborador e gestor. O campo calibrado
   segue restrito ao RH por FLS.
4. **Colaborador elegível.** Status `Ativo` ou `Ferias`, com `User__c`. Colaborador sem gestor com usuário (o topo da
   árvore) recebe a avaliação com `Reviewer__c` vazio; ela fica Pendente e o painel mostra "sem avaliador".
5. **Remover meta = cancelar.** O colaborador não tem Delete em Goal__c (spec 02); cancelar tira a meta da soma de 100%.
   Só metas `Ativa` entram na soma. Metas editáveis em Planejado e Autoavaliação, até o envio da autoavaliação; o RH
   corrige a qualquer momento.
6. **Prazos informativos.** `Self_Review_Due__c` e `Manager_Review_Due__c` aparecem na tela e na validação de datas,
   mas não bloqueiam gravação: quem fecha a fase é o RH (A2).
7. **Regras no trigger.** As regras de edição (A3, A4, A5) vivem nos serviços chamados pelos handlers, para valer
   também fora das telas (edição direta na API, registro padrão). Os serviços só gravam como o usuário e deixam a
   validação responder; os controllers traduzem `DmlException` em mensagem amigável.
8. **Sharing.** Avaliador: Edit enquanto Pendente ou Em andamento, Read depois; resto da cadeia: Read
   (`Manager_Chain__c`); colaborador: Read após Liberada (`Employee_Release__c`). A cadeia é resolvida em lote pelo
   `Hierarchy_Path__c` (duas consultas para qualquer quantidade de avaliações).
9. **Aviso de 100%.** O LWC avisa enquanto a soma não fecha; o servidor repete a regra no envio (A4).
10. **Usuários de teste.** O `orgTree` entrega usuário de gestor 1 (HR_Manager), colaboradores 1 e 2 (HR_Employee) e RH.
    Quando o colaborador 1 é avaliador (do colaborador 4), o teste concede o grupo HR_Manager a ele
    (`PerformanceTestSupport.grantManager`).

## Pendências e limites conhecidos

- Trocar o gestor de um colaborador depois do lançamento não recalcula `Reviewer__c` nem os shares das avaliações
  abertas. O RH pode trocar o avaliador pelo registro (somente antes do envio), o que recalcula os shares.
- Um usuário de RH que também é colaborador é dono da própria avaliação (o RH lança o ciclo) e portanto a enxerga antes
  da liberação. Mitigação possível: atribuir o dono a uma fila.
- A liberação roda em uma transação (cerca de 5000 avaliações no limite de DML com os shares); acima disso seria
  preciso Batch.
- A página de registro do formulário (`performanceReviewForm` em `lightning__RecordPage`) está exposta, mas sem
  FlexiPage de registro criada.

## Pedidos ao orquestrador

1. Incluir as abas `RH_Desempenho_Admin` (RH) e `RH_Desempenho_Equipe`/`RH_Desempenho_Meu_Ciclo` no app `RH_Core`
   (arquivo do core) e, quando existir, no app Meu RH (módulo myhr). Os LWCs também podem ser arrastados em qualquer página.
2. O `HR_Performance_Employee` e o `HR_Performance_Manager` não têm FLS no `Final_Rating__c` além de leitura, por
   desenho. Nenhuma mudança no core foi necessária.
3. Em sandbox de integração, rodar `RunLocalTests`: os testes do módulo criam usuários pelo `HrTestDataFactory`
   (limite de 4 por método respeitado).

## Como reproduzir

```
sf project deploy start --source-dir force-app/performance --target-org rh-w2 --ignore-conflicts --wait 30
sf apex run test --target-org rh-w2 --code-coverage --result-format json --wait 30 --class-names \
  PerformanceCycleFlowTest ReviewCycleServiceTest SelfAssessmentGoalRulesTest PerformanceReviewServiceTest \
  PerformanceSharingServiceTest PerformanceControllersTest PerformanceNoAccessTest
npm run test:unit -- force-app/performance
sf code-analyzer run --workspace force-app/performance --rule-selector pmd:Recommended --severity-threshold 2
```

`--ignore-conflicts` é necessário porque o rastreamento de código-fonte da scratch org vê o deploy anterior do
`force-app` completo como alteração remota.
