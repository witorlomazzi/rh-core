@IsTest
private class OnboardingServiceTest {
    private static final List<Integer> OFFSETS = new List<Integer>{ -10, -5, -3, -3, 0, 1, 5, 30 };
    private static final List<String> ROLES = new List<String>{ 'Colaborador', 'RH', 'TI', 'Gestor', 'Gestor', 'RH', 'Gestor', 'Gestor' };
    private static final List<String> TITLES = new List<String>{
        'Enviar documentos admissionais',
        'Conferir documentos e exame admissional',
        'Preparar equipamento e acessos',
        'Definir padrinho ou madrinha',
        'Reunião de boas-vindas',
        'Apresentar políticas internas',
        'Plano de 30 dias definido',
        'Conversa de 30 dias'
    };

    @TestSetup
    static void setup() {
        OnboardingTestSupport.createAll();
    }

    // ------------------------------------------------------------------------------------------ O1 a O3

    @IsTest
    static void hiredApplicationCreatesEmployeePlanAndEightTasks() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 1);
        Candidate__c candidate = [SELECT Name, Email__c FROM Candidate__c WHERE Id = :apps[0].Candidate__c];

        System.runAs(c.tree.hrUser) {
            OnboardingTestSupport.hire(apps);
        }

        Employee__c employee = OnboardingTestSupport.employeeOf(apps[0].Id);
        Assert.areEqual(candidate.Name, employee.Name);
        Assert.areEqual(candidate.Email__c, employee.Email__c);
        Assert.areEqual('Pre_Admissao', employee.Status__c);
        Assert.areEqual(c.opening.Position__c, employee.Position__c);
        Assert.areEqual(c.opening.Department__c, employee.Department__c);
        Assert.areEqual(c.tree.mgr1.Id, employee.Manager__c, 'O gestor contratante da vaga vira o gestor');
        Assert.areEqual('CLT', employee.Employment_Type__c);
        Date expectedHire = Date.today().addDays(15);
        Assert.areEqual(expectedHire, employee.Hire_Date__c);
        Assert.areEqual('PRE-' + apps[0].Name.replaceAll('[^0-9]', ''), employee.Employee_Number__c);

        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Assert.areEqual('Nao_Iniciado', plan.Status__c);
        Assert.areEqual(expectedHire, plan.Start_Date__c);
        Assert.areEqual(apps[0].Id, plan.Job_Application__c);
        Assert.areEqual(8, plan.Total_Tasks__c.intValue());
        Assert.areEqual(0, plan.Completed_Tasks__c.intValue());

        List<Onboarding_Task__c> tasks = OnboardingTestSupport.tasksOf(plan.Id);
        Assert.areEqual(8, tasks.size());
        for (Integer i = 0; i < 8; i++) {
            Onboarding_Task__c t = tasks[i];
            Assert.areEqual(TITLES[i], t.Name);
            Assert.areEqual(ROLES[i], t.Owner_Role__c, t.Name);
            Assert.areEqual(expectedHire.addDays(OFFSETS[i]), t.Due_Date__c, t.Name);
            Assert.areEqual(OFFSETS[i], t.Due_Offset_Days__c.intValue(), t.Name);
            Assert.areEqual('Pendente', t.Status__c);
            Assert.isNotNull(t.Description__c);
            if (t.Owner_Role__c == 'Colaborador') {
                Assert.isNull(t.Assigned_To__c, 'O colaborador ainda nao tem usuario');
            } else if (t.Owner_Role__c == 'Gestor') {
                Assert.areEqual(c.tree.mgr1User.Id, t.Assigned_To__c, 'Gestor: usuario do gestor da vaga');
            } else {
                Assert.areEqual(c.tree.hrUser.Id, t.Assigned_To__c, 'RH e TI: quem contratou');
            }
        }
    }

    @IsTest
    static void runningAgainDoesNotDuplicateAnything() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 1);
        System.runAs(c.tree.hrUser) {
            OnboardingTestSupport.hire(apps);
        }
        Employee__c employee = OnboardingTestSupport.employeeOf(apps[0].Id);

        Map<Id, Id> again = OnboardingService.createFromApplication(new Set<Id>{ apps[0].Id });
        Assert.isTrue(again.isEmpty(), 'Candidatura que ja tem colaborador e ignorada');
        new OnboardingHiredHandler().handle(new Set<Id>{ apps[0].Id });

        Assert.areEqual(1, [SELECT COUNT() FROM Employee__c WHERE Name = :employee.Name]);
        Assert.areEqual(1, [SELECT COUNT() FROM Onboarding_Plan__c WHERE Employee__c = :employee.Id]);
        Assert.areEqual(8, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__r.Employee__c = :employee.Id]);
        Assert.areEqual(employee.Id, OnboardingTestSupport.employeeOf(apps[0].Id).Id);
    }

    @IsTest
    static void emptyInputCreatesNothing() {
        Assert.isTrue(OnboardingService.createFromApplication(null).isEmpty());
        Assert.isTrue(OnboardingService.createFromApplication(new Set<Id>()).isEmpty());
        OnboardingService.refreshPlanStatus(null);
        OnboardingService.refreshPlanStatus(new Set<Id>());
        Assert.areEqual(0, [SELECT COUNT() FROM Onboarding_Plan__c]);
    }

    @IsTest
    static void templatesAreFilteredByEmploymentType() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        OnboardingTemplateConfig.Template everyone = template('Para todos', 'RH', 1, 2);
        OnboardingTemplateConfig.Template contractorOnly = template('So PJ', 'RH', 2, 3);
        contractorOnly.employmentTypes = new Set<String>{ 'PJ' };
        OnboardingTemplateConfig.Template cltOrIntern = template('CLT ou estagio', 'Gestor', 3, 4);
        cltOrIntern.employmentTypes = new Set<String>{ 'CLT', 'Estagio' };
        OnboardingTemplateConfig.testOverride = new List<OnboardingTemplateConfig.Template>{ everyone, contractorOnly, cltOrIntern };

        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 1);
        Map<Id, Id> created = OnboardingService.createFromApplication(new Set<Id>{ apps[0].Id });

        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(created.get(apps[0].Id));
        List<Onboarding_Task__c> tasks = OnboardingTestSupport.tasksOf(plan.Id);
        Assert.areEqual(2, tasks.size(), 'A tarefa so para PJ nao entra em uma vaga CLT');
        Assert.areEqual('Para todos', tasks[0].Name);
        Assert.areEqual('CLT ou estagio', tasks[1].Name);
        Assert.areEqual(Date.today().addDays(15 + 4), tasks[1].Due_Date__c);
    }

    @IsTest
    static void failureInTheHandlerUndoesTheHiring() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 1);
        // Ocupa a matricula provisoria que a admissao vai usar: a criacao do colaborador falha.
        Employee__c blocker = HrTestDataFactory.buildEmployee(null, null);
        blocker.Employee_Number__c = 'PRE-' + apps[0].Name.replaceAll('[^0-9]', '');
        insert blocker;

        Boolean failed = false;
        try {
            OnboardingTestSupport.hire(apps);
        } catch (Exception e) {
            failed = true;
        }
        Assert.isTrue(failed, 'Nao pode existir contratado sem a admissao');
        Job_Application__c reloaded = [SELECT Stage__c, Employee__c FROM Job_Application__c WHERE Id = :apps[0].Id];
        Assert.areEqual('Proposta', reloaded.Stage__c, 'A mudanca para Contratado foi desfeita');
        Assert.isNull(reloaded.Employee__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Onboarding_Plan__c]);
    }

    // ------------------------------------------------------------------------------------------ O4

    @IsTest
    static void activationCompletesTheAdmission() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Date newHire = Date.today().addDays(10);

        System.runAs(c.tree.hrUser) {
            OnboardingService.activate(employee.Id, '  ZZTEST-A100 ', newHire);
        }

        Employee__c active = OnboardingTestSupport.reloadEmployee(employee.Id);
        Assert.areEqual('Ativo', active.Status__c);
        Assert.areEqual('ZZTEST-A100', active.Employee_Number__c);
        Assert.areEqual(newHire, active.Hire_Date__c);

        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Assert.areEqual('Em_Andamento', plan.Status__c);
        Assert.areEqual(newHire, plan.Start_Date__c);
        for (Onboarding_Task__c t : OnboardingTestSupport.tasksOf(plan.Id)) {
            Assert.areEqual(newHire.addDays(t.Due_Offset_Days__c.intValue()), t.Due_Date__c, 'Prazos refeitos para a nova data: ' + t.Name);
        }

        List<Position_History__c> history = [
            SELECT Position__c, Start_Date__c, End_Date__c, Change_Reason__c
            FROM Position_History__c
            WHERE Employee__c = :employee.Id
        ];
        Assert.areEqual(1, history.size());
        Assert.areEqual('Admissao', history[0].Change_Reason__c);
        Assert.areEqual(newHire, history[0].Start_Date__c);
        Assert.areEqual(c.opening.Position__c, history[0].Position__c);
        Assert.isNull(history[0].End_Date__c);
    }

    @IsTest
    static void activationCanSetManagerAndPosition() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c noPosition = HrTestDataFactory.buildEmployee(null, null);
        noPosition.Status__c = 'Pre_Admissao';
        noPosition.Employee_Number__c = 'PRE-ZZTEST1';
        noPosition.Hire_Date__c = Date.today().addDays(5);
        insert noPosition;
        Job_Position__c position = HrTestDataFactory.position();

        System.runAs(c.tree.hrUser) {
            String error = activateError(noPosition.Id, 'ZZTEST-A200', Date.today(), null, null);
            Assert.areEqual(OnboardingService.MSG_POSITION_REQUIRED, error, 'Sem cargo nao ha historico de admissao');
            OnboardingService.activate(noPosition.Id, 'ZZTEST-A200', Date.today(), c.tree.mgr2.Id, position.Id);
        }

        Employee__c active = OnboardingTestSupport.reloadEmployee(noPosition.Id);
        Assert.areEqual('Ativo', active.Status__c);
        Assert.areEqual(c.tree.mgr2.Id, active.Manager__c);
        Assert.areEqual(position.Id, active.Position__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Position_History__c WHERE Employee__c = :noPosition.Id]);
        Assert.areEqual(0, [SELECT COUNT() FROM Onboarding_Plan__c WHERE Employee__c = :noPosition.Id], 'Sem plano, a ativacao nao cria um');
    }

    @IsTest
    static void activationValidatesTheRequest() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Date hire = Date.today().addDays(3);

        System.runAs(c.tree.mgr1User) {
            Assert.areEqual(OnboardingService.MSG_NOT_HR, activateError(employee.Id, 'ZZTEST-B1', hire, null, null), 'So o RH ativa');
        }
        System.runAs(c.tree.emp1User) {
            Assert.areEqual(OnboardingService.MSG_NOT_HR, activateError(employee.Id, 'ZZTEST-B1', hire, null, null));
        }
        System.runAs(c.tree.hrUser) {
            Assert.areEqual(OnboardingService.MSG_NUMBER_REQUIRED, activateError(employee.Id, '   ', hire, null, null));
            Assert.areEqual(OnboardingService.MSG_NUMBER_REQUIRED, activateError(employee.Id, null, hire, null, null));
            Assert.areEqual(OnboardingService.MSG_NUMBER_LENGTH, activateError(employee.Id, 'ZZTEST-123456789012345', hire, null, null));
            Assert.areEqual(OnboardingService.MSG_NUMBER_PROVISIONAL, activateError(employee.Id, 'pre-999', hire, null, null));
            Assert.areEqual(OnboardingService.MSG_DATE_REQUIRED, activateError(employee.Id, 'ZZTEST-B1', null, null, null));
            Assert.areEqual(OnboardingService.MSG_NUMBER_TAKEN, activateError(employee.Id, 'ZZTEST-EMP1', hire, null, null), 'Matricula unica');
            Assert.areEqual(OnboardingService.MSG_NUMBER_TAKEN, activateError(employee.Id, 'zztest-emp1', hire, null, null), 'Sem diferenciar maiusculas');
            Assert.areEqual(OnboardingService.MSG_EMPLOYEE_NOT_FOUND, activateError(c.opening.Id, 'ZZTEST-B1', hire, null, null), 'Id de outro objeto');
        }
        Assert.areEqual('Pre_Admissao', OnboardingTestSupport.reloadEmployee(employee.Id).Status__c, 'Nada mudou');
        Assert.areEqual(0, [SELECT COUNT() FROM Position_History__c WHERE Employee__c = :employee.Id]);
    }

    @IsTest
    static void onlyPreAdmissionEmployeesCanBeActivated() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        System.runAs(c.tree.hrUser) {
            OnboardingService.activate(employee.Id, 'ZZTEST-C1', Date.today());
            Assert.areEqual(OnboardingService.MSG_NOT_PRE_ADMISSION, activateError(employee.Id, 'ZZTEST-C2', Date.today(), null, null));
            Assert.areEqual(OnboardingService.MSG_NOT_PRE_ADMISSION, activateError(c.tree.emp3.Id, 'ZZTEST-C3', Date.today(), null, null));
        }
        Assert.areEqual('ZZTEST-C1', OnboardingTestSupport.reloadEmployee(employee.Id).Employee_Number__c);
    }

    @IsTest
    static void failedActivationRollsEverythingBack() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        System.runAs(c.tree.hrUser) {
            // Gestor igual ao proprio colaborador: a validacao do colaborador recusa.
            String error = activateError(employee.Id, 'ZZTEST-D1', Date.today(), employee.Id, null);
            Assert.isNotNull(error);
        }
        Employee__c unchanged = OnboardingTestSupport.reloadEmployee(employee.Id);
        Assert.areEqual('Pre_Admissao', unchanged.Status__c);
        Assert.areEqual(employee.Employee_Number__c, unchanged.Employee_Number__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Position_History__c WHERE Employee__c = :employee.Id]);
        Assert.areEqual('Nao_Iniciado', OnboardingTestSupport.planOf(employee.Id).Status__c);
    }

    // ------------------------------------------------------------------------------------------ O5

    @IsTest
    static void assignedUserCompletesAndReopensTheirTask() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c managerTask = OnboardingTestSupport.taskOfRole(plan.Id, 'Gestor');

        System.runAs(c.tree.mgr1User) {
            OnboardingService.setTaskDone(managerTask.Id, true);
        }
        Onboarding_Task__c done = [SELECT Status__c, Completed_Date__c FROM Onboarding_Task__c WHERE Id = :managerTask.Id];
        Assert.areEqual('Concluida', done.Status__c);
        Assert.isNotNull(done.Completed_Date__c);
        Assert.areEqual(1, [SELECT Completed_Tasks__c FROM Onboarding_Plan__c WHERE Id = :plan.Id].Completed_Tasks__c.intValue());

        System.runAs(c.tree.mgr1User) {
            OnboardingService.setTaskDone(managerTask.Id, true);
            OnboardingService.setTaskDone(managerTask.Id, false);
        }
        Onboarding_Task__c reopened = [SELECT Status__c, Completed_Date__c FROM Onboarding_Task__c WHERE Id = :managerTask.Id];
        Assert.areEqual('Pendente', reopened.Status__c);
        Assert.isNull(reopened.Completed_Date__c);
    }

    @IsTest
    static void hrCanChangeAnyTaskButOthersCannotChangeTasksTheyDoNotOwn() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c managerTask = OnboardingTestSupport.taskOfRole(plan.Id, 'Gestor');
        Onboarding_Task__c hrTask = OnboardingTestSupport.taskOfRole(plan.Id, 'RH');
        Onboarding_Task__c employeeTask = OnboardingTestSupport.taskOfRole(plan.Id, 'Colaborador');

        System.runAs(c.tree.mgr1User) {
            Assert.areEqual(OnboardingService.MSG_NOT_ASSIGNED, taskError(hrTask.Id, true), 'Gestor nao conclui tarefa do RH');
            Assert.areEqual(OnboardingService.MSG_NOT_ASSIGNED, taskError(employeeTask.Id, true), 'Nem a do colaborador, sem responsavel');
            Assert.isNull(taskError(managerTask.Id, true));
        }
        System.runAs(c.tree.hrUser) {
            Assert.isNull(taskError(employeeTask.Id, true), 'O RH conclui qualquer tarefa');
            Assert.isNull(taskError(managerTask.Id, false));
            Assert.areEqual(OnboardingService.MSG_TASK_NOT_FOUND, taskError(c.opening.Id, true), 'Id de outro objeto');
        }
        Assert.areEqual('Concluida', [SELECT Status__c FROM Onboarding_Task__c WHERE Id = :employeeTask.Id].Status__c);
        Assert.areEqual('Pendente', [SELECT Status__c FROM Onboarding_Task__c WHERE Id = :hrTask.Id].Status__c);
    }

    @IsTest
    static void newHireWithAUserSeesAndCompletesOnlyTheirOwnTasks() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        User newcomer = HrTestDataFactory.user('zznew', 'HR_Employee');
        update new Employee__c(Id = employee.Id, User__c = newcomer.Id);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);

        Test.startTest(); // contratacao, usuario novo e vinculo somam muitas consultas
        System.runAs(c.tree.hrUser) {
            OnboardingService.syncPlans(new Set<Id>{ employee.Id });
        }
        Onboarding_Task__c employeeTask = OnboardingTestSupport.taskOfRole(plan.Id, 'Colaborador');
        Onboarding_Task__c hrTask = OnboardingTestSupport.taskOfRole(plan.Id, 'RH');
        Assert.areEqual(newcomer.Id, employeeTask.Assigned_To__c, 'Tarefa do colaborador vai para o usuario dele');

        System.runAs(newcomer) {
            OnboardingService.ChecklistView view = OnboardingService.checklist(null);
            Assert.isTrue(view.hasPlan, 'O colaborador ve o proprio plano pelo Meu RH');
            Assert.areEqual(employee.Id, view.employeeId);
            Assert.isFalse(view.isHr);
            Assert.isNull(taskError(employeeTask.Id, true));
            Assert.areEqual(OnboardingService.MSG_NOT_ASSIGNED, taskError(hrTask.Id, true));
        }
        Assert.areEqual('Concluida', [SELECT Status__c FROM Onboarding_Task__c WHERE Id = :employeeTask.Id].Status__c);
    }

    @IsTest
    static void planCompletesWhenNoTaskIsPending() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        List<Onboarding_Task__c> tasks = OnboardingTestSupport.tasksOf(plan.Id);

        // Tres nao aplicaveis e cinco concluidas: o plano conclui.
        OnboardingTestSupport.setStatus(new List<Onboarding_Task__c>{ tasks[0], tasks[1], tasks[2] }, 'Nao_Aplicavel', c.tree.hrUser);
        Assert.areEqual('Nao_Iniciado', OnboardingTestSupport.planOf(employee.Id).Status__c);
        OnboardingTestSupport.setStatus(new List<Onboarding_Task__c>{ tasks[3], tasks[4], tasks[5], tasks[6], tasks[7] }, 'Concluida', c.tree.hrUser);
        Assert.areEqual('Concluido', OnboardingTestSupport.planOf(employee.Id).Status__c);

        // Reabrir uma tarefa de um colaborador ainda em pre-admissao volta para Nao iniciado.
        OnboardingTestSupport.setStatus(new List<Onboarding_Task__c>{ tasks[7] }, 'Pendente', c.tree.hrUser);
        Assert.areEqual('Nao_Iniciado', OnboardingTestSupport.planOf(employee.Id).Status__c);

        // Depois da ativacao, volta para Em andamento. Limites novos: a ativacao e as trocas anteriores somam muitas consultas.
        Test.startTest();
        System.runAs(c.tree.hrUser) {
            OnboardingService.activate(employee.Id, 'ZZTEST-E1', Date.today());
        }
        OnboardingTestSupport.setStatus(new List<Onboarding_Task__c>{ tasks[7] }, 'Concluida', c.tree.hrUser);
        Assert.areEqual('Concluido', OnboardingTestSupport.planOf(employee.Id).Status__c);
        OnboardingTestSupport.setStatus(new List<Onboarding_Task__c>{ tasks[7] }, 'Pendente', c.tree.hrUser);
        Assert.areEqual('Em_Andamento', OnboardingTestSupport.planOf(employee.Id).Status__c);
    }

    @IsTest
    static void deletingTheLastPendingTaskCompletesThePlan() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        List<Onboarding_Task__c> tasks = OnboardingTestSupport.tasksOf(plan.Id);
        List<Onboarding_Task__c> toComplete = new List<Onboarding_Task__c>();
        for (Integer i = 0; i < 7; i++) {
            toComplete.add(tasks[i]);
        }
        OnboardingTestSupport.setStatus(toComplete, 'Concluida', c.tree.hrUser);
        Assert.areNotEqual('Concluido', OnboardingTestSupport.planOf(employee.Id).Status__c);

        System.runAs(c.tree.hrUser) {
            delete tasks[7];
        }
        Assert.areEqual('Concluido', OnboardingTestSupport.planOf(employee.Id).Status__c);
    }

    @IsTest
    static void taskCreatedAsDoneGetsACompletionDate() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c extra = new Onboarding_Task__c(Name = 'ZZTEST-Extra', Plan__c = plan.Id, Status__c = 'Concluida', Owner_Role__c = 'RH');
        System.runAs(c.tree.hrUser) {
            insert extra;
        }
        Assert.isNotNull([SELECT Completed_Date__c FROM Onboarding_Task__c WHERE Id = :extra.Id].Completed_Date__c);
    }

    // ------------------------------------------------------------------------------------------ O6

    @IsTest
    static void changingTheHireDateRecalculatesOnlyPendingTasks() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        List<Onboarding_Task__c> before = OnboardingTestSupport.tasksOf(plan.Id);
        OnboardingTestSupport.setStatus(new List<Onboarding_Task__c>{ before[0] }, 'Concluida', c.tree.hrUser);
        Date newHire = Date.today().addDays(40);
        update new Employee__c(Id = employee.Id, Hire_Date__c = newHire);

        System.runAs(c.tree.hrUser) {
            Assert.isTrue(OnboardingService.checklist(employee.Id).datesOutOfSync, 'Plano com data de inicio diferente da admissao');
            OnboardingService.recalculateDates(new Set<Id>{ employee.Id });
            Assert.isFalse(OnboardingService.checklist(employee.Id).datesOutOfSync);
        }

        Assert.areEqual(newHire, OnboardingTestSupport.planOf(employee.Id).Start_Date__c);
        List<Onboarding_Task__c> after = OnboardingTestSupport.tasksOf(plan.Id);
        Assert.areEqual(before[0].Due_Date__c, after[0].Due_Date__c, 'Tarefa concluida mantem o prazo');
        for (Integer i = 1; i < 8; i++) {
            Assert.areEqual(newHire.addDays(OFFSETS[i]), after[i].Due_Date__c, after[i].Name);
        }
    }

    @IsTest
    static void syncReassignsManagerTasksAndOnlyHrCanSync() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        update new Employee__c(Id = employee.Id, Manager__c = c.tree.emp2.Id);

        System.runAs(c.tree.mgr1User) {
            try {
                OnboardingService.syncPlans(new Set<Id>{ employee.Id });
                Assert.fail('So o RH sincroniza');
            } catch (OnboardingService.OnboardingException e) {
                Assert.areEqual(OnboardingService.MSG_NOT_HR, e.getMessage());
            }
            try {
                OnboardingService.recalculateDates(new Set<Id>{ employee.Id });
                Assert.fail('So o RH recalcula');
            } catch (OnboardingService.OnboardingException e) {
                Assert.areEqual(OnboardingService.MSG_NOT_HR, e.getMessage());
            }
        }
        System.runAs(c.tree.hrUser) {
            OnboardingService.syncPlans(new Set<Id>{ employee.Id });
            OnboardingService.syncPlans(null);
            OnboardingService.syncPlans(new Set<Id>{ c.tree.emp3.Id });
        }
        for (Onboarding_Task__c t : OnboardingTestSupport.tasksOf(plan.Id)) {
            if (t.Owner_Role__c == 'Gestor') {
                Assert.areEqual(c.tree.emp2User.Id, t.Assigned_To__c, 'Gestor novo, tarefa nova: ' + t.Name);
            } else if (t.Owner_Role__c == 'RH' || t.Owner_Role__c == 'TI') {
                Assert.areEqual(c.tree.hrUser.Id, t.Assigned_To__c, 'RH e TI nao mudam');
            }
        }
    }

    // ------------------------------------------------------------------------------------------ leitura dos LWCs

    @IsTest
    static void checklistGroupsTasksByRoleWithProgressAndOverdue() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        update new Employee__c(Id = employee.Id, Hire_Date__c = Date.today().addDays(-40));
        System.runAs(c.tree.hrUser) {
            OnboardingService.recalculateDates(new Set<Id>{ employee.Id });
        }
        List<Onboarding_Task__c> tasks = OnboardingTestSupport.tasksOf(plan.Id);
        OnboardingTestSupport.setStatus(new List<Onboarding_Task__c>{ tasks[0], tasks[1] }, 'Concluida', c.tree.hrUser);

        System.runAs(c.tree.hrUser) {
            OnboardingService.ChecklistView byEmployee = OnboardingService.checklist(employee.Id);
            OnboardingService.ChecklistView byPlan = OnboardingService.checklist(plan.Id);
            Assert.areEqual(byEmployee.planId, byPlan.planId, 'Colaborador ou plano chegam ao mesmo checklist');
            Assert.isTrue(byEmployee.hasPlan);
            Assert.isTrue(byEmployee.isHr);
            Assert.areEqual(employee.Name, byEmployee.employeeName);
            Assert.areEqual('Não iniciado', byEmployee.planStatusLabel);
            Assert.areEqual(8, byEmployee.total);
            Assert.areEqual(2, byEmployee.resolved);
            Assert.areEqual(25, byEmployee.progressPercent);
            Assert.areEqual(6, byEmployee.overdueCount, 'Todas as pendentes venceram, as concluidas nao contam');
            List<String> order = new List<String>();
            for (OnboardingService.TaskGroup g : byEmployee.groups) {
                order.add(g.role);
            }
            Assert.areEqual(new List<String>{ 'Colaborador', 'RH', 'TI', 'Gestor' }, order);
            OnboardingService.TaskGroup rh = byEmployee.groups[1];
            Assert.areEqual(2, rh.total);
            Assert.areEqual(1, rh.resolved);
            Assert.isTrue(rh.tasks[0].done);
            Assert.isFalse(rh.tasks[0].overdue);
            Assert.isTrue(rh.tasks[1].overdue);
            Assert.isTrue(rh.tasks[1].canChange, 'O RH altera qualquer tarefa');
            Assert.areEqual('Pendente', rh.tasks[1].statusLabel);
        }
    }

    @IsTest
    static void checklistWithoutPlanOrWithAnotherObject() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        System.runAs(c.tree.hrUser) {
            Assert.isFalse(OnboardingService.checklist(c.tree.emp3.Id).hasPlan, 'Colaborador sem plano');
            Assert.isFalse(OnboardingService.checklist(null).hasPlan, 'Usuario sem colaborador');
            try {
                OnboardingService.checklist(c.opening.Id);
                Assert.fail('Objeto invalido');
            } catch (OnboardingService.OnboardingException e) {
                Assert.areEqual(OnboardingService.MSG_RECORD_TYPE, e.getMessage());
            }
        }
        System.runAs(c.tree.emp1User) {
            Assert.isFalse(OnboardingService.checklist(null).hasPlan, 'Colaborador comum sem plano proprio');
        }
    }

    @IsTest
    static void overviewListsPlansWithOverdueFirst() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 3);
        System.runAs(c.tree.hrUser) {
            OnboardingTestSupport.hire(apps);
        }
        Employee__c late = OnboardingTestSupport.employeeOf(apps[0].Id);
        Employee__c ontime = OnboardingTestSupport.employeeOf(apps[1].Id);
        Employee__c finished = OnboardingTestSupport.employeeOf(apps[2].Id);
        update new Employee__c(Id = late.Id, Hire_Date__c = Date.today().addDays(-40));
        System.runAs(c.tree.hrUser) {
            OnboardingService.recalculateDates(new Set<Id>{ late.Id });
        }
        Onboarding_Plan__c finishedPlan = OnboardingTestSupport.planOf(finished.Id);
        OnboardingTestSupport.setStatus(OnboardingTestSupport.tasksOf(finishedPlan.Id), 'Concluida', c.tree.hrUser);

        System.runAs(c.tree.hrUser) {
            OnboardingService.OverviewResult open = OnboardingService.overview(false);
            Assert.areEqual(2, open.planCount, 'Plano concluido fica de fora');
            Assert.areEqual(1, open.overduePlanCount);
            Assert.areEqual(late.Id, open.plans[0].employeeId, 'Atraso primeiro');
            Assert.areEqual(ontime.Id, open.plans[1].employeeId);
            Assert.areEqual(8, open.plans[0].overdueCount);
            Assert.areEqual(0, open.plans[0].progressPercent);
            Assert.areEqual(0, open.averageProgress);
            Assert.areEqual('Não iniciado', open.plans[1].statusLabel);

            OnboardingService.OverviewResult all = OnboardingService.overview(true);
            Assert.areEqual(3, all.planCount);
            Assert.areEqual(33, all.averageProgress);
        }
    }

    @IsTest
    static void overviewWithoutPlansIsEmpty() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        System.runAs(c.tree.hrUser) {
            OnboardingService.OverviewResult result = OnboardingService.overview(false);
            Assert.areEqual(0, result.planCount);
            Assert.areEqual(0, result.averageProgress);
            Assert.isTrue(result.plans.isEmpty());
        }
    }

    @IsTest
    static void activationContextListsPreAdmissionEmployeesPositionsAndManagers() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        System.runAs(c.tree.hrUser) {
            OnboardingService.ActivationContext ctx = OnboardingService.activationContext();
            Assert.areEqual(1, ctx.employees.size());
            OnboardingService.PendingEmployee p = ctx.employees[0];
            Assert.areEqual(employee.Id, p.id);
            Assert.areEqual(employee.Employee_Number__c, p.employeeNumber);
            Assert.areEqual(employee.Hire_Date__c, p.hireDate);
            Assert.areEqual(c.opening.Position__c, p.positionId);
            Assert.areEqual(c.tree.mgr1.Id, p.managerId);
            Assert.isNotNull(p.positionName);
            Assert.isNotNull(p.departmentName);
            Assert.isNotNull(p.managerName);
            Assert.isFalse(ctx.positions.isEmpty());
            Assert.isFalse(ctx.managers.isEmpty());
        }
        System.runAs(c.tree.mgr1User) {
            try {
                OnboardingService.activationContext();
                Assert.fail('So o RH');
            } catch (OnboardingService.OnboardingException e) {
                Assert.areEqual(OnboardingService.MSG_NOT_HR, e.getMessage());
            }
        }
    }

    // ------------------------------------------------------------------------------------------ apoio

    private static OnboardingTemplateConfig.Template template(String title, String role, Integer sortOrder, Integer offset) {
        OnboardingTemplateConfig.Template t = new OnboardingTemplateConfig.Template();
        t.title = title;
        t.description = 'ZZTEST-' + title;
        t.ownerRole = role;
        t.sortOrder = sortOrder;
        t.offsetDays = offset;
        return t;
    }

    private static String activateError(Id employeeId, String employeeNumber, Date hireDate, Id managerId, Id positionId) {
        try {
            OnboardingService.activate(employeeId, employeeNumber, hireDate, managerId, positionId);
        } catch (OnboardingService.OnboardingException e) {
            return e.getMessage();
        }
        return null;
    }

    private static String activateError(Id employeeId, String employeeNumber, Date hireDate) {
        return activateError(employeeId, employeeNumber, hireDate, null, null);
    }

    private static String taskError(Id taskId, Boolean done) {
        try {
            OnboardingService.setTaskDone(taskId, done);
        } catch (OnboardingService.OnboardingException e) {
            return e.getMessage();
        }
        return null;
    }
}
