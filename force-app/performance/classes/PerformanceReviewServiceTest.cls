/**
 * Regra A5 (avaliacao do gestor so editavel pelo avaliador, na fase do gestor, Pendente para Em_Andamento para
 * Enviada) e A6 (calibracao so do RH), com testes negativos e as travas de Performance_Review__c.
 */
@IsTest
private class PerformanceReviewServiceTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    /** Ciclo lancado, emp1 e emp2 sem metas, e a avaliacao do emp4 (subordinado do emp1) criada pelo RH. */
    private static Review_Cycle__c cycleWithReviews(HrTestDataFactory.OrgTree t) {
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            ReviewCycleService.createRecords(cycle, new List<Employee__c>{ t.emp4 }, new ReviewCycleService.LaunchResult());
        }
        return cycle;
    }

    @IsTest
    static void reviewerMovesFromPendingToInProgressToSent() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        Assert.areEqual('Pendente', review.Status__c);
        System.runAs(t.mgr1User) {
            Performance_Review__c draft = PerformanceReviewService.saveManagerReview(review.Id, null, 'Anotacao inicial', false);
            Assert.areEqual('Em_Andamento', draft.Status__c);
            Performance_Review__c again = PerformanceReviewService.saveManagerReview(review.Id, 4, 'Anotacao revisada', false);
            Assert.areEqual('Em_Andamento', again.Status__c);
            Performance_Review__c sent = PerformanceReviewService.saveManagerReview(review.Id, 4, 'Avaliacao final', true);
            Assert.areEqual('Enviada', sent.Status__c);
            Assert.areEqual(4, sent.Manager_Rating__c);
            try {
                PerformanceReviewService.saveManagerReview(review.Id, 2, 'Tentativa tardia', false);
                Assert.fail('Enviada nao e editavel');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('já foi enviada'));
            }
        }
        Assert.areEqual(4, PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Manager_Rating__c);
    }

    @IsTest
    static void onlyTheDesignatedReviewerFillsTheReview() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp4.Id, cycle.Id);
        Assert.areEqual(t.emp1User.Id, review.Reviewer__c, 'Colaborador 1 e o gestor direto do 4');
        PerformanceTestSupport.grantManager(t.emp1User);
        // Gestor 1 e da cadeia (le), mas nao e o avaliador
        System.runAs(t.mgr1User) {
            Assert.isNotNull(PerformanceReviewSelector.byId(review.Id), 'Cadeia le a avaliacao');
            try {
                PerformanceReviewService.saveManagerReview(review.Id, 5, 'Nao sou o avaliador', true);
                Assert.fail('Somente o avaliador');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('avaliador designado'));
            }
            // Sem Edit no share, a gravacao direta tambem falha
            Performance_Review__c direct = new Performance_Review__c(Id = review.Id, Manager_Rating__c = 5);
            try {
                update as user direct;
                Assert.fail('Cadeia so le a avaliacao');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().length() > 0);
            }
        }
        // RH tem acesso total, mas o trigger recusa quem nao e o avaliador designado
        System.runAs(t.hrUser) {
            Performance_Review__c byHr = new Performance_Review__c(Id = review.Id, Manager_Rating__c = 5);
            try {
                update as user byHr;
                Assert.fail('Trigger deve recusar quem nao e avaliador');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'avaliador designado');
            }
            try {
                PerformanceReviewService.saveManagerReview(review.Id, 5, 'RH', true);
                Assert.fail('RH nao e o avaliador');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('avaliador designado'));
            }
        }
        // O avaliador de verdade consegue
        System.runAs(t.emp1User) {
            Assert.areEqual('Enviada', PerformanceReviewService.saveManagerReview(review.Id, 3, 'Boa entrega', true).Status__c);
        }
    }

    @IsTest
    static void reviewIsClosedOutsideTheManagerPhase() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            try {
                PerformanceReviewService.saveManagerReview(review.Id, 3, 'Cedo demais', false);
                Assert.fail('Ciclo ainda em Autoavaliacao');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('fase de avaliação do gestor'));
            }
            Performance_Review__c direct = new Performance_Review__c(Id = review.Id, Manager_Comments__c = 'Cedo demais');
            try {
                update as user direct;
                Assert.fail('Trigger deve recusar fora da fase');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'fase de avaliação do gestor');
            }
        }
    }

    @IsTest
    static void submitNeedsRatingAndCommentAndRatingInsideTheScale() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            try {
                PerformanceReviewService.saveManagerReview(review.Id, null, 'Sem nota', true);
                Assert.fail('Envio sem nota');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('nota e o comentário'));
            }
            try {
                PerformanceReviewService.saveManagerReview(review.Id, 4, ' ', true);
                Assert.fail('Envio sem comentario');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('nota e o comentário'));
            }
            try {
                PerformanceReviewService.saveManagerReview(review.Id, 6, 'Acima da escala', false);
                Assert.fail('Nota acima da escala');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'entre 1 e 5');
            }
            try {
                PerformanceReviewService.saveManagerReview(Id.valueOf('a00000000000000AAA'), 3, 'Inexistente', false);
                Assert.fail('Avaliacao inexistente');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('não encontrada'));
            }
        }
        Assert.areEqual('Pendente', PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Status__c, 'Falhas nao mudam a situacao');
    }

    @IsTest
    static void statusAndFinalFieldsCannotBeWrittenDirectly() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        // Gestor: Status__c e somente leitura por FLS
        System.runAs(t.mgr1User) {
            Performance_Review__c direct = new Performance_Review__c(Id = review.Id, Status__c = 'Enviada');
            try {
                update as user direct;
                Assert.fail('Status somente leitura para o gestor');
            } catch (Exception e) {
                Assert.isTrue(e.getMessage().length() > 0);
            }
            Performance_Review__c calibrated = new Performance_Review__c(Id = review.Id, Calibrated_Rating__c = 5);
            try {
                update as user calibrated;
                Assert.fail('Gestor nao grava nota calibrada');
            } catch (Exception e) {
                Assert.isTrue(e.getMessage().length() > 0);
            }
        }
        // RH: mesmo com FLS de edicao, o trigger exige o fluxo do ciclo
        System.runAs(t.hrUser) {
            Performance_Review__c direct = new Performance_Review__c(Id = review.Id, Status__c = 'Liberada');
            try {
                update as user direct;
                Assert.fail('Situacao so muda pelo fluxo');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'fluxo do ciclo');
            }
            Performance_Review__c manual = new Performance_Review__c(
                Review_Cycle__c = cycle.Id,
                Employee__c = t.emp3.Id,
                Status__c = 'Pendente'
            );
            try {
                insert as user manual;
                Assert.fail('Avaliacao so nasce no lancamento');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'lançamento do ciclo');
            }
        }
    }

    @IsTest
    static void onlyHrChangesTheReviewerAndOnlyBeforeSending() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        PerformanceTestSupport.grantManager(t.emp2User);
        System.runAs(t.mgr1User) {
            Performance_Review__c swap = new Performance_Review__c(Id = review.Id, Reviewer__c = t.emp2User.Id);
            try {
                update as user swap;
                Assert.fail('Gestor nao troca avaliador');
            } catch (Exception e) {
                Assert.isTrue(e.getMessage().length() > 0);
            }
        }
        System.runAs(t.hrUser) {
            Performance_Review__c swap = new Performance_Review__c(Id = review.Id, Reviewer__c = t.emp2User.Id);
            update as user swap;
        }
        Assert.areEqual(t.emp2User.Id, PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Reviewer__c);
        // O novo avaliador ganha acesso de edicao; o antigo continua na cadeia, so leitura
        Performance_Review__c after = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        Assert.areEqual(1, PerformanceTestSupport.shareCount(after.Id, t.emp2User.Id, PerformanceSharingService.CHAIN_REASON));
        Assert.areEqual(
            'Edit',
            [SELECT AccessLevel FROM Performance_Review__Share WHERE ParentId = :after.Id AND UserOrGroupId = :t.emp2User.Id AND RowCause = :PerformanceSharingService.CHAIN_REASON]
            .AccessLevel
        );
        Assert.areEqual(
            'Read',
            [SELECT AccessLevel FROM Performance_Review__Share WHERE ParentId = :after.Id AND UserOrGroupId = :t.mgr1User.Id AND RowCause = :PerformanceSharingService.CHAIN_REASON]
            .AccessLevel
        );
        System.runAs(t.emp2User) {
            Assert.areEqual('Enviada', PerformanceReviewService.saveManagerReview(after.Id, 4, 'Novo avaliador', true).Status__c);
        }
        System.runAs(t.hrUser) {
            Performance_Review__c late = new Performance_Review__c(Id = after.Id, Reviewer__c = t.mgr1User.Id);
            try {
                update as user late;
                Assert.fail('Depois do envio o avaliador nao muda');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'antes do envio');
            }
        }
    }

    // ------------------------------------------------------------------------------------- calibracao (A6)

    @IsTest
    static void hrCalibratesSentReviewsInTheCalibrationPhase() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            PerformanceReviewService.saveManagerReview(review.Id, 5, 'Excelente', true);
        }
        // Antes da fase de calibracao
        System.runAs(t.hrUser) {
            try {
                PerformanceReviewService.calibrate(review.Id, 4);
                Assert.fail('Ciclo ainda na fase do gestor');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('Calibração'));
            }
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            PerformanceReviewService.calibrate(review.Id, 4);
            Assert.areEqual('Calibrada', PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Status__c);
            Assert.areEqual(4, PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Calibrated_Rating__c);
            PerformanceReviewService.calibrate(review.Id, 3);
            Assert.areEqual(3, PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Calibrated_Rating__c, 'Pode recalibrar');
            Assert.areEqual(3, PerformanceReviewSelector.calibratedByIds(new Set<Id>{ review.Id }).get(review.Id));
        }
    }

    @IsTest
    static void calibrationNegatives() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithReviews(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c sent = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        Performance_Review__c pending = PerformanceTestSupport.reviewOf(t.emp2.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            PerformanceReviewService.saveManagerReview(sent.Id, 5, 'Excelente', true);
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.mgr1User) {
            try {
                PerformanceReviewService.calibrate(sent.Id, 3);
                Assert.fail('Gestor nao calibra');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('RH'));
            }
        }
        System.runAs(t.hrUser) {
            try {
                PerformanceReviewService.calibrate(pending.Id, 3);
                Assert.fail('Avaliacao pendente nao calibra');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('já enviada'));
            }
            for (Decimal bad : new List<Decimal>{ 0, 6 }) {
                try {
                    PerformanceReviewService.calibrate(sent.Id, bad);
                    Assert.fail('Nota calibrada fora da escala');
                } catch (ReviewErrors.ReviewException e) {
                    Assert.isTrue(e.getMessage().contains('entre 1 e 5'));
                }
            }
            try {
                PerformanceReviewService.calibrate(sent.Id, null);
                Assert.fail('Nota calibrada obrigatoria');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('entre 1 e 5'));
            }
            try {
                PerformanceReviewService.calibrate(Id.valueOf('a00000000000000AAA'), 3);
                Assert.fail('Avaliacao inexistente');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('não encontrada'));
            }
        }
        Assert.isNull(PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Calibrated_Rating__c);
    }
}
