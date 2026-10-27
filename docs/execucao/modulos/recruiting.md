# Módulo recruiting (spec 13)

Branch `feat/recruiting`. Org de trabalho `rh-w2`. Projeto demonstrativo, empresa e dados fictícios.

## O que foi entregue

- Vagas com identificador público gerado do título (C7), datas de abertura e encerramento, contagem de candidaturas (C8).
- Candidatos únicos por e-mail normalizado (C4), com cadastro reaproveitando a pessoa (`CandidateService.upsertByEmail`).
- Candidaturas únicas por candidato e vaga (C5), só em vaga Aberta (C6), com dono na fila `HR_Recruiting_Queue`.
- Máquina de etapas guiada por `Recruiting_Stage__mdt` (C1, C2), validada no trigger (vale para tela, API, Flow e kanban).
- Histórico de etapas com dias na etapa anterior e observação (C3). Campo novo `Application_Stage_History__c.Note__c`.
- Encerramento da vaga reprova as candidaturas em andamento com motivo Outro e observação "Vaga encerrada" (C6).
- Compartilhamento com o gestor contratante (C9): Edit na candidatura e Read no candidato, refeito quando o gestor da vaga muda.
- Aviso de contratação ao módulo de admissão pela interface `HiredApplicationHandler` (C10).
- Retenção LGPD semanal (`CandidateRetentionBatch`, C11).
- LWC `recruitingKanban`, `recruitingApplicationPanel` e `recruitingOpeningSummary`; app "RH Recrutamento", aba "Funil de recrutamento" e páginas de registro de vaga e candidatura.

## Checklist dos critérios de aceite

- [x] Transições válidas e inválidas, C2, C4, C5, C6 e C11 testados (positivo e negativo): `JobApplicationStageTest`, `JobApplicationLifecycleTest`, `CandidateServiceTest`, `CandidateRetentionBatchTest`.
- [x] Lote de 200 candidaturas mudando de etapa: por DML direto (`bulkOf200ApplicationsMovesInOneDml`) e pelo serviço (`bulkOf200ThroughTheServiceIsAllOrNothing`). Retenção com 200 candidatos também.
- [x] Segurança: gestor contratante vê só candidaturas das próprias vagas; colaborador comum não vê candidato nenhum (`RecruitingSecurityTest`).
- [x] Jest para os 3 LWCs, incluindo erro do servidor ao mover.
- [x] Gates da spec 03: deploy sem erro em rh-w2; testes Apex 100% e cobertura por classe acima de 85%; Jest; Code Analyzer sem severidade 1 ou 2; sem travessão nem emoji. Revisão `sf-code-reviewer` sem achado grave. Ressalva: ESLint no worktree precisa de `--resolve-plugins-relative-to .` (há outro `node_modules` no diretório pai, conflito de plugin); com a flag passa limpo.

## Classes, triggers e LWC

Apex: `RecruitingStageConfig`, `RecruitingQueue`, `HiredApplicationHandler` (interface), `JobOpeningSelector`, `JobOpeningService`, `JobOpeningTriggerHandler`, `CandidateSelector`, `CandidateService`, `CandidateTriggerHandler`, `JobApplicationSelector`, `JobApplicationService`, `JobApplicationTriggerHandler`, `RecruitingSharingService`, `RecruitingSharingRecalcBatch`, `CandidateRetentionBatch` (Batchable e Schedulable), `RecruitingKanbanController`, `RecruitingInsightsController`.
Triggers: `JobOpeningTrigger`, `CandidateTrigger`, `JobApplicationTrigger`.
Testes: `RecruitingTestData` (apoio), `RecruitingStageConfigTest`, `JobOpeningServiceTest`, `CandidateServiceTest`, `JobApplicationStageTest`, `JobApplicationLifecycleTest`, `RecruitingSharingTest`, `RecruitingSecurityTest`, `CandidateRetentionBatchTest`, `RecruitingControllersTest`.
LWC: `recruitingKanban`, `recruitingApplicationPanel`, `recruitingOpeningSummary`.
Metadados novos: app `RH_Recrutamento`, aba `RH_Funil`, FlexiPages `RH_Funil`, `Job_Opening_Record_Page`, `Job_Application_Record_Page` (padrão do objeto via `actionOverrides`).

## Serviços para o portal (spec 14) e a admissão (spec 15)

- `CandidateService.upsertByEmail(CandidateInput)` e versão em lote: cadastra ou reaproveita candidato; não sobrescreve dado existente (só preenche vazios, registra consentimento e renova atividade).
- `JobApplicationService.apply(CandidateInput, openingId, source, coverLetter)`: candidato mais candidatura em um savepoint; erros viram `JobApplicationService.RecruitingException` com a mensagem da regra. Chamar de um controller `without sharing` (o portal): o serviço herda o modo de quem chama e isola o que precisa de sistema.
- `JobApplicationService.changeStage/changeStages`, `rate`, `onHired`.
- `CandidateService.anonymize(Set<Id>)` e `CandidateRetentionBatch.schedule()`.
- Admissão: implementar `HiredApplicationHandler` na classe `OnboardingHiredHandler`; é resolvida por `Type.forName` (nome em `JobApplicationService.HIRED_HANDLER_CLASS`). Exceção da implementação propaga e desfaz a contratação.

## Números

- Testes Apex: 81, 100% passando (rh-w2).
- Cobertura por classe: CandidateRetentionBatch 100, CandidateSelector 100, CandidateService 96, CandidateTrigger 100, CandidateTriggerHandler 92, JobApplicationSelector 100, JobApplicationService 93, JobApplicationTrigger 100, JobApplicationTriggerHandler 97, JobOpeningSelector 100, JobOpeningService 99, JobOpeningTrigger 100, JobOpeningTriggerHandler 100, RecruitingInsightsController 100, RecruitingKanbanController 95, RecruitingQueue 91, RecruitingSharingRecalcBatch 100, RecruitingSharingService 97, RecruitingStageConfig 100.
- Jest: 3 suítes, 24 testes.
- Code Analyzer (pmd:Recommended): 0 violações de severidade 1 ou 2; restam avisos de severidade 3 e 4 (complexidade, ApexDoc, parâmetros).

## Decisões

1. A validação de etapa fica no trigger de `Job_Application__c`, não só no serviço: o recrutador tem Stage__c editável na tela e a regra precisa valer em qualquer caminho. O serviço valida antes do DML só para devolver mensagem limpa.
2. `Stage__c` é somente leitura por FLS para o gestor contratante; `JobApplicationService.changeStages` grava em modo sistema depois de checar acesso ao registro (consulta em USER_MODE), permissão de edição do objeto e a transição. Comentado no código. A nota (`rate`) é gravada `as user`.
3. "Exige nota" e "exige motivo" são lidos como exigência ao entrar na etapa (Proposta exige nota; Reprovado exige motivo), conforme os campos da CMDT.
4. Toda candidatura nova começa na primeira etapa da CMDT; inserir direto em outra etapa é recusado. Isso gera um histórico inicial (De vazio, Para Nova). Quem precisar semear candidaturas em etapas avançadas deve avançar por update (gera histórico real) ou usar `TriggerHandler.bypass('JobApplicationTriggerHandler')`.
5. `Stage_Entered_Date__c` é mantido pelo trigger; edição manual é ignorada. O candidato de uma candidatura não pode ser trocado; a vaga pode (refaz chave única, contagens e shares).
6. Slug gerado uma vez e estável (a URL pública não muda se o título mudar). Limite de 70 caracteres na base mais sufixo numérico.
7. `upsertByEmail` em candidato existente nunca sobrescreve dado preenchido: evita que um formulário público altere dados de outra pessoa que use o mesmo e-mail.
8. Anonimização grava o e-mail anônimo e o normalizado em minúsculo (`anon-<id em minúsculo>@anon.invalid`): o campo de e-mail do Salesforce guarda minúsculo e o normalizado é minúsculo por regra, então os dois ficam iguais. Candidato sem `Last_Activity_Date__c` usa a data de criação. Protegem da anonimização as candidaturas em etapas não terminais e em Contratado.
9. Contagem de candidaturas por consulta agregada (não por incremento), segura contra concorrência. Handler de candidatura é `without sharing` para enxergar todas as candidaturas na contagem e na chave única; serviços herdam o modo de quem chama e isolam o trecho de sistema em classes internas `without sharing`.
10. Troca de gestor contratante com mais de 1000 candidaturas na vaga vai para `RecruitingSharingRecalcBatch`; abaixo disso é síncrona. O mesmo batch serve de classe de recálculo de sharing.
11. Encerrar vaga com muitas candidaturas (acima de ~10 mil) estouraria o limite de DML; não tratado, volume irreal para o produto.
12. Permission sets: além de `classAccesses` e `tabSettings`, acrescentei `applicationVisibilities` (app novo `RH_Recrutamento`) e o `fieldPermissions` do campo novo `Note__c`. Não editei o app `RH_Core` (pasta core): as abas de recrutamento não aparecem nele, ver pedidos.
13. Nos testes de Apex o limite de 100 SOQL por método já chega com cerca de 55 consumidos no início na org (sobrecarga da plataforma/permission set groups); os testes criam candidaturas em lote e usam `RecruitingTestData` sem recargas desnecessárias.
14. Deploy no worktree exigiu `--ignore-conflicts` (rastreamento de código-fonte da org veio de outro worktree).

## Pendências

- Nenhuma de critério de aceite. Não verificado visualmente em navegador (kanban só por Jest e deploy); arrastar e soltar real e o menu Mover para devem ser conferidos na org por uma pessoa.
- Termos de LGPD e texto de consentimento ficam com o portal (spec 14); aqui só se grava o consentimento informado.

## Pedidos ao orquestrador

- Se quiser as abas de recrutamento dentro do app `RH_Core`, incluir `RH_Funil`, `Job_Opening__c`, `Candidate__c` e `Job_Application__c` na lista de abas do `RH_Core.app` (fora do meu escopo).
- Módulo onboarding: implementar `OnboardingHiredHandler implements HiredApplicationHandler`.
- Módulo portal: chamar `JobApplicationService.apply` de um controller `without sharing`; as candidaturas do portal nascem em Nova com fila como dona.
- Agendamento: executar uma vez `CandidateRetentionBatch.schedule();` em Apex anônimo na org de demonstração (não agendei nada).
- O seed (analytics) deve avançar etapas por update ou usar o bypass descrito na decisão 4. Testes que movem para Contratado devem instalar `JobApplicationService.testHandler` (ver `RecruitingTestData.useRecorder`) se o módulo de admissão estiver na org.

## Como reproduzir

```bash
# trava obrigatória da org (mkdir atômico) e libera no trap
LOCK="<raiz-do-repositorio>/.locks/rh-w2"
until mkdir "$LOCK" 2>/dev/null; do sleep 30; done; trap 'rmdir "$LOCK"' EXIT
sf project deploy start --source-dir force-app/recruiting --target-org rh-w2 --ignore-conflicts --wait 20
sf apex run test --target-org rh-w2 --code-coverage --result-format json --wait 30 \
  --class-names RecruitingStageConfigTest JobOpeningServiceTest CandidateServiceTest JobApplicationStageTest \
  JobApplicationLifecycleTest RecruitingSharingTest RecruitingSecurityTest CandidateRetentionBatchTest RecruitingControllersTest
# fora da trava
npm run test:unit -- --testPathPattern=recruiting
sf code-analyzer run --workspace force-app/recruiting --rule-selector pmd:Recommended --severity-threshold 2
npx eslint --resolve-plugins-relative-to . "force-app/recruiting/lwc/**/*.js"
```
