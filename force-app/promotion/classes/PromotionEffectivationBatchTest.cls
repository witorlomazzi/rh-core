@IsTest
private class PromotionEffectivationBatchTest {
    @TestSetup
    static void setup() {
        PromotionTestSupport.createAll();
    }

    private static List<Employee__c> createTeam(PromotionTestSupport.Ctx c, Integer size) {
        List<Employee__c> team = new List<Employee__c>();
        for (Integer i = 0; i < size; i++) {
            Employee__c e = HrTestDataFactory.buildEmployee(null, null);
            e.Position__c = c.posA.Id;
            e.Department__c = c.department.Id;
            e.Salary__c = PromotionTestSupport.BASE_SALARY;
            team.add(e);
        }
        insert team;
        PositionHistoryService.createAdmission(new Map<Id, Employee__c>(team).keySet());
        return team;
    }

    @IsTest
    static void effectivatesTwoHundredPromotionsInOneChunk() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Employee__c> team = createTeam(c, 200);
        PromotionTestSupport.approvedRequests(team, c.posB.Id, 6000, Date.today());
        Date today = Date.today();
        Date yesterday = today.addDays(-1);

        Test.startTest();
        Database.executeBatch(new PromotionEffectivationBatch(), 200);
        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM Promotion_Request__c WHERE Status__c = 'Efetivado' AND Employee__c IN :team]);
        System.assertEquals(200, [SELECT COUNT() FROM Employee__c WHERE Id IN :team AND Position__c = :c.posB.Id AND Salary__c = 6000]);
        System.assertEquals(
            200,
            [
                SELECT COUNT()
                FROM Position_History__c
                WHERE Employee__c IN :team AND Change_Reason__c = 'Promocao' AND End_Date__c = NULL AND Start_Date__c = :today
            ]
        );
        System.assertEquals(
            200,
            [SELECT COUNT() FROM Position_History__c WHERE Employee__c IN :team AND Change_Reason__c = 'Admissao' AND End_Date__c = :yesterday]
        );
    }

    @IsTest
    static void leavesFutureDatedAndNotApprovedAlone() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Employee__c> team = createTeam(c, 3);
        List<Promotion_Request__c> future = PromotionTestSupport.approvedRequests(
            new List<Employee__c>{ team[0] },
            c.posB.Id,
            6000,
            Date.today().addDays(5)
        );
        List<Promotion_Request__c> pending = PromotionTestSupport.approvedRequests(
            new List<Employee__c>{ team[1] },
            c.posB.Id,
            6000,
            Date.today()
        );
        List<Promotion_Request__c> due = PromotionTestSupport.approvedRequests(
            new List<Employee__c>{ team[2] },
            c.posB.Id,
            6000,
            Date.today().addDays(-3)
        );
        pending[0].Status__c = 'Pendente';
        TriggerHandler.bypass('PromotionRequestTriggerHandler');
        update pending;
        TriggerHandler.clearBypass('PromotionRequestTriggerHandler');

        Test.startTest();
        Database.executeBatch(new PromotionEffectivationBatch());
        Test.stopTest();

        System.assertEquals('Aprovado', [SELECT Status__c FROM Promotion_Request__c WHERE Id = :future[0].Id].Status__c);
        System.assertEquals('Pendente', [SELECT Status__c FROM Promotion_Request__c WHERE Id = :pending[0].Id].Status__c);
        System.assertEquals('Efetivado', [SELECT Status__c FROM Promotion_Request__c WHERE Id = :due[0].Id].Status__c, 'Atrasada tambem efetiva');
        Position_History__c opened = [SELECT Start_Date__c FROM Position_History__c WHERE Employee__c = :team[2].Id AND End_Date__c = NULL];
        System.assertEquals(Date.today().addDays(-3), opened.Start_Date__c, 'O historico comeca na data de efetivacao, nao na da execucao');
    }

    @IsTest
    static void schedulableStartsTheBatch() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Employee__c> team = createTeam(c, 1);
        PromotionTestSupport.approvedRequests(team, c.posB.Id, 6000, Date.today());
        Test.startTest();
        new PromotionEffectivationBatch().execute((SchedulableContext) null);
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Promotion_Request__c WHERE Status__c = 'Efetivado' AND Employee__c IN :team]);
    }

    @IsTest
    static void dailyScheduleIsRegistered() {
        Test.startTest();
        Id jobId = PromotionEffectivationBatch.scheduleDaily();
        Test.stopTest();
        CronTrigger ct = [SELECT CronExpression, CronJobDetail.Name FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(PromotionEffectivationBatch.CRON_DAILY, ct.CronExpression);
        System.assertEquals(PromotionEffectivationBatch.JOB_NAME, ct.CronJobDetail.Name);
    }
}
