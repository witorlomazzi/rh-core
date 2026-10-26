/**
 * Volume: 50 contratacoes em uma unica mudanca de etapa e 200 tarefas mudando de situacao em um unico DML.
 */
@IsTest
private class OnboardingBulkTest {
    @TestSetup
    static void setup() {
        OnboardingTestSupport.createAll();
    }

    @IsTest
    static void fiftyHiresInOneStageChangeCreateFiftyPlansWithEightTasksEach() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 50);
        Assert.areEqual(50, apps.size());

        Test.startTest();
        System.runAs(c.tree.hrUser) {
            OnboardingTestSupport.hire(apps);
        }
        Test.stopTest();

        Set<Id> appIds = new Map<Id, Job_Application__c>(apps).keySet();
        List<Job_Application__c> hired = [SELECT Id, Employee__c FROM Job_Application__c WHERE Id IN :appIds];
        Set<Id> employeeIds = new Set<Id>();
        for (Job_Application__c a : hired) {
            Assert.isNotNull(a.Employee__c, 'Toda candidatura contratada tem colaborador');
            employeeIds.add(a.Employee__c);
        }
        Assert.areEqual(50, employeeIds.size());

        Set<String> numbers = new Set<String>();
        for (Employee__c e : [SELECT Employee_Number__c, Status__c FROM Employee__c WHERE Id IN :employeeIds]) {
            Assert.areEqual('Pre_Admissao', e.Status__c);
            Assert.isTrue(e.Employee_Number__c.startsWith('PRE-'));
            numbers.add(e.Employee_Number__c);
        }
        Assert.areEqual(50, numbers.size(), 'Matriculas provisorias distintas');

        List<Onboarding_Plan__c> plans = [SELECT Id, Total_Tasks__c, Start_Date__c FROM Onboarding_Plan__c WHERE Employee__c IN :employeeIds];
        Assert.areEqual(50, plans.size());
        for (Onboarding_Plan__c p : plans) {
            Assert.areEqual(8, p.Total_Tasks__c.intValue());
            Assert.areEqual(Date.today().addDays(15), p.Start_Date__c);
        }
        Assert.areEqual(400, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__r.Employee__c IN :employeeIds]);
        // 7 tarefas por plano tem responsavel desde o inicio; a do colaborador espera o usuario dele.
        Assert.areEqual(350, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__r.Employee__c IN :employeeIds AND Assigned_To__c != NULL]);
        // 7 tarefas por plano tem responsavel desde o inicio; a do colaborador espera o usuario dele.
    }

    @IsTest
    static void twoHundredTasksChangingStatusInOneDmlUpdateEveryPlan() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 25);
        System.runAs(c.tree.hrUser) {
            OnboardingTestSupport.hire(apps);
        }
        Set<Id> employeeIds = new Set<Id>();
        for (Job_Application__c a : [SELECT Employee__c FROM Job_Application__c WHERE Id IN :new Map<Id, Job_Application__c>(apps).keySet()]) {
            employeeIds.add(a.Employee__c);
        }
        List<Onboarding_Task__c> tasks = [SELECT Id FROM Onboarding_Task__c WHERE Plan__r.Employee__c IN :employeeIds];
        Assert.areEqual(200, tasks.size());

        Test.startTest();
        OnboardingTestSupport.setStatus(tasks, 'Concluida', c.tree.hrUser);
        Test.stopTest();

        Assert.areEqual(25, [SELECT COUNT() FROM Onboarding_Plan__c WHERE Employee__c IN :employeeIds AND Status__c = 'Concluido']);
        Assert.areEqual(200, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__r.Employee__c IN :employeeIds AND Completed_Date__c != NULL]);

        OnboardingTestSupport.setStatus(tasks, 'Pendente', c.tree.hrUser);
        Assert.areEqual(25, [SELECT COUNT() FROM Onboarding_Plan__c WHERE Employee__c IN :employeeIds AND Status__c = 'Nao_Iniciado']);
        Assert.areEqual(0, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__r.Employee__c IN :employeeIds AND Completed_Date__c != NULL]);
    }

    @IsTest
    static void syncingFiftyPlansAtOnceStaysWithinLimits() {
        OnboardingTestSupport.Ctx c = OnboardingTestSupport.load();
        List<Job_Application__c> apps = OnboardingTestSupport.applications(c.opening.Id, 50);
        System.runAs(c.tree.hrUser) {
            OnboardingTestSupport.hire(apps);
        }
        Set<Id> employeeIds = new Set<Id>();
        for (Job_Application__c a : [SELECT Employee__c FROM Job_Application__c WHERE Id IN :new Map<Id, Job_Application__c>(apps).keySet()]) {
            employeeIds.add(a.Employee__c);
        }
        Date newHire = Date.today().addDays(60);
        List<Employee__c> patches = new List<Employee__c>();
        for (Id employeeId : employeeIds) {
            patches.add(new Employee__c(Id = employeeId, Hire_Date__c = newHire));
        }
        update patches;

        Test.startTest();
        System.runAs(c.tree.hrUser) {
            OnboardingService.syncPlans(employeeIds);
        }
        Test.stopTest();

        Assert.areEqual(50, [SELECT COUNT() FROM Onboarding_Plan__c WHERE Employee__c IN :employeeIds AND Start_Date__c = :newHire]);
        Assert.areEqual(50, [SELECT COUNT() FROM Onboarding_Task__c WHERE Plan__r.Employee__c IN :employeeIds AND Order__c = 8 AND Due_Date__c = :newHire.addDays(30)]);
    }
}
