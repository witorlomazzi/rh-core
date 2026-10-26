@IsTest
private class OnboardingControllerTest {
    @TestSetup
    static void setup() {
        OnboardingTestSupport.createAll();
    }

    @IsTest
    static void checklistAndCompletionGoThroughTheController() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        Onboarding_Plan__c plan = OnboardingTestSupport.planOf(employee.Id);
        Onboarding_Task__c managerTask = OnboardingTestSupport.taskOfRole(plan.Id, 'Gestor');

        System.runAs(c.tree.mgr1User) {
            OnboardingService.ChecklistView view = OnboardingController.getChecklist(employee.Id);
            Assert.isTrue(view.hasPlan);
            Assert.areEqual(8, view.total);
            OnboardingController.setTaskDone(managerTask.Id, true);
            Assert.areEqual(1, OnboardingController.getChecklist(plan.Id).resolved);
        }
    }

    @IsTest
    static void overviewActivationAndSyncGoThroughTheController() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);

        Test.startTest();
        System.runAs(c.tree.hrUser) {
            Assert.areEqual(1, OnboardingController.getOverview(false).planCount);
            Assert.areEqual(1, OnboardingController.getActivationContext().employees.size());
            OnboardingController.syncPlan(employee.Id);
            OnboardingController.activate(employee.Id, 'ZZTEST-F1', Date.today().addDays(2), c.tree.mgr2.Id, null);
            Assert.areEqual(0, OnboardingController.getActivationContext().employees.size());
        }
        Test.stopTest();
        Employee__c active = OnboardingTestSupport.reloadEmployee(employee.Id);
        Assert.areEqual('Ativo', active.Status__c);
        Assert.areEqual(c.tree.mgr2.Id, active.Manager__c);
    }

    @IsTest
    static void businessErrorsBecomeFriendlyMessages() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);

        System.runAs(c.tree.mgr1User) {
            Assert.areEqual(OnboardingService.MSG_NOT_HR, messageOf(0, employee.Id));
            Assert.areEqual(OnboardingService.MSG_NOT_HR, messageOf(1, employee.Id));
            Assert.areEqual(OnboardingService.MSG_NOT_HR, messageOf(2, employee.Id));
            Assert.areEqual(OnboardingService.MSG_RECORD_TYPE, messageOf(3, c.opening.Id));
            Assert.areEqual(OnboardingService.MSG_TASK_NOT_FOUND, messageOf(4, c.opening.Id));
        }
    }

    @IsTest
    static void unexpectedErrorsKeepTheDetailAfterAPrefix() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        Employee__c employee = OnboardingTestSupport.hireOne(c);
        User outsider = HrTestDataFactory.user('zzout', null);

        System.runAs(outsider) {
            for (Integer i = 0; i < 5; i++) {
                String message = messageOf(i, employee.Id);
                Assert.isNotNull(message, 'Operacao ' + i + ' deveria falhar');
                if (i < 3) {
                    Assert.areEqual(OnboardingService.MSG_NOT_HR, message, 'Operacoes do RH recusam antes de qualquer consulta');
                } else {
                    Assert.isTrue(message.startsWith('Não foi possível concluir a operação.'), message);
                }
            }
        }
    }

    /** Executa uma das operacoes do controller e devolve a mensagem da AuraHandledException (ou null). */
    private static String messageOf(Integer operation, Id recordId) {
        try {
            if (operation == 0) {
                OnboardingController.getActivationContext();
            } else if (operation == 1) {
                OnboardingController.syncPlan(recordId);
            } else if (operation == 2) {
                OnboardingController.activate(recordId, 'ZZTEST-G1', Date.today(), null, null);
            } else if (operation == 3) {
                OnboardingController.getChecklist(recordId);
            } else {
                OnboardingController.setTaskDone(recordId, true);
            }
        } catch (AuraHandledException e) {
            return e.getMessage();
        }
        return null;
    }
}
