@IsTest
private class RecruitingControllersTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static Job_Opening__c opening;
    private static Job_Application__c app;

    private static HrTestDataFactory.OrgTree given() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.hrUser) {
            opening = RecruitingTestData.opening('Kanban', t.mgr1.Id, 'Aberta');
            app = RecruitingTestData.applications(RecruitingTestData.candidates('kb', 1), opening.Id)[0];
        }
        return t;
    }

    @IsTest
    static void openingsListSkipsDraftsAndShowsCounts() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.hrUser) {
            RecruitingTestData.opening('Rascunho oculto', null, 'Rascunho');
            List<RecruitingKanbanController.OpeningOptionDto> options = RecruitingKanbanController.getOpenings();
            Boolean found = false;
            for (RecruitingKanbanController.OpeningOptionDto o : options) {
                Assert.areNotEqual('Rascunho', o.status);
                if (o.id == opening.Id) {
                    found = true;
                    Assert.areEqual(1, o.applicationsCount);
                }
            }
            Assert.isTrue(found);
        }
    }

    @IsTest
    static void boardHasStagesInOrderCardsAndReasons() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.hrUser) {
            RecruitingKanbanController.BoardDto board = RecruitingKanbanController.getBoard(opening.Id);
            Assert.areEqual(opening.Id, board.openingId);
            Assert.areEqual('Aberta', board.openingStatus);
            Assert.areEqual(8, board.stages.size());
            Assert.areEqual('Nova', board.stages[0].value);
            Assert.isNotNull(board.stages[0].color);
            Assert.isTrue(board.stages[0].allowedNext.contains('Triagem'));
            Assert.isTrue(board.stages[4].requiresScore, 'Proposta exige nota');
            Assert.areEqual(5, board.rejectionReasons.size());
            Assert.areEqual(1, board.cards.size());
            RecruitingKanbanController.CardDto card = board.cards[0];
            Assert.areEqual(app.Id, card.id);
            Assert.areEqual('Nova', card.stage);
            Assert.areEqual(0, card.daysInStage);
            Assert.isTrue(card.candidateName.startsWith('ZZTEST-'));
            Assert.isNotNull(card.applicationNumber);
        }
    }

    @IsTest
    static void moveCardAdvancesAndReturnsTheUpdatedCard() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.hrUser) {
            RecruitingKanbanController.CardDto moved = RecruitingKanbanController.moveCard(app.Id, 'Triagem', null, null);
            Assert.areEqual('Triagem', moved.stage);
            RecruitingKanbanController.CardDto rejected = RecruitingKanbanController.moveCard(app.Id, 'Reprovado', 'Perfil', null);
            Assert.areEqual('Reprovado', rejected.stage);
            Assert.areEqual('Perfil', rejected.rejectionReason);
        }
    }

    @IsTest
    static void moveCardReportsRuleViolationsAsFriendlyErrors() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.hrUser) {
            try {
                RecruitingKanbanController.moveCard(app.Id, 'Proposta', null, null);
                Assert.fail('Transicao invalida');
            } catch (AuraHandledException e) {
                Assert.areEqual('Mudança de etapa não permitida: de Nova para Proposta.', e.getMessage());
            }
            try {
                RecruitingKanbanController.moveCard(app.Id, 'Reprovado', null, null);
                Assert.fail('Sem motivo');
            } catch (AuraHandledException e) {
                Assert.areEqual('Informe o motivo da reprovação.', e.getMessage());
            }
            try {
                RecruitingKanbanController.moveCard(null, 'Triagem', null, null);
                Assert.fail('Sem candidatura');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
    }

    @IsTest
    static void rateCardStoresTheScore() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.mgr1User) {
            RecruitingKanbanController.CardDto rated = RecruitingKanbanController.rateCard(app.Id, 3);
            Assert.areEqual(3, rated.score);
            try {
                RecruitingKanbanController.rateCard(app.Id, 10);
                Assert.fail('Fora da faixa');
            } catch (AuraHandledException e) {
                Assert.areEqual('A nota deve estar entre 0 e 5.', e.getMessage());
            }
        }
    }

    @IsTest
    static void boardOfAMissingOpeningFails() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.hrUser) {
            Id missing = opening.Id;
            delete [SELECT Id FROM Job_Application__c WHERE Job_Opening__c = :missing];
            delete [SELECT Id FROM Job_Opening__c WHERE Id = :missing];
            try {
                RecruitingKanbanController.getBoard(missing);
                Assert.fail('Vaga inexistente');
            } catch (AuraHandledException e) {
                Assert.areEqual('Vaga não encontrada ou sem acesso.', e.getMessage());
            }
            try {
                RecruitingInsightsController.getOpeningSummary(missing);
                Assert.fail('Vaga inexistente');
            } catch (AuraHandledException e) {
                Assert.areEqual('Vaga não encontrada ou sem acesso.', e.getMessage());
            }
        }
    }

    @IsTest
    static void historyListsEachMoveWithDaysAndNote() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.hrUser) {
            RecruitingTestData.ageStage(app.Id, 2);
            RecruitingKanbanController.moveCard(app.Id, 'Triagem', null, null);
            opening.Status__c = 'Fechada';
            update opening;

            List<RecruitingInsightsController.HistoryItemDto> items = RecruitingInsightsController.getHistory(app.Id);
            Assert.areEqual(3, items.size());
            Assert.isNull(items[0].fromStage);
            Assert.areEqual('Nova', items[0].toLabel);
            Assert.areEqual('Nova', items[1].fromLabel);
            Assert.areEqual('Triagem', items[1].toLabel);
            Assert.isTrue(items[1].daysInPreviousStage >= 2.0);
            Assert.isNotNull(items[1].changedBy);
            Assert.areEqual('Reprovado', items[2].toStage);
            Assert.areEqual('Vaga encerrada', items[2].note);
        }
    }

    @IsTest
    static void openingSummaryCountsByStageAndAveragesDays() {
        HrTestDataFactory.OrgTree t = given();
        System.runAs(t.hrUser) {
            List<Job_Application__c> apps = new List<Job_Application__c>{ app };
            apps.addAll(RecruitingTestData.applications(RecruitingTestData.candidates('sum', 3), opening.Id));
            for (Integer i = 1; i < 4; i++) {
                RecruitingTestData.ageStage(apps[i].Id, 4);
                RecruitingKanbanController.moveCard(apps[i].Id, 'Triagem', null, null);
            }
            RecruitingKanbanController.moveCard(apps[3].Id, 'Desistiu', null, null);

            RecruitingInsightsController.OpeningSummaryDto summary = RecruitingInsightsController.getOpeningSummary(opening.Id);
            Assert.areEqual(4, summary.total);
            Assert.areEqual(3, summary.inProgress, 'Desistiu e terminal');
            Map<String, RecruitingInsightsController.StageSummaryDto> byStage = new Map<String, RecruitingInsightsController.StageSummaryDto>();
            for (RecruitingInsightsController.StageSummaryDto s : summary.stages) {
                byStage.put(s.stage, s);
            }
            Assert.areEqual(1, byStage.get('Nova').count);
            Assert.areEqual(2, byStage.get('Triagem').count);
            Assert.areEqual(1, byStage.get('Desistiu').count);
            Assert.isTrue(byStage.get('Nova').averageDays >= 3.9, 'Media de dias na etapa Nova: ' + byStage.get('Nova').averageDays);
            Assert.isNull(byStage.get('Proposta').averageDays);
        }
    }
}
