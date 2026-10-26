# 15. Fase 2: Admissão e onboarding (onboarding)

Pasta: `force-app/onboarding`. Depende de recruiting e promotion (histórico de admissão). Branch: `feat/onboarding`.

## Histórias

1. Como RH, quando uma candidatura vira Contratado, o colaborador é criado em Pré-admissão com plano de
   onboarding gerado a partir do modelo.
2. Como RH, completo os dados da admissão (matrícula, data de admissão, gestor, cargo) e ativo o colaborador.
3. Como colaborador novo, gestor, TI e RH, vejo e concluo as tarefas que são minhas.
4. Como RH, acompanho o progresso de todos os planos.

## Regras

- O1. `OnboardingHiredHandler` implementa `HiredApplicationHandler` (spec 13). Para cada candidatura:
  cria `Employee__c` com Name e Email__c do candidato, Status__c = Pre_Admissao, Position__c e
  Department__c da vaga, Manager__c = Hiring_Manager__c da vaga, Employment_Type__c da vaga,
  Hire_Date__c = hoje + 15 dias (provisório, editável), Employee_Number__c provisório `PRE-<AutoNumber>`;
  grava `Job_Application__c.Employee__c`; cria o plano. Idempotente: se a candidatura já tem Employee__c,
  não cria de novo. Contexto de sistema (spec 02).
- O2. Plano: uma tarefa por registro de `Onboarding_Task_Template__mdt` aplicável ao tipo de contratação,
  com Due_Date__c = Hire_Date__c + Due_Offset_Days__c. Assigned_To__c: RH = usuário que contratou (ou
  dono da fila se vazio); Gestor = usuário do gestor; TI = mesmo do RH (configurável depois);
  Colaborador = User__c do colaborador quando existir.
- O3. Modelos padrão (8 registros): Enviar documentos admissionais (Colaborador, -10), Conferir
  documentos e exame admissional (RH, -5), Preparar equipamento e acessos (TI, -3), Definir padrinho ou
  madrinha (Gestor, -3), Reunião de boas-vindas (Gestor, 0), Apresentar políticas internas (RH, 1),
  Plano de 30 dias definido (Gestor, 5), Conversa de 30 dias (Gestor, 30).
- O4. `OnboardingService.activate(employeeId, employeeNumber, hireDate)`: só RH; valida matrícula única;
  Status__c = Ativo; cria histórico de admissão via `PositionHistoryService.createAdmission`; Status do
  plano = Em_Andamento.
- O5. Concluir tarefa: só quem é Assigned_To__c ou RH. Plano vira Concluido quando todas as tarefas
  estiverem Concluida ou Nao_Aplicavel.
- O6. Se Hire_Date__c mudar antes da ativação, recalcular as datas das tarefas pendentes.

## Componentes

Apex: `OnboardingHiredHandler`, `OnboardingService`, `OnboardingPlanSelector`,
`OnboardingTaskSelector`, `OnboardingTemplateConfig`, `OnboardingController`,
`OnboardingTaskTriggerHandler` + trigger, `EmployeeOnboardingSync` (se precisar reagir a mudança de
Hire_Date__c, implementar como chamada a partir de `OnboardingController`, não alterando a trigger do core),
testes.

LWC:
- `onboardingChecklist`: no registro do colaborador ou no Meu RH; tarefas agrupadas por responsável,
  checkbox para concluir (quando permitido), barra de progresso, datas vencidas destacadas.
- `onboardingActivation`: para o RH, formulário de ativação (O4).
- `onboardingOverview`: para o RH, lista de planos em andamento com progresso e atrasos.

## Critérios de aceite

- [ ] Candidatura Contratado cria colaborador e plano com 8 tarefas e datas corretas; reexecutar não
      duplica; lote de 50 contratações.
- [ ] Ativação valida matrícula e cria histórico de admissão.
- [ ] O5 com teste negativo (outro usuário não conclui tarefa alheia).
- [ ] Jest para os 3 LWCs. Gates da spec 03.
