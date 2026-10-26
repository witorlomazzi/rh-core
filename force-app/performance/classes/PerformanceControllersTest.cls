/**
 * Controllers do modulo de desempenho: caminho feliz do RH e do colaborador, conversao de erros em
 * AuraHandledException e bloqueio de quem nao e RH.
 */
@IsTest
private class PerformanceControllersTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    @IsTest
    static void hrRunsTheCycleThroughTheAdminController() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Id cycleId;
        System.runAs(t.hrUser) {
            cycleId = ReviewCycleController.createCycle(
                'ZZTEST-Ciclo via painel',
                Date.today().addDays(-10),
                Date.today().addDays(80),
                Date.today().addDays(10),
                Date.today().addDays(20),
                5
            );
            ReviewCycleController.Overview planned = ReviewCycleController.getOverview(cycleId);
            Assert.areEqual('Planejado', planned.cycle.status);
            Assert.areEqual(5, planned.cycle.scaleMax);
            Assert.areEqual(0, planned.reviewTotal);
            Assert.areEqual(5, planned.reviewsByStatus.size());
            Assert.isTrue(planned.eligibleEmployees >= 3);

            ReviewCycleService.LaunchResult launched = ReviewCycleController.launch(cycleId);
            Assert.isTrue(launched.reviewsCreated >= 3);
            ReviewCycleController.Overview open = ReviewCycleController.getOverview(cycleId);
            Assert.areEqual('Autoavaliacao', open.cycle.status);
            Assert.isTrue(open.reviewTotal >= 3);
            Assert.isTrue(open.selfTotal >= 3);
            Assert.areEqual(0, open.selfSubmitted);
            Assert.isTrue(open.withoutReviewer >= 1, 'Gestor de topo sem avaliador');
            Assert.isTrue(PerformanceReviewController.getCycles().size() >= 1);

            Assert.areEqual('Avaliacao_Gestor', ReviewCycleController.advance(cycleId));
            Assert.areEqual('Calibracao', ReviewCycleController.advance(cycleId));
            List<ReviewCycleController.CalibrationRow> rows = ReviewCycleController.getCalibration(cycleId);
            Assert.isTrue(rows.size() >= 3);
            for (ReviewCycleController.CalibrationRow row : rows) {
                Assert.isFalse(row.canCalibrate, 'Nenhuma avaliacao enviada ainda');
            }
        }
    }

    @IsTest
    static void adminControllerMethodsRefuseNonHr() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        System.runAs(t.emp1User) {
            Integer denied = 0;
            try {
                ReviewCycleController.getOverview(cycle.Id);
            } catch (AuraHandledException e) {
                denied++;
            }
            try {
                ReviewCycleController.createCycle('ZZTEST-Intruso', null, null, null, null, 5);
            } catch (AuraHandledException e) {
                denied++;
            }
            try {
                ReviewCycleController.launch(cycle.Id);
            } catch (AuraHandledException e) {
                denied++;
            }
            try {
                ReviewCycleController.advance(cycle.Id);
            } catch (AuraHandledException e) {
                denied++;
            }
            try {
                ReviewCycleController.release(cycle.Id);
            } catch (AuraHandledException e) {
                denied++;
            }
            try {
                ReviewCycleController.getCalibration(cycle.Id);
            } catch (AuraHandledException e) {
                denied++;
            }
            try {
                ReviewCycleController.calibrate(cycle.Id, 3);
            } catch (AuraHandledException e) {
                denied++;
            }
            Assert.areEqual(7, denied, 'Todo metodo do painel recusa quem nao e RH');
        }
    }

    @IsTest
    static void adminControllerReportsMissingCycleAndBadInput() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.hrUser) {
            Id missing = Id.valueOf('a00000000000000AAA');
            try {
                ReviewCycleController.getOverview(missing);
                Assert.fail('Ciclo inexistente');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('não encontrado'));
            }
            try {
                ReviewCycleController.getCalibration(missing);
                Assert.fail('Ciclo inexistente');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('não encontrado'));
            }
            try {
                ReviewCycleController.createCycle('ZZTEST-Escala ruim', null, null, null, null, 1);
                Assert.fail('Escala invalida');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('entre 2 e 9'), e.getMessage());
            }
            try {
                PerformanceReviewController.getTeam(missing);
                Assert.fail('Ciclo inexistente');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('não encontrado'));
            }
        }
    }

    @IsTest
    static void hrSeesCalibratedRatingInTheReviewForm() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            PerformanceReviewController.saveReview(review.Id, 5, 'Excelente', true);
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            ReviewCycleController.calibrate(review.Id, 4);
            ReviewCycleController.CalibrationRow row = ReviewCycleController.getCalibration(cycle.Id)[0];
            Assert.isNotNull(row.employeeName);
            PerformanceReviewController.ReviewFormView form = PerformanceReviewController.getReviewForm(review.Id);
            Assert.areEqual(4, form.calibratedRating);
            Assert.areEqual(5, form.managerRating);
            Assert.isFalse(form.canEdit, 'RH nao edita pelo gestor');
            Assert.isNotNull(form.cycle.managerDue);
        }
        System.runAs(t.mgr1User) {
            PerformanceReviewController.ReviewFormView form = PerformanceReviewController.getReviewForm(review.Id);
            Assert.isNull(form.calibratedRating, 'Gestor nao ve a calibrada');
            Assert.areEqual('Calibrada', form.reviewStatus);
        }
    }

    @IsTest
    static void reviewFormShowsEmployeeGoalsAndSelfAssessmentToTheManager() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 70, 30 });
        PerformanceTestSupport.submitSelf(t.emp1User, t.emp1, cycle.Id, 4);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            PerformanceReviewController.ReviewFormView form = PerformanceReviewController.getReviewForm(review.Id);
            Assert.areEqual(2, form.goals.size());
            Assert.areEqual(100, form.weightSum);
            Assert.isTrue(form.selfAssessment.submitted);
            Assert.areEqual(4, form.selfAssessment.rating);
            Assert.isTrue(form.canEdit);
            Assert.areEqual(t.emp1.Id, form.employeeId);
        }
    }

    @IsTest
    static void myCycleWithoutEmployeeOrWithoutCycleIsEmpty() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.hrUser) {
            PerformanceReviewController.MyCycleView hrView = PerformanceReviewController.getMyCycle(null);
            Assert.isFalse(hrView.hasEmployee, 'RH sem cadastro de colaborador');
        }
        System.runAs(t.emp1User) {
            PerformanceReviewController.MyCycleView view = PerformanceReviewController.getMyCycle(null);
            Assert.isTrue(view.hasEmployee);
            Assert.isNull(view.cycle, 'Nenhum ciclo lancado ainda');
            Assert.isTrue(view.cycles.isEmpty());
        }
    }

    @IsTest
    static void myCycleLetsTheEmployeePickAnotherCycle() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c older = PerformanceTestSupport.newCycle();
        older.Start_Date__c = Date.today().addDays(-400);
        update older;
        PerformanceTestSupport.launch(t.hrUser, older.Id);
        Review_Cycle__c newer = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, newer.Id);
        System.runAs(t.emp1User) {
            PerformanceReviewController.MyCycleView latest = PerformanceReviewController.getMyCycle(null);
            Assert.areEqual(newer.Id, latest.cycle.id, 'Sem escolha, o ciclo mais recente');
            Assert.areEqual(2, latest.cycles.size());
            PerformanceReviewController.MyCycleView picked = PerformanceReviewController.getMyCycle(older.Id);
            Assert.areEqual(older.Id, picked.cycle.id);
            Assert.isTrue(picked.canEditSelf);
        }
    }

    @IsTest
    static void teamViewReflectsSelfAssessmentAndReviewStatus() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 100 });
        PerformanceTestSupport.submitSelf(t.emp1User, t.emp1, cycle.Id, 5);
        System.runAs(t.mgr1User) {
            PerformanceReviewController.TeamView before = PerformanceReviewController.getTeam(cycle.Id);
            for (PerformanceReviewController.TeamRow row : before.rows) {
                Assert.isFalse(row.canEdit, 'Ciclo ainda em Autoavaliacao');
                Assert.isTrue(row.isReviewer);
                if (row.employeeId == t.emp1.Id) {
                    Assert.isTrue(row.selfSubmitted);
                    Assert.areEqual(5, row.selfRating);
                } else {
                    Assert.isFalse(row.selfSubmitted);
                }
            }
            Assert.areEqual(2, before.rows.size() - (containsEmployee(before, t.emp4.Id) ? 1 : 0), 'Colaboradores 1 e 2');
        }
    }

    private static Boolean containsEmployee(PerformanceReviewController.TeamView view, Id employeeId) {
        for (PerformanceReviewController.TeamRow row : view.rows) {
            if (row.employeeId == employeeId) {
                return true;
            }
        }
        return false;
    }
}
