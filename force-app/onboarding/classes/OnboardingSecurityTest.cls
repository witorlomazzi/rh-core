/**
 * Seguranca do onboarding (spec 02): colaborador A nao ve o plano de B, gestor ve o plano da propria equipe e nao o de
 * outra, usuario sem permission set nao recebe dado, e a regra O5 vale tambem para DML direto (trigger).
 */
@IsTest
private class OnboardingSecurityTest {
    @TestSetup
    static void setup() {
        OnboardingTestSupport.createAll();
    }

    @IsTest
    static void unrelatedEmployeeDoesNotSeeTheNewHirePlan() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c task = OnboardingTestSupport.taskOfRole(plan.Id, 'Gestor');

        System.runAs(c.tree.emp2User) {
            Assert.isFalse(OnboardingService.checklist(employee.Id).hasPlan, 'Colaborador sem relacao nao ve o plano');
            Assert.isFalse(OnboardingService.checklist(plan.Id).hasPlan);
            Assert.areEqual(0, OnboardingService.overview(true).planCount);
            Assert.areEqual(0, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__c = :plan.Id]);
            try {
                OnboardingService.setTaskDone(task.Id, true);
                Assert.fail('Tarefa fora do alcance');
            } catch (OnboardingService.OnboardingException e) {
                Assert.areEqual(OnboardingService.MSG_TASK_NOT_FOUND, e.getMessage());
            }
        }
    }

    @IsTest
    static void hiringManagerSeesTheTeamPlanButAnotherManagerDoesNot() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);

        System.runAs(c.tree.mgr1User) {
            OnboardingService.ChecklistView view = OnboardingService.checklist(employee.Id);
            Assert.isTrue(view.hasPlan, 'O gestor contratante acompanha o plano');
            Assert.isFalse(view.isHr);
            Assert.areEqual(8, view.total);
            Assert.areEqual(1, OnboardingService.overview(false).planCount);
        }
        // Gestor em outra linha da hierarquia: o novo contratado e subordinado do gestor 1, nao do gestor 2.
        update new Employee__c(Id = employee.Id, Manager__c = c.tree.mgr2.Id);
        System.runAs(c.tree.mgr1User) {
            Assert.isFalse(OnboardingService.checklist(employee.Id).hasPlan, 'Saiu da equipe do gestor 1');
        }
        Assert.areEqual(8, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__c = :plan.Id]);
    }

    @IsTest
    static void userWithoutPermissionSetGetsNoDataAndNoWrite() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c task = OnboardingTestSupport.taskOfRole(plan.Id, 'Gestor');
        User outsider = HrTestDataFactory.user('zzout', null);

        System.runAs(outsider) {
            Boolean blocked = false;
            try {
                OnboardingService.checklist(employee.Id);
            } catch (Exception e) {
                blocked = true;
            }
            Assert.isTrue(blocked, 'Sem permission set a consulta falha, nunca devolve dado');
            blocked = false;
            try {
                OnboardingService.setTaskDone(task.Id, true);
            } catch (Exception e) {
                blocked = true;
            }
            Assert.isTrue(blocked);
            Assert.isFalse(OnboardingService.isHr());
        }
    }

    @IsTest
    static void directUpdateOfSomeoneElsesTaskIsRefusedByTheTrigger() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c hrTask = OnboardingTestSupport.taskOfRole(plan.Id, 'RH');
        Onboarding_Task__c managerTask = OnboardingTestSupport.taskOfRole(plan.Id, 'Gestor');

        System.runAs(c.tree.mgr1User) {
            try {
                update new Onboarding_Task__c(Id = hrTask.Id, Status__c = 'Concluida');
                Assert.fail('O gestor nao conclui tarefa do RH, nem por DML');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains(OnboardingTaskTriggerHandler.NOT_ASSIGNED_MESSAGE), e.getMessage());
            }
            update new Onboarding_Task__c(Id = managerTask.Id, Status__c = 'Concluida');
        }
        Assert.areEqual('Pendente', [SELECT Status__c FROM Onboarding_Task__c WHERE Id = :hrTask.Id].Status__c);
        Assert.areEqual('Concluida', [SELECT Status__c FROM Onboarding_Task__c WHERE Id = :managerTask.Id].Status__c);
    }

    @IsTest
    static void employeeCannotReassignOrChangeDueDates() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c managerTask = OnboardingTestSupport.taskOfRole(plan.Id, 'Gestor');

        System.runAs(c.tree.mgr1User) {
            Onboarding_Task__c patch = new Onboarding_Task__c(Id = managerTask.Id, Assigned_To__c = c.tree.emp1User.Id, Due_Date__c = Date.today().addDays(90));
            try {
                Database.update(patch, AccessLevel.USER_MODE);
                Assert.fail('Sem FLS de edicao em Assigned_To__c e Due_Date__c');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().containsIgnoreCase('inaccessible'), e.getMessage());
            }
        }
        Onboarding_Task__c unchanged = [SELECT Assigned_To__c, Due_Date__c FROM Onboarding_Task__c WHERE Id = :managerTask.Id];
        Assert.areEqual(managerTask.Assigned_To__c, unchanged.Assigned_To__c);
        Assert.areEqual(managerTask.Due_Date__c, unchanged.Due_Date__c);
    }

    @IsTest
    static void onlyHrSeesEveryPlan() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        System.runAs(c.tree.hrUser) {
            Assert.isTrue(OnboardingService.isHr());
            Assert.isTrue(OnboardingService.checklist(employee.Id).hasPlan);
            Assert.areEqual(1, OnboardingService.overview(true).planCount);
        }
        System.runAs(c.tree.emp1User) {
            Assert.isFalse(OnboardingService.isHr());
        }
    }
}
