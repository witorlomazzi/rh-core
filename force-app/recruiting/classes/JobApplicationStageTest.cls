@IsTest
private class JobApplicationStageTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static Job_Application__c newApplication(String label) {
        Job_Opening__c opening = RecruitingTestData.opening('Funil ' + label, null, 'Aberta');
        return RecruitingTestData.application(RecruitingTestData.candidate(label).Id, opening.Id);
    }

    private static String updateError(Job_Application__c app) {
        try {
            update app;
        } catch (DmlException e) {
            return e.getDmlMessage(0);
        }
        return null;
    }

    @IsTest
    static void newApplicationStartsAtTheFirstStageWithInitialHistory() {
        Job_Application__c app = newApplication('inicio');
        Assert.areEqual('Nova', app.Stage__c);
        Assert.isNotNull(app.Stage_Entered_Date__c);
        Assert.areEqual(RecruitingQueue.id(), app.OwnerId);
        List<Application_Stage_History__c> history = RecruitingTestData.history(app.Id);
        Assert.areEqual(1, history.size());
        Assert.isNull(history[0].From_Stage__c);
        Assert.areEqual('Nova', history[0].To_Stage__c);
        Assert.areEqual(UserInfo.getUserId(), history[0].Changed_By__c);
    }

    @IsTest
    static void fullFunnelWalkCreatesHistoryForEachStep() {
        RecruitingTestData.HiredRecorder recorder = RecruitingTestData.useRecorder();
        Job_Application__c app = newApplication('walk');
        Datetime before = Datetime.now();

        RecruitingTestData.advanceTo(app.Id, 'Contratado');

        Job_Application__c done = RecruitingTestData.reloadApplication(app.Id);
        Assert.areEqual('Contratado', done.Stage__c);
        List<Application_Stage_History__c> history = RecruitingTestData.history(app.Id);
        Assert.areEqual(6, history.size(), 'Entrada + 5 mudancas');
        List<String> expected = new List<String>{ 'Nova', 'Triagem', 'Entrevista_RH', 'Entrevista_Tecnica', 'Proposta', 'Contratado' };
        for (Integer i = 0; i < expected.size(); i++) {
            Assert.areEqual(expected[i], history[i].To_Stage__c);
        }
        Assert.areEqual('Nova', history[1].From_Stage__c);
        Assert.isNotNull(history[1].Days_In_Previous_Stage__c);
        Assert.isTrue(done.Stage_Entered_Date__c >= before.addSeconds(-2), 'Data de entrada na etapa atualizada');
        Assert.isTrue(recorder.handled.contains(app.Id), 'Contratado avisa a admissao');
        Assert.areEqual(1, recorder.calls);
        Assert.areEqual(Date.today(), RecruitingTestData.reloadCandidate(done.Candidate__c).Last_Activity_Date__c);
    }

    @IsTest
    static void daysInPreviousStageAreRecorded() {
        Job_Application__c app = newApplication('dias');
        RecruitingTestData.ageStage(app.Id, 3);
        app.Stage__c = 'Triagem';
        update app;
        List<Application_Stage_History__c> history = RecruitingTestData.history(app.Id);
        Application_Stage_History__c move = history[history.size() - 1];
        Assert.areEqual('Nova', move.From_Stage__c);
        Assert.isTrue(move.Days_In_Previous_Stage__c >= 3.0 && move.Days_In_Previous_Stage__c < 3.2, String.valueOf(move.Days_In_Previous_Stage__c));
    }

    @IsTest
    static void invalidTransitionsAreRejected() {
        Job_Application__c app = newApplication('invalida');
        app.Stage__c = 'Proposta';
        String error = updateError(app);
        Assert.areEqual('Mudança de etapa não permitida: de Nova para Proposta.', error);
        Assert.areEqual('Nova', RecruitingTestData.reloadApplication(app.Id).Stage__c);

        app = RecruitingTestData.reloadApplication(app.Id);
        app.Stage__c = 'Triagem';
        update app;
        app.Stage__c = 'Nova';
        Assert.isTrue(updateError(app).startsWith('Mudança de etapa não permitida: de Triagem'), 'Nao volta etapa');
        Assert.areEqual(2, RecruitingTestData.history(app.Id).size(), 'Mudanca recusada nao grava historico');
    }

    @IsTest
    static void terminalStagesCannotMove() {
        Job_Opening__c opening = RecruitingTestData.opening('Terminais', null, 'Aberta');
        List<Job_Application__c> apps = RecruitingTestData.applications(RecruitingTestData.candidates('term', 3), opening.Id);
        RecruitingTestData.useRecorder();
        update new List<Job_Application__c>{
            new Job_Application__c(Id = apps[0].Id, Stage__c = 'Reprovado', Rejection_Reason__c = 'Outro'),
            new Job_Application__c(Id = apps[1].Id, Stage__c = 'Desistiu')
        };
        RecruitingTestData.advanceTo(apps[2].Id, 'Contratado');
        for (Job_Application__c a : apps) {
            String error = updateError(new Job_Application__c(Id = a.Id, Stage__c = 'Triagem'));
            Assert.isTrue(error.startsWith('Mudança de etapa não permitida'), error);
        }
    }

    @IsTest
    static void rejectionRequiresAReason() {
        Job_Application__c app = newApplication('motivo');
        app.Stage__c = 'Reprovado';
        Assert.areEqual('Informe o motivo da reprovação.', updateError(app));
        app.Rejection_Reason__c = 'Salario';
        update app;
        Job_Application__c rejected = RecruitingTestData.reloadApplication(app.Id);
        Assert.areEqual('Reprovado', rejected.Stage__c);
        Assert.areEqual('Salario', rejected.Rejection_Reason__c);
    }

    @IsTest
    static void proposalRequiresAScore() {
        Job_Application__c app = newApplication('nota');
        RecruitingTestData.advanceTo(app.Id, 'Entrevista_Tecnica');
        app = RecruitingTestData.reloadApplication(app.Id);
        app.Stage__c = 'Proposta';
        String error = updateError(app);
        Assert.isNotNull(error);
        Assert.isTrue(error.contains('nota'), error);
        app.Score__c = 5;
        update app;
        Assert.areEqual('Proposta', RecruitingTestData.reloadApplication(app.Id).Stage__c);
    }

    @IsTest
    static void scoreMustBeBetweenZeroAndFive() {
        Job_Application__c app = newApplication('faixa');
        app.Score__c = 7;
        Assert.areEqual('A nota deve estar entre 0 e 5.', updateError(app));
        app.Score__c = 0;
        update app;
        Assert.areEqual(0, RecruitingTestData.reloadApplication(app.Id).Score__c);
    }

    @IsTest
    static void stageEnteredDateCannotBeEditedByHand() {
        Job_Application__c app = newApplication('data');
        Datetime original = app.Stage_Entered_Date__c;
        app.Stage_Entered_Date__c = original.addDays(-10);
        update app;
        Assert.areEqual(original, RecruitingTestData.reloadApplication(app.Id).Stage_Entered_Date__c);
    }

    @IsTest
    static void candidateOfAnApplicationCannotChange() {
        Job_Application__c app = newApplication('cand');
        app.Candidate__c = RecruitingTestData.candidate('outro').Id;
        Assert.areEqual(JobApplicationTriggerHandler.CANDIDATE_LOCKED_MESSAGE, updateError(app));
    }

    @IsTest
    static void bulkOf200ApplicationsMovesInOneDml() {
        Job_Opening__c opening = RecruitingTestData.opening('Lote 200', null, 'Aberta');
        List<Candidate__c> candidates = new List<Candidate__c>();
        for (Integer i = 0; i < 200; i++) {
            candidates.add(RecruitingTestData.buildCandidate('b' + i));
        }
        insert candidates;
        List<Job_Application__c> apps = new List<Job_Application__c>();
        for (Candidate__c c : candidates) {
            apps.add(new Job_Application__c(Candidate__c = c.Id, Job_Opening__c = opening.Id));
        }
        insert apps;
        Assert.areEqual(200, RecruitingTestData.reloadOpening(opening.Id).Applications_Count__c);

        Test.startTest();
        for (Job_Application__c a : apps) {
            a.Stage__c = 'Triagem';
        }
        update apps;
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM Job_Application__c WHERE Job_Opening__c = :opening.Id AND Stage__c = 'Triagem']);
        Assert.areEqual(200, [SELECT COUNT() FROM Application_Stage_History__c WHERE To_Stage__c = 'Triagem' AND Job_Application__r.Job_Opening__c = :opening.Id]);
    }

    @IsTest
    static void bulkOf200ThroughTheServiceIsAllOrNothing() {
        // Org limpa: o administrador de teste nao tem permissao de campo sobre os campos do produto.
        User adminUser = HrTestDataFactory.user('zzadm', 'HR_Admin');
        System.runAs(adminUser) {
            Job_Opening__c opening = RecruitingTestData.opening('Servico 200', null, 'Aberta');
            List<Candidate__c> candidates = new List<Candidate__c>();
            for (Integer i = 0; i < 200; i++) {
                candidates.add(RecruitingTestData.buildCandidate('s' + i));
            }
            insert candidates;
            List<Job_Application__c> apps = new List<Job_Application__c>();
            for (Candidate__c c : candidates) {
                apps.add(new Job_Application__c(Candidate__c = c.Id, Job_Opening__c = opening.Id));
            }
            insert apps;

            List<JobApplicationService.StageChange> changes = new List<JobApplicationService.StageChange>();
            for (Job_Application__c a : apps) {
                changes.add(new JobApplicationService.StageChange(a.Id, 'Triagem', null, null));
            }
            Test.startTest();
            List<Job_Application__c> moved = JobApplicationService.changeStages(changes);
            Test.stopTest();
            Assert.areEqual(200, moved.size());
            Assert.areEqual(200, [SELECT COUNT() FROM Job_Application__c WHERE Stage__c = 'Triagem' AND Job_Opening__c = :opening.Id]);

            // Um pedido invalido derruba o lote inteiro.
            List<JobApplicationService.StageChange> mixed = new List<JobApplicationService.StageChange>();
            for (Integer i = 0; i < 3; i++) {
                mixed.add(new JobApplicationService.StageChange(apps[i].Id, 'Entrevista_RH', null, null));
            }
            mixed.add(new JobApplicationService.StageChange(apps[3].Id, 'Contratado', null, null));
            try {
                JobApplicationService.changeStages(mixed);
                Assert.fail('Lote invalido deve falhar');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.isTrue(e.getMessage().startsWith('Mudança de etapa não permitida'), e.getMessage());
            }
            Assert.areEqual(0, [SELECT COUNT() FROM Job_Application__c WHERE Stage__c = 'Entrevista_RH' AND Job_Opening__c = :opening.Id]);
            }
    }

    @IsTest
    static void serviceValidatesBeforeTheDml() {
        // Org limpa: o administrador de teste nao tem permissao de campo sobre os campos do produto.
        User adminUser = HrTestDataFactory.user('zzadm', 'HR_Admin');
        System.runAs(adminUser) {
            Job_Application__c app = newApplication('svc');
            try {
                JobApplicationService.changeStage(app.Id, 'Reprovado', null, null);
                Assert.fail('Sem motivo deve falhar');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.areEqual('Informe o motivo da reprovação.', e.getMessage());
            }
            Job_Application__c moved = JobApplicationService.changeStage(app.Id, 'Reprovado', 'Perfil', null);
            Assert.areEqual('Reprovado', moved.Stage__c);
            Assert.areEqual('Perfil', moved.Rejection_Reason__c);

            Job_Application__c same = JobApplicationService.changeStage(moved.Id, 'Reprovado', null, null);
            Assert.areEqual('Reprovado', same.Stage__c, 'Mesma etapa e no-op');

            try {
                JobApplicationService.changeStage(app.Id, 'Triagem', null, 9);
                Assert.fail('Nota fora da faixa');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.areEqual('A nota deve estar entre 0 e 5.', e.getMessage());
            }
            for (JobApplicationService.StageChange bad : new List<JobApplicationService.StageChange>{
                new JobApplicationService.StageChange(null, 'Triagem', null, null),
                new JobApplicationService.StageChange(app.Id, '', null, null)
            }) {
                try {
                    JobApplicationService.changeStages(new List<JobApplicationService.StageChange>{ bad });
                    Assert.fail('Pedido incompleto');
                } catch (JobApplicationService.RecruitingException e) {
                    Assert.isNotNull(e.getMessage());
                }
            }
            try {
                JobApplicationService.changeStages(
                    new List<JobApplicationService.StageChange>{
                        new JobApplicationService.StageChange(app.Id, 'Triagem', null, null),
                        new JobApplicationService.StageChange(app.Id, 'Triagem', null, null)
                    }
                );
                Assert.fail('Repetida');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.isTrue(e.getMessage().contains('mais de uma vez'));
            }
            Assert.isTrue(JobApplicationService.changeStages(null).isEmpty());
            }
    }

    @IsTest
    static void rateStoresTheScoreAndValidatesRange() {
        // Org limpa: o administrador de teste nao tem permissao de campo sobre os campos do produto.
        User adminUser = HrTestDataFactory.user('zzadm', 'HR_Admin');
        System.runAs(adminUser) {
            Job_Application__c app = newApplication('rate');
            JobApplicationService.rate(app.Id, 4);
            Assert.areEqual(4, RecruitingTestData.reloadApplication(app.Id).Score__c);
            try {
                JobApplicationService.rate(app.Id, 6);
                Assert.fail('Nota fora da faixa');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.areEqual('A nota deve estar entre 0 e 5.', e.getMessage());
            }
            try {
                JobApplicationService.rate(null, 3);
                Assert.fail('Sem candidatura');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.isNotNull(e.getMessage());
            }
            }
    }

    @IsTest
    static void onHiredUsesTheHandlerAndSurvivesItsAbsence() {
        RecruitingTestData.HiredRecorder recorder = RecruitingTestData.useRecorder();
        JobApplicationService.onHired(new Set<Id>());
        JobApplicationService.onHired(null);
        Assert.areEqual(0, recorder.calls);
        Id fakeId = newApplication('hired').Id;
        JobApplicationService.onHired(new Set<Id>{ fakeId });
        Assert.areEqual(1, recorder.calls);

        // Sem substituto e sem a classe de admissao na org, so registra em debug.
        JobApplicationService.testHandler = null;
        if (Type.forName(JobApplicationService.HIRED_HANDLER_CLASS) == null) {
            JobApplicationService.onHired(new Set<Id>{ fakeId });
        }
        Assert.areEqual(1, recorder.calls);
    }
}
