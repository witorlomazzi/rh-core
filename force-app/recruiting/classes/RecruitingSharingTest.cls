@IsTest
private class RecruitingSharingTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static Set<Id> appShares(Id applicationId) {
        return RecruitingTestData.shareUsers(
            Job_Application__Share.SObjectType,
            applicationId,
            RecruitingSharingService.APPLICATION_REASON
        );
    }

    private static Set<Id> candidateShares(Id candidateId) {
        return RecruitingTestData.shareUsers(
            Candidate__Share.SObjectType,
            candidateId,
            RecruitingSharingService.CANDIDATE_REASON
        );
    }

    @IsTest
    static void hiringManagerReceivesApplicationAndCandidateShares() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c opening = RecruitingTestData.opening('Share', t.mgr1.Id, 'Aberta');
        Candidate__c candidate = RecruitingTestData.candidate('share');
        Job_Application__c app = RecruitingTestData.application(candidate.Id, opening.Id);

        Assert.areEqual(new Set<Id>{ t.mgr1User.Id }, appShares(app.Id));
        Assert.areEqual(new Set<Id>{ t.mgr1User.Id }, candidateShares(candidate.Id));
        Job_Application__Share share = [
            SELECT AccessLevel
            FROM Job_Application__Share
            WHERE ParentId = :app.Id AND RowCause = :RecruitingSharingService.APPLICATION_REASON
        ];
        Assert.areEqual('Edit', share.AccessLevel);
        Candidate__Share cShare = [
            SELECT AccessLevel
            FROM Candidate__Share
            WHERE ParentId = :candidate.Id AND RowCause = :RecruitingSharingService.CANDIDATE_REASON
        ];
        Assert.areEqual('Read', cShare.AccessLevel);
    }

    @IsTest
    static void openingWithoutManagerOrManagerWithoutUserCreatesNoShares() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c noManager = RecruitingTestData.opening('Sem gestor', null, 'Aberta');
        Job_Opening__c managerWithoutUser = RecruitingTestData.opening('Gestor sem usuario', t.mgr2.Id, 'Aberta');
        Job_Application__c a = RecruitingTestData.applications(RecruitingTestData.candidates('s1', 1), noManager.Id)[0];
        Job_Application__c b = RecruitingTestData.applications(RecruitingTestData.candidates('s2', 1), managerWithoutUser.Id)[0];
        Assert.isTrue(appShares(a.Id).isEmpty());
        Assert.isTrue(appShares(b.Id).isEmpty());
    }

    @IsTest
    static void changingTheHiringManagerRebuildsAllShares() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c opening = RecruitingTestData.opening('Troca', t.mgr1.Id, 'Aberta');
        List<Candidate__c> candidates = RecruitingTestData.candidates('troca', 5);
        List<Job_Application__c> apps = RecruitingTestData.applications(candidates, opening.Id);

        Test.startTest();
        update new Job_Opening__c(Id = opening.Id, Hiring_Manager__c = t.emp1.Id);
        Test.stopTest();

        for (Integer i = 0; i < apps.size(); i++) {
            Assert.areEqual(new Set<Id>{ t.emp1User.Id }, appShares(apps[i].Id), 'Candidatura ' + i);
            Assert.areEqual(new Set<Id>{ t.emp1User.Id }, candidateShares(candidates[i].Id), 'Candidato ' + i);
        }

        update new Job_Opening__c(Id = opening.Id, Hiring_Manager__c = null);
        Assert.isTrue(appShares(apps[0].Id).isEmpty(), 'Sem gestor, sem share');
        Assert.isTrue(candidateShares(candidates[0].Id).isEmpty());
    }

    @IsTest
    static void candidateShareSurvivesWhileAnotherApplicationNeedsIt() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c first = RecruitingTestData.opening('Primeira', t.mgr1.Id, 'Aberta');
        Job_Opening__c second = RecruitingTestData.opening('Segunda', t.mgr1.Id, 'Aberta');
        Candidate__c candidate = RecruitingTestData.candidate('multi');
        Job_Application__c appFirst = RecruitingTestData.applications(new List<Candidate__c>{ candidate }, first.Id)[0];
        Job_Application__c appSecond = RecruitingTestData.applications(new List<Candidate__c>{ candidate }, second.Id)[0];
        Assert.areEqual(new Set<Id>{ t.mgr1User.Id }, candidateShares(candidate.Id));

        update new Job_Opening__c(Id = first.Id, Hiring_Manager__c = t.emp1.Id);
        Assert.areEqual(new Set<Id>{ t.mgr1User.Id, t.emp1User.Id }, candidateShares(candidate.Id), 'Cada gestor tem o seu');
        Assert.areEqual(new Set<Id>{ t.emp1User.Id }, appShares(appFirst.Id));

        update new Job_Opening__c(Id = second.Id, Hiring_Manager__c = t.emp1.Id);
        Assert.areEqual(new Set<Id>{ t.emp1User.Id }, candidateShares(candidate.Id), 'Gestor antigo perde o candidato');
    }

    @IsTest
    static void recalcBatchRebuildsMissingShares() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c opening = RecruitingTestData.opening('Batch', t.mgr1.Id, 'Aberta');
        Candidate__c candidate = RecruitingTestData.candidate('batch');
        Job_Application__c app = RecruitingTestData.applications(new List<Candidate__c>{ candidate }, opening.Id)[0];
        delete [SELECT Id FROM Job_Application__Share WHERE ParentId = :app.Id AND RowCause = :RecruitingSharingService.APPLICATION_REASON];
        delete [SELECT Id FROM Candidate__Share WHERE ParentId = :candidate.Id AND RowCause = :RecruitingSharingService.CANDIDATE_REASON];
        Assert.isTrue(appShares(app.Id).isEmpty());

        Test.startTest();
        Database.executeBatch(new RecruitingSharingRecalcBatch(new Set<Id>{ opening.Id }), 200);
        Test.stopTest();

        Assert.areEqual(new Set<Id>{ t.mgr1User.Id }, appShares(app.Id));
        Assert.areEqual(new Set<Id>{ t.mgr1User.Id }, candidateShares(candidate.Id));
    }

    @IsTest
    static void recalcBatchWithoutFilterCoversAllOpenings() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c opening = RecruitingTestData.opening('Batch geral', t.mgr1.Id, 'Aberta');
        Job_Application__c app = RecruitingTestData.applications(RecruitingTestData.candidates('geral', 1), opening.Id)[0];
        delete [SELECT Id FROM Job_Application__Share WHERE ParentId = :app.Id AND RowCause = :RecruitingSharingService.APPLICATION_REASON];
        Test.startTest();
        Database.executeBatch(new RecruitingSharingRecalcBatch(), 200);
        Test.stopTest();
        Assert.areEqual(new Set<Id>{ t.mgr1User.Id }, appShares(app.Id));
    }

    @IsTest
    static void recalculateHandlesEmptyInput() {
        RecruitingSharingService.recalculate(null);
        RecruitingSharingService.recalculate(new List<Job_Application__c>());
        RecruitingSharingService.recalculateForOpenings(null);
        RecruitingSharingService.recalculateForOpenings(new Set<Id>());
        Assert.isTrue(true);
    }
}
