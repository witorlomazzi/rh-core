# Módulo onboarding (spec 15)

Branch `feat/onboarding`. Org de trabalho `rh-w1` (com trava). Projeto demonstrativo, empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

## O que foi entregue

- Candidatura que vira Contratado cria o colaborador em Pré-admissão, o plano de onboarding e as tarefas dos 8 modelos de `Onboarding_Task_Template__mdt` (O1 a O3). Implementa `HiredApplicationHandler` (`OnboardingHiredHandler`), resolvido pelo recrutamento via `Type.forName`. Erro desfaz a contratação.
- Ativação pelo RH (O4): valida matrícula (obrigatória, até 20 caracteres, sem prefixo `PRE-`, única sem diferenciar maiúsculas), ativa o colaborador, chama `PositionHistoryService.createAdmission` e coloca o plano em andamento. Savepoint: qualquer falha desfaz tudo.
- Regra de conclusão (O5) no serviço e no trigger de tarefa (vale para DML direto): só o responsável ou o RH muda a situação. Plano vira Concluído quando nenhuma tarefa está Pendente.
- Recalculo de prazos (O6) e dos responsáveis (colaborador e gestor) das tarefas pendentes, acionado pelo RH.
- Três LWCs com abas e páginas de aplicativo: checklist, ativação e visão geral.

## Checklist dos critérios de aceite

- [x] Candidatura Contratado cria colaborador e plano com 8 tarefas e datas corretas; reexecutar não duplica; lote de 50 contratações (`OnboardingServiceTest.hiredApplicationCreatesEmployeePlanAndEightTasks`, `runningAgainDoesNotDuplicateAnything`, `OnboardingBulkTest.fiftyHiresInOneStageChangeCreateFiftyPlansWithEightTasksEach`).
- [x] Ativação valida matrícula e cria histórico de admissão (`activationCompletesTheAdmission`, `activationValidatesTheRequest`).
- [x] O5 com teste negativo: outro usuário não conclui tarefa alheia, pelo serviço e por DML direto (`hrCanChangeAnyTaskButOthersCannotChangeTasksTheyDoNotOwn`, `OnboardingSecurityTest.directUpdateOfSomeoneElsesTaskIsRefusedByTheTrigger`).
- [x] Jest para os 3 LWCs. Gates da spec 03 (ver números).

## Classes, trigger e LWCs

Apex: `OnboardingService`, `OnboardingHiredHandler`, `OnboardingTemplateConfig`, `OnboardingPlanSelector`, `OnboardingTaskSelector`, `OnboardingController`, `OnboardingTaskTriggerHandler`, trigger `OnboardingTaskTrigger`.
Testes: `OnboardingServiceTest` (23), `OnboardingSecurityTest` (6), `OnboardingBulkTest` (3), `OnboardingControllerTest` (4), `OnboardingTemplateConfigTest` (4), apoio `OnboardingTestSupport`.
LWC: `onboardingChecklist` (recordId de Employee__c ou Onboarding_Plan__c; sem recordId mostra o plano do usuário atual), `onboardingActivation`, `onboardingOverview` (abre o checklist do plano escolhido).
Metadados: campo novo `Onboarding_Task__c.Due_Offset_Days__c`; FlexiPages e abas `RH_Onboarding_Visao_Geral`, `RH_Onboarding_Ativacao`, `RH_Onboarding_Meu`; `classAccesses` e `tabSettings` nos dois permission sets.

## Números

- Apex em `rh-w1`: 40 métodos de teste (44 execuções contando os 4 `@TestSetup`), 100% passando. Os 81 testes do recrutamento seguem 100% com o onboarding instalado.
- Cobertura por classe: OnboardingService 96, OnboardingController 94, OnboardingTaskTriggerHandler 100, OnboardingTaskSelector 100, OnboardingPlanSelector 100, OnboardingTemplateConfig 100, OnboardingHiredHandler 100, OnboardingTaskTrigger 100.
- Jest: 3 suítes, 26 testes (`npx sfdx-lwc-jest -- force-app/onboarding`). ESLint limpo (`npx eslint --resolve-plugins-relative-to . "force-app/onboarding/lwc/**/*.js"`).
- Code Analyzer (`pmd:Recommended`): 0 violações de severidade 1 ou 2; restam 34 de severidade 3 e 105 de severidade 4 (ApexDoc, complexidade, `ApexUnitTestClassShouldHaveRunAs` nos testes puros de configuração).
- Travessão e emoji: zero ocorrências na pasta do módulo.
- Revisão `sf-code-reviewer` (feita sobre `develop...HEAD`, só `force-app/onboarding` alterada): sem achado grave.

## Decisões tomadas

1. **Campo novo `Due_Offset_Days__c` na tarefa**: guarda o prazo em dias copiado do modelo, para recalcular as datas (O6) mesmo que o Custom Metadata mude depois. FLS: leitura no conjunto do colaborador, edição no do RH (ajuste de permission set além de `classAccesses` e `tabSettings`, necessário pelo campo novo).
2. **O6 sem trigger no Employee__c**: como a spec pede, não toquei o core. O recálculo é uma chamada do RH (`OnboardingService.recalculateDates` / `syncPlans`, botão "Recalcular prazos" no checklist). O checklist avisa o RH quando `Start_Date__c` do plano difere da admissão do colaborador (`datesOutOfSync`). A ativação refaz tudo sozinha. Edição direta de `Hire_Date__c` fora dessas telas não recalcula até o RH sincronizar.
3. **Responsáveis (O2)**: RH e TI recebem quem executou a mudança para Contratado; Gestor recebe o usuário do `Hiring_Manager__c` da vaga; Colaborador fica vazio até existir `User__c`. `syncPlans` (e a ativação) preenche Colaborador e Gestor quando o usuário passa a existir. "Dono da fila se vazio" não se aplica: quem move a candidatura é sempre um usuário.
4. **Matrícula provisória**: `PRE-` mais os dígitos do número da candidatura (`CA-000123` vira `PRE-000123`), único porque a candidatura é única. A ativação recusa matrícula com prefixo `PRE-`.
5. **Ativação exige cargo** (atual ou informado), porque o histórico de admissão nasce dele. A ativação aceita opcionalmente gestor e cargo (sobrecarga com 5 parâmetros; a de 3 parâmetros da spec continua disponível). Colaborador criado à mão, sem plano, é ativado sem criar plano.
6. **Progresso**: calculado em Apex como (Concluída + Não aplicável) / total, para chegar a 100% quando o plano conclui. Não usa `Progress_Percent__c` (fórmula de Fase 0 conta só Concluída).
7. **Lookup `Job_Application__c` fora das consultas de usuário do plano**: quem não lê candidaturas (colaborador, gestor) perdia a consulta inteira em USER_MODE.
8. **Contexto de sistema** (spec 02), na classe interna `OnboardingService.Privileged`: criação de colaborador, plano e tarefas na contratação; atualização da situação do plano quando uma tarefa muda (quem conclui não edita o plano); leituras do trigger de tarefa em modo sistema (bug `tmpVar1`). A conferência de matrícula duplicada lê em modo sistema só para devolver um booleano.
9. **Trigger de tarefa preenche `Completed_Date__c`** ao concluir e limpa ao reabrir. Para operações de sistema que precisem mudar situação sem ser responsável (seed), usar `TriggerHandler.bypass('OnboardingTaskTriggerHandler')`.
10. **Limites nos testes**: contratação, usuário novo e ativação somam muitas consultas na mesma transação; os testes usam `Test.startTest()` para dividir.
11. **Candidatura sem plano**: contratação reexecutada não recria nada, mas também não repara um colaborador criado sem plano (a spec pede apenas idempotência).

## Pendências

- Nada pendente de critério de aceite. Não verificado visualmente em navegador (LWCs só por Jest e deploy).
- Notificação aos responsáveis das tarefas (HrNotificationService) não foi incluída: fora da spec.

## Pedidos ao orquestrador

1. Incluir as abas `RH_Onboarding_Visao_Geral`, `RH_Onboarding_Ativacao` e `RH_Onboarding_Meu` na navegação do app `RH_Core` (arquivo do core, fora do meu escopo).
2. Se quiser o checklist na página do registro, acrescentar `onboardingChecklist` às páginas de registro de `Employee__c` (core) e de `Onboarding_Plan__c`. O componente já aceita os dois como `recordId`.
3. Seed (spec 18): colaboradores de demonstração em estados avançados devem usar `TriggerHandler.bypass('OnboardingTaskTriggerHandler')` se o usuário do seed não for RH; planos podem nascer por `OnboardingService.createFromApplication(Set<Id>)`.
4. Testes de outros módulos que movem candidatura para Contratado continuam instalando `RecruitingTestData.useRecorder()`; os 81 testes do recrutamento passaram com o onboarding na org.

## Como reproduzir

```bash
# trava obrigatória da org (mkdir atômico) e libera no trap
LOCK="<raiz-do-repositorio>/.locks/rh-w1"
until mkdir "$LOCK" 2>/dev/null; do sleep 30; done; trap 'rmdir "$LOCK"' EXIT
sf project deploy start --source-dir force-app/onboarding --target-org rh-w1 --ignore-conflicts --wait 30
sf apex run test --target-org rh-w1 --code-coverage --result-format human --wait 30 \
  --class-names OnboardingTemplateConfigTest OnboardingServiceTest OnboardingSecurityTest OnboardingBulkTest OnboardingControllerTest
# fora da trava
npx sfdx-lwc-jest -- force-app/onboarding
sf code-analyzer run --workspace force-app/onboarding --rule-selector pmd:Recommended --severity-threshold 2
npx eslint --resolve-plugins-relative-to . "force-app/onboarding/lwc/**/*.js"
```
