@IsTest
private class JobApplicationLifecycleTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static String insertError(SObject record) {
        try {
            insert record;
        } catch (DmlException e) {
            return e.getDmlMessage(0);
        }
        return null;
    }

    @IsTest
    static void duplicateApplicationForTheSameOpeningIsRejected() {
        Job_Opening__c opening = RecruitingTestData.opening('Duplicada', null, 'Aberta');
        Candidate__c candidate = RecruitingTestData.candidate('dup');
        Job_Application__c first = RecruitingTestData.application(candidate.Id, opening.Id);
        Assert.areEqual(String.valueOf(candidate.Id) + '|' + String.valueOf(opening.Id), first.Unique_Key__c);

        String error = insertError(new Job_Application__c(Candidate__c = candidate.Id, Job_Opening__c = opening.Id));
        Assert.areEqual('Este candidato já se inscreveu nesta vaga.', error);

        Job_Opening__c other = RecruitingTestData.opening('Outra', null, 'Aberta');
        Assert.isNotNull(RecruitingTestData.application(candidate.Id, other.Id).Id, 'Outra vaga e permitida');
    }

    @IsTest
    static void duplicateInsideTheSameBatchIsRejected() {
        Job_Opening__c opening = RecruitingTestData.opening('Lote duplicado', null, 'Aberta');
        Candidate__c candidate = RecruitingTestData.candidate('lote');
        List<Job_Application__c> batch = new List<Job_Application__c>{
            new Job_Application__c(Candidate__c = candidate.Id, Job_Opening__c = opening.Id),
            new Job_Application__c(Candidate__c = candidate.Id, Job_Opening__c = opening.Id)
        };
        List<Database.SaveResult> results = Database.insert(batch, false);
        Assert.isTrue(results[0].isSuccess());
        Assert.isFalse(results[1].isSuccess());
        Assert.areEqual(JobApplicationTriggerHandler.DUPLICATE_MESSAGE, results[1].getErrors()[0].getMessage());
    }

    @IsTest
    static void onlyOpenOpeningsAcceptNewApplications() {
        for (String status : new List<String>{ 'Rascunho', 'Pausada', 'Fechada', 'Cancelada' }) {
            Job_Opening__c opening = RecruitingTestData.opening('Status ' + status, null, status);
            String error = insertError(
                new Job_Application__c(Candidate__c = RecruitingTestData.candidate('st' + status).Id, Job_Opening__c = opening.Id)
            );
            Assert.areEqual(JobApplicationTriggerHandler.CLOSED_OPENING_MESSAGE, error, status);
        }
        Job_Opening__c open = RecruitingTestData.opening('Aberta ok', null, 'Aberta');
        Assert.isNotNull(RecruitingTestData.application(RecruitingTestData.candidate('ok').Id, open.Id).Id);
    }

    @IsTest
    static void newApplicationMustStartAtTheInitialStage() {
        Job_Opening__c opening = RecruitingTestData.opening('Inicio', null, 'Aberta');
        String error = insertError(
            new Job_Application__c(
                Candidate__c = RecruitingTestData.candidate('ini').Id,
                Job_Opening__c = opening.Id,
                Stage__c = 'Contratado'
            )
        );
        Assert.isNotNull(error);
        Assert.isTrue(error.contains('começa na etapa'), error);
    }

    @IsTest
    static void insertScoreOutOfRangeIsRejected() {
        Job_Opening__c opening = RecruitingTestData.opening('Nota insert', null, 'Aberta');
        String error = insertError(
            new Job_Application__c(
                Candidate__c = RecruitingTestData.candidate('ni').Id,
                Job_Opening__c = opening.Id,
                Score__c = 8
            )
        );
        Assert.areEqual(JobApplicationTriggerHandler.SCORE_MESSAGE, error);
    }

    @IsTest
    static void applyCreatesCandidateAndApplicationFromDto() {
        Job_Opening__c opening = RecruitingTestData.opening('Portal', null, 'Aberta');
        CandidateService.CandidateInput input = new CandidateService.CandidateInput();
        input.name = 'ZZTEST-Carla Mendes';
        input.email = 'zztest.carla@exemplo.com';
        input.consentGiven = true;

        Job_Application__c app = JobApplicationService.apply(input, opening.Id, 'Portal', 'Quero participar');

        Job_Application__c reloaded = RecruitingTestData.reloadApplication(app.Id);
        Assert.areEqual('Nova', reloaded.Stage__c);
        Assert.areEqual('Quero participar', reloaded.Cover_Letter__c);
        Candidate__c candidate = RecruitingTestData.reloadCandidate(reloaded.Candidate__c);
        Assert.areEqual('zztest.carla@exemplo.com', candidate.Email_Normalized__c);
        Assert.isTrue(candidate.Consent_Given__c);
        Assert.areEqual(1, RecruitingTestData.reloadOpening(opening.Id).Applications_Count__c);

        // Segunda tentativa com o mesmo e-mail: mesma pessoa, candidatura duplicada recusada.
        try {
            JobApplicationService.apply(input, opening.Id, 'Portal', null);
            Assert.fail('Candidatura repetida deve falhar');
        } catch (JobApplicationService.RecruitingException e) {
            Assert.areEqual('Este candidato já se inscreveu nesta vaga.', e.getMessage());
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c = 'zztest.carla@exemplo.com']);
    }

    @IsTest
    static void applyToAClosedOpeningRollsBackTheNewCandidate() {
        Job_Opening__c closed = RecruitingTestData.opening('Fechada portal', null, 'Fechada');
        CandidateService.CandidateInput input = new CandidateService.CandidateInput();
        input.name = 'ZZTEST-Daniel Rocha';
        input.email = 'zztest.daniel@exemplo.com';
        try {
            JobApplicationService.apply(input, closed.Id, 'Portal', null);
            Assert.fail('Vaga fechada recusa candidatura');
        } catch (JobApplicationService.RecruitingException e) {
            Assert.areEqual(JobApplicationTriggerHandler.CLOSED_OPENING_MESSAGE, e.getMessage());
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c = 'zztest.daniel@exemplo.com'], 'Candidato desfeito');
        try {
            JobApplicationService.apply(input, null, 'Portal', null);
            Assert.fail('Sem vaga');
        } catch (JobApplicationService.RecruitingException e) {
            Assert.isNotNull(e.getMessage());
        }
        try {
            JobApplicationService.apply(new CandidateService.CandidateInput(), closed.Id, 'Portal', null);
            Assert.fail('Entrada vazia');
        } catch (JobApplicationService.RecruitingException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void everyStageChangeTouchesTheCandidateActivity() {
        Job_Opening__c opening = RecruitingTestData.opening('Atividade', null, 'Aberta');
        Candidate__c candidate = RecruitingTestData.candidate('ativ');
        Job_Application__c app = RecruitingTestData.application(candidate.Id, opening.Id);
        RecruitingTestData.ageCandidate(candidate.Id, 90);
        Assert.areEqual(Date.today().addDays(-90), RecruitingTestData.reloadCandidate(candidate.Id).Last_Activity_Date__c);
        app.Stage__c = 'Triagem';
        update app;
        Assert.areEqual(Date.today(), RecruitingTestData.reloadCandidate(candidate.Id).Last_Activity_Date__c);
    }

    @IsTest
    static void deletingAnOpeningWithApplicationsIsBlocked() {
        Job_Opening__c opening = RecruitingTestData.opening('Restrita', null, 'Aberta');
        RecruitingTestData.application(RecruitingTestData.candidate('rest').Id, opening.Id);
        try {
            delete opening;
            Assert.fail('Vaga com candidaturas nao pode ser excluida');
        } catch (DmlException e) {
            Assert.areEqual(StatusCode.DELETE_FAILED, e.getDmlType(0));
        }
    }
}
