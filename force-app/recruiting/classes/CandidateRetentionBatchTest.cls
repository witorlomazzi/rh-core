@IsTest
private class CandidateRetentionBatchTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static Candidate__c oldCandidate(String label, Integer idleDays) {
        Candidate__c c = RecruitingTestData.buildCandidate(label);
        c.Phone__c = '(11) 90000-0000';
        c.City__c = 'Santos';
        insert c;
        RecruitingTestData.ageCandidate(c.Id, idleDays);
        return c;
    }

    @IsTest
    static void batchAnonymizesOnlyExpiredCandidatesWithoutActiveOrHiredApplications() {
        RecruitingTestData.useRecorder();
        Job_Opening__c opening = RecruitingTestData.opening('Retencao', null, 'Aberta');
        Integer days = HrSettings.get().Candidate_Retention_Days__c.intValue();

        Candidate__c expiredIdle = oldCandidate('idle', days + 10);
        Candidate__c recent = oldCandidate('recent', days - 10);

        Candidate__c expiredActive = oldCandidate('active', days + 10);
        Candidate__c expiredHired = oldCandidate('hired', days + 10);
        Candidate__c expiredRejected = oldCandidate('rejected', days + 10);
        List<Job_Application__c> apps = RecruitingTestData.applications(
            new List<Candidate__c>{ expiredActive, expiredHired, expiredRejected },
            opening.Id
        );
        RecruitingTestData.advanceTo(apps[1].Id, 'Contratado');
        Job_Application__c rejectedApp = apps[2];
        update new Job_Application__c(Id = rejectedApp.Id, Cover_Letter__c = 'Texto livre do candidato');
        update new Job_Application__c(Id = rejectedApp.Id, Stage__c = 'Desistiu');
        // Candidatura nova e mudanca de etapa renovam a ultima atividade: envelhece de novo.
        RecruitingTestData.ageCandidate(expiredActive.Id, days + 10);
        RecruitingTestData.ageCandidate(expiredHired.Id, days + 10);
        RecruitingTestData.ageCandidate(expiredRejected.Id, days + 10);

        Test.startTest();
        Database.executeBatch(new CandidateRetentionBatch(), 200);
        Test.stopTest();

        Assert.isTrue(RecruitingTestData.reloadCandidate(expiredIdle.Id).Anonymized__c, 'Vencido sem candidatura');
        Assert.isTrue(RecruitingTestData.reloadCandidate(expiredRejected.Id).Anonymized__c, 'Vencido com candidatura encerrada');
        Assert.isFalse(RecruitingTestData.reloadCandidate(recent.Id).Anonymized__c, 'Dentro do prazo');
        Assert.isFalse(RecruitingTestData.reloadCandidate(expiredActive.Id).Anonymized__c, 'Candidatura ativa protege');
        Assert.isFalse(RecruitingTestData.reloadCandidate(expiredHired.Id).Anonymized__c, 'Contratado nunca e anonimizado');

        Candidate__c anon = RecruitingTestData.reloadCandidate(expiredIdle.Id);
        Assert.areEqual('Candidato anonimizado', anon.Name);
        Assert.areEqual(('anon-' + expiredIdle.Id + '@anon.invalid').toLowerCase(), anon.Email__c);
        Assert.areEqual(anon.Email__c, anon.Email_Normalized__c);
        Assert.isNull(anon.Phone__c);
        Assert.isNull(anon.City__c);
        Assert.isNull(RecruitingTestData.reloadApplication(rejectedApp.Id).Cover_Letter__c);
    }

    @IsTest
    static void longerRetentionWindowKeepsTheCandidate() {
        Candidate__c c = oldCandidate('janela', 100);
        HrSettings.testOverride = new HR_Setting__mdt(Candidate_Retention_Days__c = 365);
        Test.startTest();
        Database.executeBatch(new CandidateRetentionBatch(), 200);
        Test.stopTest();
        Assert.isFalse(RecruitingTestData.reloadCandidate(c.Id).Anonymized__c, 'Prazo de 365 dias ainda nao venceu');
    }

    @IsTest
    static void shorterRetentionWindowAnonymizesTheCandidate() {
        Candidate__c c = oldCandidate('janela2', 100);
        HrSettings.testOverride = new HR_Setting__mdt(Candidate_Retention_Days__c = 30);
        Test.startTest();
        Database.executeBatch(new CandidateRetentionBatch(), 200);
        Test.stopTest();
        Assert.isTrue(RecruitingTestData.reloadCandidate(c.Id).Anonymized__c, 'Prazo de 30 dias venceu');
    }

    @IsTest
    static void batchSurvivesLargeScope() {
        List<Candidate__c> many = new List<Candidate__c>();
        for (Integer i = 0; i < 200; i++) {
            many.add(RecruitingTestData.buildCandidate('many' + i));
        }
        insert many;
        List<Candidate__c> aged = new List<Candidate__c>();
        for (Candidate__c c : many) {
            aged.add(new Candidate__c(Id = c.Id, Last_Activity_Date__c = Date.today().addDays(-400)));
        }
        TriggerHandler.bypass('CandidateTriggerHandler');
        update aged;
        TriggerHandler.clearBypass('CandidateTriggerHandler');

        Test.startTest();
        Database.executeBatch(new CandidateRetentionBatch(), 200);
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM Candidate__c WHERE Anonymized__c = TRUE AND Id IN :many]);
    }

    @IsTest
    static void scheduleRegistersAWeeklyJob() {
        Test.startTest();
        Id jobId = CandidateRetentionBatch.schedule();
        Test.stopTest();
        CronTrigger job = [SELECT CronExpression, CronJobDetail.Name FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(CandidateRetentionBatch.WEEKLY_CRON, job.CronExpression);
        Assert.areEqual(CandidateRetentionBatch.JOB_NAME, job.CronJobDetail.Name);
    }

    @IsTest
    static void schedulableLaunchesTheBatch() {
        Candidate__c c = oldCandidate('sched', 400);
        Test.startTest();
        new CandidateRetentionBatch().execute((SchedulableContext) null);
        Test.stopTest();
        Assert.isTrue(RecruitingTestData.reloadCandidate(c.Id).Anonymized__c);
    }
}
