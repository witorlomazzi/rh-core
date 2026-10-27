# Módulo promotion: relatório de entrega

Spec: `docs/specs/12-promocoes.md`. Branch: `feat/promotion`. Org de trabalho: `rh-w1` (com trava). Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

## O que foi entregue

- Solicitação de promoção pelo gestor (equipe direta e indireta), sem acesso a salário.
- Aprovação em duas etapas pelo motor do core: gestor de segundo nível e RH (`PromotionApprovalHandler` implementa `ApprovalOutcomeHandler`).
- Etapa do RH com salário proposto validado contra a faixa do cargo novo (P6), com percentual de aumento e indicador dentro/fora da faixa.
- Efetivação imediata (data de hoje ou passada) ou agendada pelo `PromotionEffectivationBatch` (diário, `scheduleDaily()`), com histórico fechado no dia anterior e novo aberto (`Position_History__c`).
- `PositionHistoryService.createAdmission(Set<Id>)` para o seed (spec 18) e a admissão (spec 15). Idempotente.
- Compartilhamento `Approver_Chain__c` (aprovador de segundo nível e grupo HR_Team); o colaborador não lê a solicitação.
- Três LWCs, três páginas de aplicativo e três abas, todas concedidas por permission set.

## Critérios de aceite

- [x] Fluxo completo: gestor solicita, gestor do gestor aprova, RH informa salário e aprova, efetivação imediata e agendada, histórico fechado e aberto (`PromotionServiceTest.fullFlowWithScheduledEffectivation`, `immediateEffectivationAndSkippedFirstStep`).
- [x] P1, P3, P4, P6 com testes negativos (e P2 como erro e como aviso).
- [x] Segurança: colaborador não lê a solicitação; gestor não lê `Current_Salary__c` nem `Proposed_Salary__c`; outro gestor fora da cadeia não vê (`PromotionSecurityTest`, 11 testes).
- [x] Lote: 200 promoções efetivadas no batch; 200 solicitações validadas e compartilhadas pela trigger.
- [x] Jest para os 3 LWCs (32 testes). Gates da spec 03 (ver "Números").

## Classes, trigger e LWCs

Apex: `PromotionService`, `PromotionRequestSelector`, `PromotionPositionSelector`, `PromotionRequestController`, `PromotionApprovalHandler`, `PromotionSharingService`, `PromotionEffectivationBatch` (Batchable e Schedulable), `PositionHistoryService`, `PositionHistorySelector`, `PromotionRequestTriggerHandler`, trigger `PromotionRequestTrigger`.

Testes: `PromotionServiceTest`, `PromotionSecurityTest`, `PromotionSharingServiceTest`, `PositionHistoryServiceTest`, `PromotionEffectivationBatchTest`, `PromotionRequestControllerTest`, suporte `PromotionTestSupport`.

LWC: `promotionRequestForm`, `promotionHrReview` (lista pendências do RH ou abre `recordId`), `positionHistoryTimeline` (`recordId`, `employeeId` ou o próprio usuário).

Metadados: páginas `RH_Solicitar_Promocao`, `RH_Revisao_Promocoes`, `RH_Historico_Cargos` e as abas de mesmo nome.

## Números

- Apex em `rh-w1`: 66 testes, 100% passando.
- Cobertura por classe: PromotionApprovalHandler 100%, PromotionEffectivationBatch 100%, PositionHistoryService 100%, PositionHistorySelector 100%, PromotionPositionSelector 100%, PromotionRequestTriggerHandler 100%, PromotionRequestSelector 95%, PromotionSharingService 98%, PromotionRequestController 97%, PromotionService 97%.
- Jest: 3 suítes, 32 testes passando (`npx sfdx-lwc-jest -- force-app/promotion`).
- Code Analyzer (`pmd:Recommended`): nenhuma violação de severidade 1 ou 2. Restam 34 de severidade 3 e 119 de severidade 4 (complexidade, lista de parâmetros, ApexDoc, `AvoidDebugStatements`), abaixo do limiar do gate.
- Travessão e emoji: zero ocorrências na pasta do módulo.
- Revisão `sf-code-reviewer`: sem achado grave. Um achado corrigido: o salário proposto podia ficar gravado se a decisão falhasse; agora `hrDecide` usa savepoint.

## Decisões tomadas

1. **P1, P2, P4 e snapshot P5 ficam na trigger (`beforeInsert`)**, não só no serviço: impedem autopromoção e snapshot forjado por DML direto. O snapshot e o solicitante (`Requested_By__c`) sempre sobrescrevem o valor enviado. O contexto de sistema é a classe interna `PromotionService.Privileged`, comentada.
2. **P1 em lote**: não usa `EmployeeHierarchyService.isInChainOf` (duas consultas por registro, estoura com 200). Usa a mesma regra sobre `Hierarchy_Path__c` carregado, via `EmployeeSharingService.pathIds`.
3. **P4 literal**: conta apenas solicitações Pendente, na criação e quando uma passa a Pendente (`beforeUpdate`). Mensagem: "Este colaborador já tem uma solicitação de promoção pendente."
4. **P3** vale na criação e quando `Effective_Date__c` muda; a efetivação tardia pelo batch não é bloqueada e o histórico começa na data de efetivação.
5. **Efetivação tolerante**: um colaborador por chamada (um segundo pedido aprovado do mesmo colaborador fica para a próxima execução); falha de DML em um colaborador não impede os demais; só efetiva o que está Aprovado (idempotente). Histórico anterior nunca é fechado antes do próprio início.
6. **Notificações limitadas a 90 por transação** e o alvo é o registro do colaborador (gestor e colaborador o leem; a solicitação não). Escopo padrão do batch agendado: 50.
7. **Histórico de admissão** ignora colaborador sem cargo ou que já tenha qualquer histórico.
8. **Leitura do histórico com salário condicional**: `Database.queryWithBinds` em `USER_MODE` e `Salary__c` só entra na consulta se `isAccessible()`. Cumpre a intenção de `stripInaccessible` sem derrubar a consulta de quem não tem o campo.
9. **Ajuste de permission set** (permitido pela spec 02 por ser necessário): `Promotion_Request__c.Justification__c` não tinha FLS nos dois conjuntos (campo não obrigatório). Adicionado (edição) em `HR_Promotion_Manager` e `HR_Promotion_Admin`. Além de `classAccesses` e `tabSettings`.
10. **Cenário de segundo nível nos testes**: o CEO e o gestor 2 da fábrica não têm usuário, então os testes dão `HR_Promotion_Manager` aos colaboradores 1 e 2: o colaborador 1 solicita a promoção do colaborador 4 e o gestor 1 aprova. O gestor 1 solicitando para o colaborador 1 exercita a etapa pulada (decisão 5 do PROGRESSO).
11. **Limites de consulta**: o motor do core gasta muitas consultas por decisão; testes de fluxo longo usam `Test.startTest()` para dividir a transação.

## Pendências

- Nenhuma funcional. As abas novas não estão no app `RH Core` (arquivo do core).
- ESLint não executa dentro do worktree aninhado (conflito do plugin `import` entre `node_modules` do worktree e do repositório pai); o Jest passa e o lint deve rodar no repositório principal pós-merge.

## Pedidos ao orquestrador

1. **Core, `JobPositionSelector`**: seleciona `Salary_Band__c` em `USER_MODE` e falha com "No such column" para qualquer usuário sem leitura do objeto `Salary_Band__c` (todo gestor e colaborador), apesar de o permission set dar FLS no campo. Contorno aqui: `PromotionPositionSelector`. Sugestão: remover `Salary_Band__c` do selector ou criar variante sem ele; outros módulos que usarem o selector terão o mesmo erro.
2. **Core, app `RH Core`**: acrescentar as abas `RH_Solicitar_Promocao`, `RH_Revisao_Promocoes` e `RH_Historico_Cargos` à navegação.
3. **Seed (spec 18)**: chamar `PositionHistoryService.createAdmission(ids)` após criar colaboradores; solicitações de demonstração em estados avançados devem ser inseridas com `TriggerHandler.bypass('PromotionRequestTriggerHandler')` (a trigger exige que o usuário seja gestor na cadeia do colaborador). Agendar o batch com `PromotionEffectivationBatch.scheduleDaily()`.
4. **Admissão (spec 15)**: chamar `PositionHistoryService.createAdmission(Set<Id>)` ao criar o colaborador.

## Comandos para reproduzir

```
sf project deploy start --source-dir force-app/promotion --target-org rh-w1 --ignore-conflicts
sf apex run test --class-names PromotionServiceTest PromotionSecurityTest PromotionSharingServiceTest PositionHistoryServiceTest PromotionEffectivationBatchTest PromotionRequestControllerTest --code-coverage --result-format human --wait 30 --target-org rh-w1
npx sfdx-lwc-jest -- force-app/promotion
sf code-analyzer run --workspace force-app/promotion --rule-selector pmd:Recommended --severity-threshold 2
```

Use a trava `<raiz-do-repositorio>/.locks/rh-w1` antes de implantar e testar.
