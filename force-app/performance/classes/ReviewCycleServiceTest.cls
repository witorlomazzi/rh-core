/**
 * Lancamento (idempotente, em lote e com 200 colaboradores), fases e liberacao do ciclo, e as validacoes do
 * trigger de Review_Cycle__c.
 */
@IsTest
private class ReviewCycleServiceTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    @IsTest
    static void launchCreatesOneReviewAndOneSelfAssessmentPerEmployeeWithUser() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);

        List<Performance_Review__c> reviews = [
            SELECT Employee__r.Employee_Number__c, Reviewer__c, Status__c, OwnerId
            FROM Performance_Review__c
            WHERE Review_Cycle__c = :cycle.Id AND Employee__r.Employee_Number__c LIKE 'ZZTEST-%'
        ];
        Assert.areEqual(3, reviews.size(), 'Gestor 1 e colaboradores 1 e 2');
        for (Performance_Review__c r : reviews) {
            Assert.areEqual('Pendente', r.Status__c);
            Assert.areEqual(t.hrUser.Id, r.OwnerId);
            if (r.Employee__r.Employee_Number__c == 'ZZTEST-MGR1') {
                Assert.isNull(r.Reviewer__c, 'Gestor de topo sem gestor com usuario');
            } else {
                Assert.areEqual(t.mgr1User.Id, r.Reviewer__c);
            }
        }
        Assert.areEqual(
            3,
            [SELECT COUNT() FROM Self_Assessment__c WHERE Review_Cycle__c = :cycle.Id AND Employee__r.Employee_Number__c LIKE 'ZZTEST-%']
        );
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Performance_Review__c WHERE Review_Cycle__c = :cycle.Id AND Employee__c = :t.emp3.Id],
            'Colaborador sem usuario nao entra no lancamento'
        );
    }

    @IsTest
    static void createRecordsIsIdempotent() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        List<Employee__c> employees = new List<Employee__c>{ t.emp1, t.emp2 };
        System.runAs(t.hrUser) {
            ReviewCycleService.LaunchResult first = new ReviewCycleService.LaunchResult();
            ReviewCycleService.createRecords(cycle, employees, first);
            Assert.areEqual(2, first.reviewsCreated);
            Assert.areEqual(2, first.selfAssessmentsCreated);

            ReviewCycleService.LaunchResult second = new ReviewCycleService.LaunchResult();
            ReviewCycleService.createRecords(cycle, employees, second);
            Assert.areEqual(0, second.reviewsCreated);
            Assert.areEqual(0, second.selfAssessmentsCreated);
            Assert.areEqual(2, second.skipped);
            Assert.areEqual(0, second.errors);
        }
        Assert.areEqual(2, [SELECT COUNT() FROM Performance_Review__c WHERE Review_Cycle__c = :cycle.Id]);
        Assert.areEqual(2, [SELECT COUNT() FROM Self_Assessment__c WHERE Review_Cycle__c = :cycle.Id]);
    }

    @IsTest
    static void createRecordsCompletesWhatIsMissing() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        System.runAs(t.hrUser) {
            // Uma execucao anterior criou so a autoavaliacao: o reenvio cria apenas a avaliacao que falta.
            SelfAssessmentService.beginTrusted();
            insert new Self_Assessment__c(Employee__c = t.emp1.Id, Review_Cycle__c = cycle.Id);
            SelfAssessmentService.endTrusted();
            ReviewCycleService.LaunchResult result = new ReviewCycleService.LaunchResult();
            ReviewCycleService.createRecords(cycle, new List<Employee__c>{ t.emp1 }, result);
            Assert.areEqual(1, result.reviewsCreated);
            Assert.areEqual(0, result.selfAssessmentsCreated);
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Self_Assessment__c WHERE Review_Cycle__c = :cycle.Id]);
    }

    @IsTest
    static void createRecordsHandlesTwoHundredEmployees() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        List<Employee__c> employees = new List<Employee__c>();
        for (Integer i = 0; i < 200; i++) {
            employees.add(HrTestDataFactory.buildEmployee(t.mgr1.Id, null));
        }
        insert employees;
        Test.startTest();
        ReviewCycleService.LaunchResult result = new ReviewCycleService.LaunchResult();
        System.runAs(t.hrUser) {
            ReviewCycleService.createRecords(cycle, employees, result);
        }
        Test.stopTest();
        Assert.areEqual(200, result.reviewsCreated);
        Assert.areEqual(200, result.selfAssessmentsCreated);
        Assert.areEqual(0, result.errors);
        Assert.areEqual(200, [SELECT COUNT() FROM Performance_Review__c WHERE Review_Cycle__c = :cycle.Id]);
        Assert.areEqual(
            200,
            [
                SELECT COUNT()
                FROM Performance_Review__Share
                WHERE Parent.Review_Cycle__c = :cycle.Id AND UserOrGroupId = :t.mgr1User.Id AND RowCause = :PerformanceSharingService.CHAIN_REASON
            ],
            'Avaliador recebe um share por avaliacao'
        );
        System.runAs(t.hrUser) {
            ReviewCycleService.LaunchResult again = new ReviewCycleService.LaunchResult();
            ReviewCycleService.createRecords(cycle, employees, again);
            Assert.areEqual(200, again.skipped, 'Segundo lancamento nao duplica');
        }
        Assert.areEqual(200, [SELECT COUNT() FROM Performance_Review__c WHERE Review_Cycle__c = :cycle.Id]);
    }

    @IsTest
    static void launchAboveLimitRunsInBatchAndOpensTheCycleAtTheEnd() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        ReviewCycleService.syncLimit = 1;
        ReviewCycleService.LaunchResult result;
        Test.startTest();
        result = PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        Test.stopTest();
        Assert.isTrue(result.async);
        Assert.areEqual(ReviewCycleService.SELF_REVIEW, [SELECT Status__c FROM Review_Cycle__c WHERE Id = :cycle.Id].Status__c);
        Assert.areEqual(
            3,
            [SELECT COUNT() FROM Performance_Review__c WHERE Review_Cycle__c = :cycle.Id AND Employee__r.Employee_Number__c LIKE 'ZZTEST-%']
        );
    }

    @IsTest
    static void launchRequiresHr() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        System.runAs(t.mgr1User) {
            try {
                ReviewCycleService.launch(cycle.Id);
                Assert.fail('Gestor nao lanca ciclo');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('RH'));
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Performance_Review__c WHERE Review_Cycle__c = :cycle.Id]);
    }

    @IsTest
    static void launchOnlyFromPlannedAndOnlyForExistingCycle() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            try {
                ReviewCycleService.launch(cycle.Id);
                Assert.fail('Ciclo ja lancado');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('Planejado'));
            }
            try {
                ReviewCycleService.launch(Id.valueOf('a00000000000000AAA'));
                Assert.fail('Ciclo inexistente');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('não encontrado'));
            }
        }
    }

    @IsTest
    static void advanceFollowsTheOrderAndStopsAtCalibration() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        System.runAs(t.hrUser) {
            assertAdvanceFails(cycle.Id, 'Lance o ciclo');
        }
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        Assert.areEqual(ReviewCycleService.MANAGER_REVIEW, PerformanceTestSupport.advance(t.hrUser, cycle.Id));
        Assert.areEqual(ReviewCycleService.CALIBRATION, PerformanceTestSupport.advance(t.hrUser, cycle.Id));
        System.runAs(t.hrUser) {
            assertAdvanceFails(cycle.Id, 'liberação');
        }
        System.runAs(t.emp1User) {
            assertAdvanceFails(cycle.Id, 'RH');
        }
    }

    @IsTest
    static void advanceFailsForConcludedCycle() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            PerformanceReviewService.saveManagerReview(review.Id, 3, 'Ok', true);
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            ReviewCycleService.release(cycle.Id);
            assertAdvanceFails(cycle.Id, 'concluído');
        }
    }

    @IsTest
    static void releaseNeedsCalibrationPhaseAndSomethingToRelease() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            try {
                ReviewCycleService.release(cycle.Id);
                Assert.fail('Ciclo fora da calibracao');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('Calibração'));
            }
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            try {
                ReviewCycleService.release(cycle.Id);
                Assert.fail('Nada enviado para liberar');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('Nenhuma avaliação'));
            }
        }
        System.runAs(t.emp1User) {
            try {
                ReviewCycleService.release(cycle.Id);
                Assert.fail('Colaborador nao libera');
            } catch (ReviewErrors.ReviewException e) {
                Assert.isTrue(e.getMessage().contains('RH'));
            }
        }
        Assert.areEqual(ReviewCycleService.CALIBRATION, [SELECT Status__c FROM Review_Cycle__c WHERE Id = :cycle.Id].Status__c);
    }

    // ------------------------------------------------------------------------------------ trigger do ciclo

    @IsTest
    static void cycleStatusCannotBeEditedDirectly() {
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        cycle.Status__c = ReviewCycleService.SELF_REVIEW;
        try {
            update cycle;
            Assert.fail('Situacao so muda pelo painel');
        } catch (DmlException e) {
            PerformanceTestSupport.assertMessage(e, 'painel de ciclos');
        }
    }

    @IsTest
    static void newCycleMustStartPlannedWithValidScaleAndDates() {
        Review_Cycle__c notPlanned = validCycle();
        notPlanned.Status__c = ReviewCycleService.SELF_REVIEW;
        assertInsertFails(notPlanned, 'nasce em Planejado');

        Review_Cycle__c badScale = validCycle();
        badScale.Rating_Scale_Max__c = 1;
        assertInsertFails(badScale, 'entre 2 e 9');

        Review_Cycle__c badEnd = validCycle();
        badEnd.End_Date__c = badEnd.Start_Date__c.addDays(-1);
        assertInsertFails(badEnd, 'data final');

        Review_Cycle__c badDue = validCycle();
        badDue.Manager_Review_Due__c = badDue.Self_Review_Due__c.addDays(-1);
        assertInsertFails(badDue, 'prazo do gestor');
    }

    @IsTest
    static void scaleCannotChangeAfterLaunch() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        cycle.Rating_Scale_Max__c = 7;
        update cycle;
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        cycle.Rating_Scale_Max__c = 4;
        try {
            update cycle;
            Assert.fail('Escala travada depois do lancamento');
        } catch (DmlException e) {
            PerformanceTestSupport.assertMessage(e, 'escala');
        }
    }

    private static Review_Cycle__c validCycle() {
        return new Review_Cycle__c(
            Name = 'ZZTEST-Invalido',
            Rating_Scale_Max__c = 5,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Self_Review_Due__c = Date.today().addDays(10),
            Manager_Review_Due__c = Date.today().addDays(20)
        );
    }

    private static void assertInsertFails(Review_Cycle__c cycle, String expectedPart) {
        try {
            insert cycle;
            Assert.fail('Ciclo invalido deveria falhar: ' + expectedPart);
        } catch (DmlException e) {
            PerformanceTestSupport.assertMessage(e, expectedPart);
        }
    }

    private static void assertAdvanceFails(Id cycleId, String expectedPart) {
        try {
            ReviewCycleService.advance(cycleId);
            Assert.fail('Avanco deveria falhar: ' + expectedPart);
        } catch (ReviewErrors.ReviewException e) {
            Assert.isTrue(e.getMessage().contains(expectedPart), e.getMessage());
        }
    }
}
