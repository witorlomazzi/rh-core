/**
 * Regras A3 (autoavaliacao so do proprio colaborador, ate o envio, nota dentro da escala) e A4 (metas somando
 * 100% para enviar), mais as travas de edicao das metas. Todos com testes negativos.
 */
@IsTest
private class SelfAssessmentGoalRulesTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static Review_Cycle__c launchedCycle(HrTestDataFactory.OrgTree t) {
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        return cycle;
    }

    // ------------------------------------------------------------------------------------------- A4: metas

    @IsTest
    static void submitFailsWhenWeightsDoNotAddTo100() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 50, 30 });
        Id saId = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Id;
        System.runAs(t.emp1User) {
            PerformanceReviewController.MyCycleView view = PerformanceReviewController.getMyCycle(cycle.Id);
            Assert.areEqual(80, view.weightSum, 'Aviso no componente enquanto nao fechar 100%');
            try {
                SelfAssessmentService.submitAssessment(saId, 4, 'Forcas', 'Melhorias');
                Assert.fail('Pesos somam 80');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, '80');
                PerformanceTestSupport.assertMessage(e, '100%');
            }
        }
        Assert.isFalse(PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Submitted__c);
    }

    @IsTest
    static void submitFailsWithoutGoals() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        Id saId = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Id;
        System.runAs(t.emp1User) {
            try {
                SelfAssessmentService.submitAssessment(saId, 4, 'Forcas', 'Melhorias');
                Assert.fail('Sem metas');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, '0%');
            }
        }
    }

    @IsTest
    static void cancelledGoalsDoNotCountTowardsWeights() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 60, 40, 30 });
        Id saId = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Id;
        System.runAs(t.emp1User) {
            PerformanceReviewController.MyCycleView view = PerformanceReviewController.getMyCycle(cycle.Id);
            Assert.areEqual(130, view.weightSum);
            Id extra = view.goals[2].id;
            GoalController.cancelGoal(extra);
            Assert.areEqual(100, PerformanceReviewController.getMyCycle(cycle.Id).weightSum);
            SelfAssessmentController.submitAssessment(saId, 5, 'Forcas', 'Melhorias');
        }
        Self_Assessment__c sa = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id);
        Assert.isTrue(sa.Submitted__c);
        Assert.isNotNull(sa.Submitted_Date__c);
    }

    @IsTest
    static void goalWeightMustBeBetween1And100AndScoreInsideScale() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        System.runAs(t.emp1User) {
            for (Decimal badWeight : new List<Decimal>{ 0, 101, -5 }) {
                try {
                    GoalController.saveGoal(null, cycle.Id, 'ZZTEST-Meta ruim', 'Alvo', null, badWeight, null);
                    Assert.fail('Peso invalido: ' + badWeight);
                } catch (AuraHandledException e) {
                    Assert.isTrue(e.getMessage().contains('entre 1% e 100%'), e.getMessage());
                }
            }
            Id goalId = GoalController.saveGoal(null, cycle.Id, 'ZZTEST-Meta boa', 'Alvo', null, 100, null);
            try {
                GoalController.setScore(goalId, 6);
                Assert.fail('Nota acima da escala');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('entre 1 e 5'), e.getMessage());
            }
            GoalController.setScore(goalId, 5);
            Assert.areEqual(5, GoalSelector.byId(goalId).Self_Score__c);
            GoalController.saveGoal(goalId, cycle.Id, 'ZZTEST-Meta editada', 'Novo alvo', 'Nova descricao', 100, 4);
            Goal__c edited = GoalSelector.byId(goalId);
            Assert.areEqual('ZZTEST-Meta editada', edited.Name);
            Assert.areEqual(4, edited.Self_Score__c);
        }
    }

    @IsTest
    static void onlyTheOwnerRegistersGoals() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        System.runAs(t.mgr1User) {
            try {
                GoalService.create(t.emp1.Id, cycle.Id, 'ZZTEST-Meta alheia', 'Alvo', null, 100);
                Assert.fail('Gestor nao registra meta do subordinado');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'próprio colaborador');
            }
        }
        // RH corrige metas de qualquer colaborador
        System.runAs(t.hrUser) {
            Goal__c g = GoalService.create(t.emp1.Id, cycle.Id, 'ZZTEST-Meta do RH', 'Alvo', null, 100);
            Assert.isNotNull(g.Id);
        }
    }

    @IsTest
    static void goalsAreLockedAfterSubmitAndOutsideTheEditablePhases() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 100 });
        PerformanceTestSupport.goals(t.emp2User, cycle.Id, new List<Decimal>{ 100 });
        PerformanceTestSupport.submitSelf(t.emp1User, t.emp1, cycle.Id, 3);
        Goal__c g1 = [SELECT Id FROM Goal__c WHERE Employee__c = :t.emp1.Id AND Review_Cycle__c = :cycle.Id];
        Goal__c g2 = [SELECT Id FROM Goal__c WHERE Employee__c = :t.emp2.Id AND Review_Cycle__c = :cycle.Id];
        System.runAs(t.emp1User) {
            try {
                GoalService.score(g1.Id, 3);
                Assert.fail('Autoavaliacao enviada trava as metas');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'bloqueadas');
            }
            PerformanceReviewController.MyCycleView view = PerformanceReviewController.getMyCycle(cycle.Id);
            Assert.isFalse(view.canEditGoals);
            Assert.isFalse(view.canEditSelf);
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.emp2User) {
            try {
                GoalService.cancel(g2.Id);
                Assert.fail('Meta fecha na fase do gestor');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'antes da avaliação do gestor');
            }
            try {
                GoalController.saveGoal(null, cycle.Id, 'ZZTEST-Tardia', 'Alvo', null, 10, null);
                Assert.fail('Nova meta fora da fase');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('antes da avaliação do gestor'));
            }
        }
    }

    @IsTest
    static void goalCycleIsRequiredAndImmutable() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        Review_Cycle__c other = PerformanceTestSupport.newCycle();
        System.runAs(t.emp1User) {
            try {
                GoalController.saveGoal(null, null, 'ZZTEST-Sem ciclo', 'Alvo', null, 10, null);
                Assert.fail('Meta sem ciclo');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('ciclo'));
            }
            Id goalId = GoalController.saveGoal(null, cycle.Id, 'ZZTEST-Meta', 'Alvo', null, 10, null);
            Goal__c g = new Goal__c(Id = goalId, Review_Cycle__c = other.Id);
            try {
                update as user g;
                Assert.fail('Ciclo imutavel');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'não pode ser alterado');
            }
        }
    }

    @IsTest
    static void userWithoutEmployeeRecordCannotSaveGoal() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        System.runAs(t.hrUser) {
            try {
                GoalController.saveGoal(null, cycle.Id, 'ZZTEST-Meta', 'Alvo', null, 10, null);
                Assert.fail('RH sem cadastro de colaborador');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('não está vinculado'));
            }
        }
    }

    // --------------------------------------------------------------------------------- A3: autoavaliacao

    @IsTest
    static void draftIsSavedAndSubmitLocksTheAssessment() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 100 });
        Id saId = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Id;
        System.runAs(t.emp1User) {
            SelfAssessmentController.saveDraft(saId, null, 'Rascunho', null);
            Self_Assessment__c draft = SelfAssessmentSelector.byId(saId);
            Assert.areEqual('Rascunho', draft.Strengths__c);
            Assert.isFalse(draft.Submitted__c);
            Assert.isNull(draft.Submitted_Date__c);

            SelfAssessmentController.submitAssessment(saId, 5, 'Forcas', 'Melhorias');
            try {
                SelfAssessmentController.saveDraft(saId, 2, 'Mudei de ideia', null);
                Assert.fail('Autoavaliacao enviada nao muda');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('já enviada'), e.getMessage());
            }
        }
        Assert.areEqual(5, PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Self_Rating__c);
    }

    @IsTest
    static void ratingMustBeInsideTheScaleAndRequiredToSubmit() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        PerformanceTestSupport.goals(t.emp1User, cycle.Id, new List<Decimal>{ 100 });
        Id saId = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Id;
        System.runAs(t.emp1User) {
            for (Decimal bad : new List<Decimal>{ 0, 6 }) {
                try {
                    SelfAssessmentController.saveDraft(saId, bad, 'Forcas', null);
                    Assert.fail('Nota fora da escala: ' + bad);
                } catch (AuraHandledException e) {
                    Assert.isTrue(e.getMessage().contains('entre 1 e 5'), e.getMessage());
                }
            }
            try {
                SelfAssessmentController.submitAssessment(saId, null, 'Forcas', null);
                Assert.fail('Envio sem nota');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Informe a nota'), e.getMessage());
            }
        }
    }

    @IsTest
    static void onlyTheEmployeeEditsTheOwnAssessment() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        Id saId = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Id;
        // O gestor enxerga a autoavaliacao da equipe (acesso pelo colaborador pai), mas nao edita
        System.runAs(t.mgr1User) {
            Assert.areEqual(saId, SelfAssessmentSelector.byId(saId).Id, 'Gestor le a autoavaliacao');
            try {
                SelfAssessmentService.save(saId, 5, 'Gestor escrevendo', null);
                Assert.fail('Gestor nao edita a autoavaliacao');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'próprio colaborador');
            }
        }
        // Colega de outra linha nem enxerga
        System.runAs(t.emp2User) {
            Assert.isNull(SelfAssessmentSelector.byId(saId), 'Colega nao le a autoavaliacao');
        }
        // RH tambem nao edita
        System.runAs(t.hrUser) {
            try {
                SelfAssessmentService.save(saId, 5, 'RH escrevendo', null);
                Assert.fail('RH nao edita a autoavaliacao');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'próprio colaborador');
            }
        }
    }

    @IsTest
    static void assessmentIsClosedOutsideTheSelfReviewPhase() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        Id saId = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id).Id;
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        System.runAs(t.emp1User) {
            try {
                SelfAssessmentController.saveDraft(saId, 3, 'Fora de hora', null);
                Assert.fail('Fase da autoavaliacao encerrada');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Autoavaliação'), e.getMessage());
            }
            Assert.isFalse(PerformanceReviewController.getMyCycle(cycle.Id).canEditSelf);
        }
    }

    @IsTest
    static void assessmentIdentityIsImmutableAndKeyIsGenerated() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = launchedCycle(t);
        Review_Cycle__c other = PerformanceTestSupport.newCycle();
        Self_Assessment__c sa = PerformanceTestSupport.selfOf(t.emp1.Id, cycle.Id);
        Assert.areEqual(String.valueOf(t.emp1.Id) + '|' + String.valueOf(cycle.Id), sa.Unique_Key__c);
        System.runAs(t.emp1User) {
            Self_Assessment__c moved = new Self_Assessment__c(Id = sa.Id, Review_Cycle__c = other.Id);
            try {
                update as user moved;
                Assert.fail('Ciclo da autoavaliacao e imutavel');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'não podem ser alterados');
            }
        }
    }

    @IsTest
    static void employeeCreatesOwnAssessmentOnlyInTheSelfReviewPhase() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        System.runAs(t.emp1User) {
            try {
                Self_Assessment__c manual = new Self_Assessment__c(Employee__c = t.emp1.Id, Review_Cycle__c = cycle.Id);
                insert as user manual;
                Assert.fail('Ciclo ainda Planejado');
            } catch (DmlException e) {
                PerformanceTestSupport.assertMessage(e, 'Autoavaliação');
            }
        }
    }
}
