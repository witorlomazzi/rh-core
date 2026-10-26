# 17. Fase 2: Meu RH, a experiência do colaborador e do gestor (myhr)

Pasta: `force-app/myhr`. Depende de todos os módulos da Fase 1 e de onboarding. Branch: `feat/myhr`.
Este módulo só monta a experiência; não recria regras dos outros módulos.

## Entregas

1. App Lightning `Meu_RH` ("Meu RH"), navegação padrão, com a Home do app e tabs: Meu RH (Home),
   Organograma, Minhas férias, Minha equipe (visível só para gestor via componente), Aprovações.
2. LWC `myHrHome` (App Page "Meu RH - Início"):
   - cabeçalho com nome, cargo, departamento, gestor e tempo de casa;
   - cartões: saldo de férias (`leaveBalanceCard`), próximas férias, solicitações recentes
     (`leaveRequestList`), pendências de aprovação (`coreApprovalInbox`), onboarding em andamento
     (`onboardingChecklist`, só se existir plano), ciclo de avaliação atual (`performanceMyCycle`);
   - se o usuário for gestor (`Direct_Reports_Count__c` > 0): bloco "Minha equipe" com
     `myHrTeamOverview`.
3. LWC `myHrTeamOverview`: lista da equipe direta (nome, cargo, status, saldo de férias, próximas férias,
   alerta de prazo concessivo), atalhos para solicitar promoção (`promotionRequestForm`) e para o
   calendário (`leaveTeamCalendar`).
4. `MyHrController`: um método `getContext()` que devolve em uma chamada o colaborador atual, se é gestor,
   se é RH (Custom Permission `HR_Admin_Access` incluída nos PS Admin) e Ids para os componentes filhos.
   Usuário sem colaborador vinculado: estado vazio amigável ("Seu usuário ainda não está vinculado a um
   colaborador. Fale com o RH.").
5. Lightning Record Page de `Employee__c` ("Colaborador - RH Core") com abas: Visão geral, Férias
   (`leaveBalanceCard`, `leaveRequestList`), Carreira (`positionHistoryTimeline`), Desempenho, Onboarding.
   Ativar como padrão do objeto no app RH Core e no Meu RH.
6. App `RH_Core` (criado na Fase 0) recebe as tabs dos módulos, a página "Painel do RH" com
   `onboardingOverview`, `performanceCycleAdmin`, `recruitingKanban` e o dashboard (spec 18).
7. A Custom Permission `HR_Admin_Access` já existe desde a Fase 0 (spec 01) e está nos PS Admin; aqui só
   é consultada com `FeatureManagement.checkPermission`.

## Critérios de aceite

- [ ] `MyHrController` testado para colaborador, gestor, RH e usuário sem vínculo.
- [ ] Jest para `myHrHome` (estados colaborador, gestor, sem vínculo, erro) e `myHrTeamOverview`.
- [ ] Deploy das FlexiPages e apps sem erro; páginas ativadas.
- [ ] Gates da spec 03.
