/**
 * Testes de seguranca da spec 02 para o recrutamento: o gestor contratante ve so as candidaturas das proprias
 * vagas, o colaborador comum nao ve candidato nenhum, o recrutador ve tudo. Usa os quatro usuarios da arvore
 * padrao: RH (recrutador), gestor 1 (gestor contratante), colaborador 1 (sem acesso a recrutamento).
 */
@IsTest
private class RecruitingSecurityTest {
    private static Job_Opening__c openingA;
    private static Job_Opening__c openingB;
    private static Candidate__c candidateA;
    private static Candidate__c candidateB;
    private static Job_Application__c appA;
    private static Job_Application__c appB;

    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    /** A vaga A tem o gestor 1 como contratante; a vaga B tem o gestor 2, que nao tem usuario. */
    private static HrTestDataFactory.OrgTree givenTwoOpenings() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.hrUser) {
            openingA = RecruitingTestData.opening('Vaga A', t.mgr1.Id, 'Aberta');
            openingB = RecruitingTestData.opening('Vaga B', t.mgr2.Id, 'Aberta');
            candidateA = RecruitingTestData.candidate('A');
            candidateB = RecruitingTestData.candidate('B');
            appA = RecruitingTestData.applications(new List<Candidate__c>{ candidateA }, openingA.Id)[0];
            appB = RecruitingTestData.applications(new List<Candidate__c>{ candidateB }, openingB.Id)[0];
        }
        return t;
    }

    @IsTest
    static void recruiterSeesEveryApplicationAndCandidate() {
        HrTestDataFactory.OrgTree t = givenTwoOpenings();
        System.runAs(t.hrUser) {
            Map<Id, Job_Application__c> visible = new Map<Id, Job_Application__c>(
                JobApplicationSelector.byIds(new Set<Id>{ appA.Id, appB.Id })
            );
            Assert.areEqual(2, visible.size());
            Assert.areEqual(2, CandidateSelector.byIds(new Set<Id>{ candidateA.Id, candidateB.Id }).size());
            Assert.isNotNull(CandidateSelector.byEmail(candidateA.Email__c));
        }
    }

    @IsTest
    static void hiringManagerSeesOnlyApplicationsOfTheirOpenings() {
        HrTestDataFactory.OrgTree t = givenTwoOpenings();
        System.runAs(t.mgr1User) {
            List<Job_Application__c> apps = JobApplicationSelector.byIds(new Set<Id>{ appA.Id, appB.Id });
            Assert.areEqual(1, apps.size());
            Assert.areEqual(appA.Id, apps[0].Id);
            List<Candidate__c> candidates = CandidateSelector.byIds(new Set<Id>{ candidateA.Id, candidateB.Id });
            Assert.areEqual(1, candidates.size());
            Assert.areEqual(candidateA.Id, candidates[0].Id);
            Assert.isNull(CandidateSelector.byEmail(candidateB.Email__c), 'Candidato de outra vaga e invisivel');
            Assert.areEqual(1, JobApplicationSelector.byOpening(openingA.Id, 100).size());
            Assert.areEqual(0, JobApplicationSelector.byOpening(openingB.Id, 100).size());
        }
    }

    @IsTest
    static void hiringManagerMovesAndRatesOnlyTheirOwnApplications() {
        HrTestDataFactory.OrgTree t = givenTwoOpenings();
        System.runAs(t.mgr1User) {
            Assert.isFalse(
                Schema.sObjectType.Job_Application__c.fields.Stage__c.isUpdateable(),
                'Etapa e somente leitura por FLS: so o servico grava'
            );
            JobApplicationService.rate(appA.Id, 4);
            Job_Application__c moved = JobApplicationService.changeStage(appA.Id, 'Triagem', null, null);
            Assert.areEqual('Triagem', moved.Stage__c);
            Assert.areEqual(4, moved.Score__c);

            try {
                JobApplicationService.changeStage(appB.Id, 'Triagem', null, null);
                Assert.fail('Candidatura de outra vaga');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.areEqual('Candidatura não encontrada ou sem acesso.', e.getMessage());
            }
            try {
                JobApplicationService.rate(appB.Id, 5);
                Assert.fail('Nota em candidatura de outra vaga');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.areEqual('Candidatura não encontrada ou sem acesso.', e.getMessage());
            }
        }
        Assert.areEqual('Nova', RecruitingTestData.reloadApplication(appB.Id).Stage__c);
        Assert.areEqual('Triagem', RecruitingTestData.reloadApplication(appA.Id).Stage__c);
    }

    @IsTest
    static void hiringManagerCannotWriteStageDirectlyOrCreateApplications() {
        HrTestDataFactory.OrgTree t = givenTwoOpenings();
        System.runAs(t.mgr1User) {
            Job_Application__c stagePatch = new Job_Application__c(Id = appA.Id, Stage__c = 'Triagem');
            Boolean stageDenied = false;
            try {
                update as user stagePatch;
            } catch (Exception e) {
                stageDenied = true;
            }
            Assert.isTrue(stageDenied, 'Gravacao direta da etapa deve ser negada');

            Job_Application__c created = new Job_Application__c(Candidate__c = candidateA.Id, Job_Opening__c = openingA.Id);
            Boolean createDenied = false;
            try {
                insert as user created;
            } catch (Exception e) {
                createDenied = true;
            }
            Assert.isTrue(createDenied, 'Gestor contratante nao cria candidatura');
        }
    }

    @IsTest
    static void ordinaryEmployeeSeesNoCandidateAndCannotMove() {
        HrTestDataFactory.OrgTree t = givenTwoOpenings();
        System.runAs(t.emp1User) {
            Assert.isFalse(Schema.sObjectType.Candidate__c.isAccessible());
            Assert.isFalse(Schema.sObjectType.Job_Application__c.isAccessible());
            try {
                JobApplicationSelector.byIds(new Set<Id>{ appA.Id });
                Assert.fail('Sem permissao de objeto a consulta falha');
            } catch (QueryException e) {
                Assert.isNotNull(e.getMessage());
            }
            try {
                CandidateSelector.byIds(new Set<Id>{ candidateA.Id });
                Assert.fail('Sem permissao de objeto a consulta falha');
            } catch (QueryException e) {
                Assert.isNotNull(e.getMessage());
            }
            try {
                JobApplicationService.changeStage(appA.Id, 'Triagem', null, null);
                Assert.fail('Colaborador comum nao move candidatura');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.areEqual('Você não tem permissão para mover candidaturas.', e.getMessage());
            }
        }
        Assert.areEqual('Nova', RecruitingTestData.reloadApplication(appA.Id).Stage__c);
    }

    @IsTest
    static void controllersTranslateAccessErrors() {
        HrTestDataFactory.OrgTree t = givenTwoOpenings();
        System.runAs(t.emp1User) {
            try {
                RecruitingKanbanController.getBoard(openingA.Id);
                Assert.fail('Sem acesso');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
            try {
                RecruitingKanbanController.moveCard(appA.Id, 'Triagem', null, null);
                Assert.fail('Sem acesso');
            } catch (AuraHandledException e) {
                Assert.areEqual('Você não tem permissão para mover candidaturas.', e.getMessage());
            }
            try {
                RecruitingInsightsController.getHistory(appA.Id);
                Assert.fail('Sem acesso ao historico');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
        System.runAs(t.mgr1User) {
            try {
                RecruitingKanbanController.getBoard(openingB.Id);
                // A vaga e publica, mas nenhuma candidatura dela e visivel ao gestor 1.
                Assert.areEqual(0, RecruitingKanbanController.getBoard(openingB.Id).cards.size());
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
            Assert.areEqual(1, RecruitingKanbanController.getBoard(openingA.Id).cards.size());
        }
    }
}
