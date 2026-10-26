/**
 * Ciclo completo da spec 16: lancar, metas com 100%, autoavaliacao, avaliacao do gestor, calibracao e liberacao.
 * Confere que o colaborador so le a avaliacao depois da liberacao e nunca le a nota calibrada (spec 02).
 * O fluxo inteiro roda entre startTest e stopTest para ter o proprio orcamento de limites.
 */
@IsTest
private class PerformanceCycleFlowTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    @IsTest
    static void fullCycleFromLaunchToRelease() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();

        Test.startTest();
        // 1. RH lanca o ciclo
        ReviewCycleService.LaunchResult launched = PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        Assert.isFalse(launched.async);
        Assert.isTrue(launched.reviewsCreated >= 3, 'Gestor 1 e colaboradores 1 e 2 tem usuario');
        Assert.areEqual(0, launched.errors);
        Performance_Review__c review1 = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        Assert.areEqual('Pendente', review1.Status__c);
        Assert.areEqual(t.mgr1User.Id, review1.Reviewer__c, 'Avaliador e o gestor direto');

        // 2. Colaborador registra metas (100%) e envia a autoavaliacao
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 60, 40 });
        PerformanceTestSupport.submitSelf(t.emp1User, t.emp1, cycle.Id, 4);
        Assert.isTrue(PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Submitted__c);

        // 3. RH avanca para a avaliacao do gestor; o gestor grava rascunho e envia
        Assert.areEqual(ReviewCycleService.MANAGER_REVIEW, PerformanceTestSupport.advance(t.hrUser, cycle.Id));
        System.runAs(t.mgr1User) {
            PerformanceReviewController.ReviewFormView saved = PerformanceReviewController.saveReview(review1.Id, 4, 'Bom desempenho', false);
            Assert.areEqual('Em_Andamento', saved.reviewStatus);
            saved = PerformanceReviewController.saveReview(review1.Id, 5, 'Excelente desempenho', true);
            Assert.areEqual('Enviada', saved.reviewStatus);
            Assert.isFalse(saved.canEdit);
            Assert.isNull(saved.calibratedRating, 'Gestor nao le a nota calibrada');
        }

        // 4. RH avanca para a calibracao e ajusta a nota
        Assert.areEqual(ReviewCycleService.CALIBRATION, PerformanceTestSupport.advance(t.hrUser, cycle.Id));
        System.runAs(t.hrUser) {
            ReviewCycleController.calibrate(review1.Id, 3);
        }

        // Antes da liberacao o colaborador nao ve a avaliacao do gestor
        System.runAs(t.emp1User) {
            Assert.isTrue(PerformanceReviewSelector.byCycle(cycle.Id).isEmpty(), 'Sem share antes da liberacao');
            Assert.isNull(PerformanceReviewController.getMyCycle(cycle.Id).released, 'Resultado so depois da liberacao');
        }

        // 5. RH libera
        ReviewCycleService.ReleaseResult released;
        System.runAs(t.hrUser) {
            released = ReviewCycleController.release(cycle.Id);
        }
        Assert.areEqual(1, released.released, 'So a avaliacao enviada e calibrada e liberada');
        Assert.areEqual(ReviewCycleService.DONE, [SELECT Status__c FROM Review_Cycle__c WHERE Id = :cycle.Id].Status__c);
        Performance_Review__c after = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        Assert.areEqual('Liberada', after.Status__c);
        Assert.areEqual(3, after.Final_Rating__c, 'Nota final e a calibrada');
        Assert.isNotNull(after.Released_Date__c);
        Assert.areEqual(1, PerformanceTestSupport.shareCount(after.Id, t.emp1User.Id, PerformanceSharingService.RELEASE_REASON));

        // Depois da liberacao o colaborador le a avaliacao e a nota final, mas nunca a calibrada
        System.runAs(t.emp1User) {
            PerformanceReviewController.MyCycleView view = PerformanceReviewController.getMyCycle(cycle.Id);
            Assert.isNotNull(view.released);
            Assert.areEqual(5, view.released.managerRating);
            Assert.areEqual(3, view.released.finalRating);
            Assert.areEqual('Excelente desempenho', view.released.managerComments);
            Assert.isFalse(view.canEditSelf);
            try {
                Database.query('SELECT Calibrated_Rating__c FROM Performance_Review__c WITH USER_MODE');
                Assert.fail('Colaborador nao le Calibrated_Rating__c');
            } catch (QueryException e) {
                Assert.isTrue(e.getMessage().length() > 0);
            }
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.READABLE,
                [SELECT Id, Calibrated_Rating__c, Manager_Rating__c FROM Performance_Review__c WHERE Id = :after.Id]
            );
            Assert.isFalse(decision.getRecords()[0].isSet('Calibrated_Rating__c'), 'Nota calibrada removida por FLS');
        }
        Test.stopTest();
        // Colaborador 2 nao enviou nada e a avaliacao dele nao foi liberada
        Assert.areEqual('Pendente', PerformanceTestSupport.reviewOf(t.emp2.Id, cycle.Id).Status__c);
        Assert.isTrue(HrNotificationService.sentCount >= 1, 'Notificacoes enviadas');
    }

    @IsTest
    static void releaseWithoutCalibrationUsesManagerRating() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        Test.startTest();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp2.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            PerformanceReviewController.saveReview(review.Id, 4, 'Entrega consistente', true);
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            ReviewCycleController.release(cycle.Id);
        }
        Performance_Review__c after = PerformanceTestSupport.reviewOf(t.emp2.Id, cycle.Id);
        Assert.areEqual('Liberada', after.Status__c);
        Assert.areEqual(4, after.Final_Rating__c, 'Sem calibracao, a nota final e a do gestor');
        System.runAs(t.emp2User) {
            Assert.areEqual(4, PerformanceReviewController.getMyCycle(null).released.finalRating);
        }
        Test.stopTest();
    }
}
