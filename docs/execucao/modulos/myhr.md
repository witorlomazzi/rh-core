# Módulo myhr (Meu RH): relatório de entrega

Spec: `docs/specs/17-meu-rh.md`. Pasta: `force-app/myhr`. Branch: `feat/myhr`. Org de trabalho: `rh-w1` (com trava). Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

## O que foi entregue

- App Lightning `Meu_RH` ("Meu RH"), navegação padrão, com as abas: Meu RH (início), Organograma, Minhas férias, Minha equipe, Aprovações (as duas últimas e o organograma reaproveitam as abas do core) e, para quem tiver o acesso, Meu ciclo de avaliação, Avaliações da equipe, Meu onboarding, Solicitar promoção e Histórico de cargos (abas dos outros módulos).
- Início por persona (`myHrHome`, App Page "Meu RH - Início"): cabeçalho com nome, cargo, departamento, gestor, tempo de casa, admissão e situação; cartões `leaveBalanceCard`, "Próximas férias", `leaveRequestList`, `coreApprovalInbox`, `onboardingChecklist` (só se existir plano) e `performanceMyCycle`; para gestor (`Direct_Reports_Count__c` > 0) o bloco "Minha equipe" com `myHrTeamOverview`. O evento `requestleave` do cartão de saldo abre `leaveRequestForm` (propriedade `period-id`) num modal.
- `myHrTeamOverview`: equipe direta com situação, saldo de férias, próximas férias e alerta de prazo concessivo (próximo ou vencido, janela de `Concession_Warning_Days__c`); atalhos para `promotionRequestForm` e `leaveTeamCalendar` em modal.
- `myHrLeave` (página "Minhas férias"): saldo, formulário e histórico lado a lado. O container existe porque componentes irmãos de uma FlexiPage não conseguem trocar o evento `requestleave`.
- `myHrEmployeeReviews`: avaliações do colaborador que o usuário pode ler (aba Desempenho do registro).
- `myHrModal` e `myHrUtils` (apoio, não expostos).
- `MyHrController` (`getContext`, `getTeamOverview`, `getEmployeeReviews`), `MyHrService` e `MyHrSelector` (tudo `USER_MODE`, sem contexto de sistema). Usuário sem vínculo: "Seu usuário ainda não está vinculado a um colaborador. Fale com o RH."
- FlexiPage de registro `Colaborador_RH_Core` ("Colaborador - RH Core") com abas Visão geral, Férias, Carreira, Desempenho e Onboarding, definida como padrão de `Employee__c` no app Meu RH (`actionOverrides` do app).
- Página "Painel do RH" (`RH_Painel_RH`) com `onboardingOverview`, `performanceCycleAdmin` e `recruitingKanban`, e a aba de mesmo nome.
- `HR_MyHR_User`: acrescentados `classAccesses` das três classes, `tabSettings` das quatro abas novas e `applicationVisibilities` do app (ver decisão 6).

## Critérios de aceite

- [x] `MyHrController` testado para colaborador, gestor, RH (com e sem colaborador vinculado) e usuário sem vínculo; mais usuário sem permission set (exceção, nunca dado).
- [x] Jest para `myHrHome` (colaborador, gestor, sem vínculo, erro, onboarding condicional, modal de férias, assinatura do canal) e `myHrTeamOverview`.
- [x] Deploy das FlexiPages, abas e app sem erro na `rh-w1` (inclui o `flexipage:tabset` da página de registro).
- [~] Páginas ativadas: `Colaborador_RH_Core` é o padrão no app Meu RH. No app RH Core e como padrão do objeto, depende de arquivos do core (ver "Pedidos ao orquestrador").
- [~] Página "Painel do RH" criada, mas sem o dashboard da spec 18 (a analytics ainda não está em `develop`) e sem a aba no app RH Core (arquivo do core).
- [x] Gates da spec 03 (ver "Números"). Revisão `sf-code-reviewer` feita manualmente sobre o diff (ver decisão 9).

## Números

- Apex em `rh-w1`: 19 testes (16 em `MyHrControllerTest`, 3 em `MyHrServiceTest`), 100% passando. Cobertura: `MyHrController` 100%, `MyHrService` 100%, `MyHrSelector` 100%.
- Jest: 6 suítes, 33 testes passando (`myHrHome`, `myHrTeamOverview`, `myHrModal`, `myHrLeave`, `myHrEmployeeReviews`, `myHrUtils`). ESLint dos LWCs sem erro.
- Code Analyzer (`pmd:Recommended`): nenhuma violação de severidade 1 ou 2. Restam 9 de severidade 3 (complexidade de `MyHrService`, lista de 4 parâmetros) e 29 de severidade 4 (ApexDoc, `RunAs` em teste puro).
- Travessão e emoji: zero ocorrências em `force-app/myhr` e neste relatório.
- Smoke no ambiente real (`rh-w1`, Apex anônimo como admin RH): `getContext` e `getTeamOverview` devolveram o colaborador, a equipe de dois diretos, o saldo somado dos períodos abertos e o alerta de prazo vencido. Os dados `ZZTEST-MYHR-*` criados para o smoke foram apagados em seguida.

## Decisões tomadas

1. **Aba "Minha equipe" visível a todos**, como pede a spec ("visível só para gestor via componente"): quem não tem equipe vê a mensagem "Você não tem pessoas na sua equipe direta.".
2. **Gestor = `Direct_Reports_Count__c` > 0**, como na spec. Quem aparece na equipe continua decidido pelo compartilhamento (USER_MODE): um colaborador que seja gestor mas só tenha o grupo `HR_Employee` vê os diretos que o sharing da cadeia permite.
3. **Equipe direta, não subárvore**: `myHrTeamOverview` lista só os diretos (`EmployeeSelector.directReports`), sem desligados. Uma consulta de períodos e uma de férias para toda a equipe (teste confirma que o número de consultas não cresce com 42 pessoas).
4. **Saldo e prazo da equipe** consideram só períodos `Disponivel` e `Prazo_Proximo`. O prazo exibido é o do período mais urgente que ainda tem saldo; alerta quando faltam menos que `Concession_Warning_Days__c` dias (padrão 60 se vazio) ou já venceu.
5. **Próximas férias** = solicitação `Pendente`, `Aprovado` ou `Em_Gozo` que ainda não terminou, a de início mais próximo; cancelada e rejeitada não entram.
6. **Permission set**: além de `classAccesses` e `tabSettings`, foi acrescentado `applicationVisibilities` para o `Meu_RH`, porque a spec 02 diz que `HR_MyHR_User` dá "acesso ao app". As abas novas ficam `Visible` nesse conjunto (inclusive `RH_Painel_RH`, que só aparece em apps onde foi incluída). Abas dos outros módulos no app Meu RH usam o `tabSettings` que cada módulo já concede.
7. **Ativação como padrão do objeto no app**: feita no próprio `Meu_RH` por `actionOverrides` com `pageOrSobjectType` (não por arquivo de objeto, que é do core).
8. **`performanceMyCycle` sempre exibido** no início (spec); o próprio componente mostra "Nenhum ciclo de avaliação aberto para você." quando não há.
9. **Revisão de código**: a skill `sf-code-reviewer` não foi invocada como ferramenta; a revisão foi manual contra a mesma lista: sem SOQL ou DML em loop, `with sharing` no controller e `inherited sharing` em serviço e selector, `WITH USER_MODE` em todas as consultas, nenhum campo salarial selecionado, nenhum Id fixo, `Id` do parâmetro de `getEmployeeReviews` protegido pelo sharing, mensagens de erro via `AuraHandledException`.
10. **Tempo de casa** calculado no servidor em meses completos e formatado no LWC ("2 anos e 2 meses").
11. **Datas do Apex** chegam como texto `yyyy-MM-dd` e são formatadas sem fuso; `Released_Date__c` é `DateTime`, então o rótulo usa só a parte da data (UTC).
12. **Validação visual** em navegador não foi feita: abrir a org exigiria imprimir a URL de acesso com token. O que foi verificado: deploy sem erro das páginas, Jest, e o smoke de Apex acima.

## Pendências

- Dashboard da spec 18 na página "Painel do RH" (depende do módulo analytics).
- Tornar `Colaborador_RH_Core` o padrão no app RH Core e no objeto, e incluir a aba `RH_Painel_RH` no app RH Core (arquivos do core).
- Verificação visual das páginas no navegador.

## Pedidos ao orquestrador

1. **App `RH_Core`** (`force-app/core/applications/RH_Core.app-meta.xml`): incluir `<tabs>RH_Painel_RH</tabs>` e, para a página de registro nova valer no app do RH, o bloco abaixo no início do arquivo:
   ```xml
   <actionOverrides>
       <actionName>View</actionName>
       <content>Colaborador_RH_Core</content>
       <formFactor>Large</formFactor>
       <skipRecordTypeSelect>false</skipRecordTypeSelect>
       <type>Flexipage</type>
       <pageOrSobjectType>Employee__c</pageOrSobjectType>
   </actionOverrides>
   ```
2. **Padrão do objeto** (opcional): `Employee__c.object-meta.xml` (core) com `actionOverrides` `View` do tipo `Flexipage` apontando para `Colaborador_RH_Core`, para valer em qualquer app.
3. **Analytics (spec 18)**: depois de integrar, acrescentar o dashboard à página `RH_Painel_RH` (pasta `force-app/myhr/flexipages`).
4. **PSG**: os grupos `HR_Employee`, `HR_Manager`, `HR_Admin` e `HR_Recruiter` já referenciam `HR_MyHR_User`; ficam com status `Updated` após o deploy e recalculam sozinhos. Em testes, `HrTestDataFactory` já força o recálculo.

## Como reproduzir

```bash
# trava da org (ver docs/execucao/00-plano-multiagente.md), depois:
LOCK="C:/Users/sousa/Desktop/Claudio/Salesforce/rh-core/.locks/rh-w1"
until mkdir "$LOCK" 2>/dev/null; do sleep 30; done; trap 'rmdir "$LOCK"' EXIT
sf project deploy start --source-dir force-app/myhr --target-org rh-w1 --ignore-conflicts --wait 30
sf apex run test --class-names MyHrControllerTest MyHrServiceTest --code-coverage --result-format human --wait 30 --target-org rh-w1
# fora da trava
npx sfdx-lwc-jest -- force-app/myhr
npx eslint --resolve-plugins-relative-to . "force-app/myhr/lwc/**/*.js"
sf code-analyzer run --workspace force-app/myhr --rule-selector pmd:Recommended --severity-threshold 2
```

`--ignore-conflicts` é necessário porque o rastreamento da scratch org vê deploys anteriores do `force-app` completo como alteração remota.
