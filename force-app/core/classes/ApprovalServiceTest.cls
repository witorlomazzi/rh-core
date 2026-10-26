@IsTest
private class ApprovalServiceTest {
    @TestSetup
    static void setup() {
        bypassModules();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.orgTree();
        insert new List<Leave_Accrual_Period__c>{
            period(t.emp1.Id),
            period(t.mgr1.Id)
        };
    }

    private static Leave_Accrual_Period__c period(Id employeeId) {
        return new Leave_Accrual_Period__c(
            Employee__c = employeeId,
            Start_Date__c = Date.today().addYears(-2),
            End_Date__c = Date.today().addYears(-1).addDays(-1),
            Entitled_Days__c = 30
        );
    }

    /** Os testes do core nao dependem das regras dos modulos: desliga os handlers deles pelo nome. */
    private static void bypassModules() {
        TriggerHandler.bypass('LeaveRequestTriggerHandler');
        TriggerHandler.bypass('LeaveAccrualPeriodTriggerHandler');
        TriggerHandler.bypass('PromotionRequestTriggerHandler');
    }

    private static HR_Approval_Step__mdt step(String type, Integer order, String approverType, String handler) {
        return new HR_Approval_Step__mdt(
            Request_Type__c = type,
            Step_Order__c = order,
            Approver_Type__c = approverType,
            Outcome_Handler__c = handler,
            Active__c = true
        );
    }

    private static void useTwoSteps() {
        ApprovalService.testSteps = new List<HR_Approval_Step__mdt>{
            step('Leave', 2, 'HR_Team', 'NoopApprovalHandler'),
            step('Leave', 1, 'Direct_Manager', 'NoopApprovalHandler'),
            step('Leave', 3, 'HR_Team', 'NoopApprovalHandler'),
            step('Promotion', 1, 'Second_Level_Manager', 'NoopApprovalHandler'),
            step('Promotion', 2, 'HR_Team', 'NoopApprovalHandler')
        };
        ApprovalService.testSteps[2].Active__c = false;
    }

    private static Leave_Request__c newLeave(Employee__c employee, User asUser) {
        Leave_Accrual_Period__c p = [SELECT Id FROM Leave_Accrual_Period__c WHERE Employee__c = :employee.Id LIMIT 1];
        Leave_Request__c r = new Leave_Request__c(
            Accrual_Period__c = p.Id,
            Employee__c = employee.Id,
            Start_Date__c = Date.today().addDays(40),
            Days__c = 10
        );
        System.runAs(asUser) {
            insert r;
        }
        return r;
    }

    private static Leave_Request__c reload(Id requestId) {
        return [SELECT Status__c, Current_Step__c, Requested_By__c FROM Leave_Request__c WHERE Id = :requestId];
    }

    private static Approval_Step__c pendingStep(Id requestId) {
        return [
            SELECT Id, Step_Order__c, Approver__c, Approver_Type__c, Status__c
            FROM Approval_Step__c
            WHERE Leave_Request__c = :requestId AND Status__c = 'Pendente'
            LIMIT 1
        ];
    }

    @IsTest
    static void twoStepFlowApproves() {
        bypassModules();
        useTwoSteps();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Request__c r = newLeave(t.emp1, t.emp1User);

        Test.startTest();
        System.runAs(t.emp1User) {
            ApprovalService.submit(r.Id, 'Leave');
        }
        Leave_Request__c afterSubmit = reload(r.Id);
        Assert.areEqual('Pendente', afterSubmit.Status__c);
        Assert.areEqual(1, afterSubmit.Current_Step__c);
        Assert.areEqual(t.emp1User.Id, afterSubmit.Requested_By__c);
        Approval_Step__c first = pendingStep(r.Id);
        Assert.areEqual(t.mgr1User.Id, first.Approver__c);

        System.runAs(t.mgr1User) {
            List<ApprovalService.ApprovalItem> items = ApprovalService.pendingForCurrentUser();
            Assert.areEqual(1, items.size(), 'Gestor ve a etapa');
            Assert.areEqual('ZZTEST-EMP1', items[0].employeeName);
            Assert.isNotNull(items[0].requestName);
            ApprovalService.decide(first.Id, true, 'Ok');
        }
        Approval_Step__c second = pendingStep(r.Id);
        Assert.areEqual('HR_Team', second.Approver_Type__c);
        Assert.areEqual(2, reload(r.Id).Current_Step__c);

        System.runAs(t.hrUser) {
            Assert.areEqual(1, ApprovalService.pendingForCurrentUser().size(), 'RH ve a etapa do grupo');
            ApprovalService.decide(second.Id, true, null);
        }
        Test.stopTest();

        Assert.areEqual('Aprovado', reload(r.Id).Status__c);
        Assert.isTrue(NoopApprovalHandler.calls.contains('advanced:' + r.Id + ':2'));
        Assert.isTrue(NoopApprovalHandler.calls.contains('approved:' + r.Id));
        Assert.areEqual(2, ApprovalStepSelector.byRequest(r.Id).size());
    }

    @IsTest
    static void rejectionRequiresCommentAndCloses() {
        bypassModules();
        useTwoSteps();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Request__c r = newLeave(t.emp1, t.emp1User);
        System.runAs(t.emp1User) {
            ApprovalService.submit(r.Id, 'Leave');
        }
        Approval_Step__c first = pendingStep(r.Id);
        Test.startTest();
        System.runAs(t.mgr1User) {
            try {
                ApprovalService.decide(first.Id, false, ' ');
                Assert.fail('Rejeicao sem comentario');
            } catch (ApprovalService.ApprovalException e) {
                Assert.isTrue(e.getMessage().contains('comentário'));
            }
            ApprovalService.decide(first.Id, false, 'Periodo de fechamento');
        }
        Test.stopTest();
        Assert.areEqual('Rejeitado', reload(r.Id).Status__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Approval_Step__c WHERE Leave_Request__c = :r.Id AND Status__c = 'Pendente']);
        Assert.isTrue(NoopApprovalHandler.calls.contains('rejected:' + r.Id));
        System.runAs(t.mgr1User) {
            try {
                ApprovalService.decide(first.Id, true, null);
                Assert.fail('Etapa ja decidida');
            } catch (ApprovalService.ApprovalException e) {
                Assert.isTrue(e.getMessage().contains('já foi decidida'));
            }
        }
    }

    @IsTest
    static void wrongApproverIsRejected() {
        bypassModules();
        useTwoSteps();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Request__c r = newLeave(t.emp1, t.emp1User);
        System.runAs(t.emp1User) {
            ApprovalService.submit(r.Id, 'Leave');
        }
        Approval_Step__c first = pendingStep(r.Id);
        Test.startTest();
        System.runAs(t.emp2User) {
            try {
                ApprovalService.decide(first.Id, true, null);
                Assert.fail('Colega nao aprova');
            } catch (ApprovalService.ApprovalException e) {
                Assert.areEqual('Você não é o aprovador desta etapa.', e.getMessage());
            }
            Assert.isTrue(ApprovalService.pendingForCurrentUser().isEmpty());
        }
        System.runAs(t.mgr1User) {
            ApprovalService.decide(first.Id, true, null);
        }
        Approval_Step__c hrStep = pendingStep(r.Id);
        System.runAs(t.mgr1User) {
            try {
                ApprovalService.decide(hrStep.Id, true, null);
                Assert.fail('Gestor fora do RH nao decide etapa do RH');
            } catch (ApprovalService.ApprovalException e) {
                Assert.areEqual('Você não é o aprovador desta etapa.', e.getMessage());
            }
        }
        Test.stopTest();
        try {
            ApprovalService.decide(null, true, null);
            Assert.fail('Etapa inexistente');
        } catch (ApprovalService.ApprovalException e) {
            Assert.isTrue(e.getMessage().contains('não encontrada'));
        }
    }

    @IsTest
    static void cancelOnlyByRequesterWhilePending() {
        bypassModules();
        useTwoSteps();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Request__c r = newLeave(t.emp1, t.emp1User);
        Test.startTest();
        System.runAs(t.emp1User) {
            try {
                ApprovalService.cancel(r.Id, 'Leave');
                Assert.fail('Rascunho nao se cancela pelo motor');
            } catch (ApprovalService.ApprovalException e) {
                Assert.isTrue(e.getMessage().contains('pendentes'));
            }
            ApprovalService.submit(r.Id, 'Leave');
        }
        System.runAs(t.mgr1User) {
            try {
                ApprovalService.cancel(r.Id, 'Leave');
                Assert.fail('Gestor nao cancela pedido do colaborador');
            } catch (ApprovalService.ApprovalException e) {
                Assert.isTrue(e.getMessage().contains('Somente quem fez'));
            }
        }
        System.runAs(t.emp1User) {
            ApprovalService.cancel(r.Id, 'Leave');
        }
        Test.stopTest();
        Assert.areEqual('Cancelado', reload(r.Id).Status__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Approval_Step__c WHERE Leave_Request__c = :r.Id AND Status__c = 'Cancelado']);
    }

    @IsTest
    static void unavailableApproverIsSkipped() {
        bypassModules();
        useTwoSteps();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        // O gestor do mgr1 e o CEO, que nao tem usuario: a etapa 1 e pulada.
        Leave_Request__c r = newLeave(t.mgr1, t.mgr1User);
        Test.startTest();
        System.runAs(t.mgr1User) {
            ApprovalService.submit(r.Id, 'Leave');
        }
        Test.stopTest();
        Approval_Step__c skipped = [
            SELECT Status__c, Comments__c
            FROM Approval_Step__c
            WHERE Leave_Request__c = :r.Id AND Step_Order__c = 1
        ];
        Assert.areEqual('Aprovado', skipped.Status__c);
        Assert.areEqual(ApprovalService.SKIPPED_COMMENT, skipped.Comments__c);
        Assert.areEqual('HR_Team', pendingStep(r.Id).Approver_Type__c);
        Assert.areEqual(2, reload(r.Id).Current_Step__c);
    }

    @IsTest
    static void allStepsSkippedApprovesImmediately() {
        bypassModules();
        ApprovalService.testSteps = new List<HR_Approval_Step__mdt>{ step('Leave', 1, 'Direct_Manager', 'NoopApprovalHandler') };
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Request__c r = newLeave(t.mgr1, t.mgr1User);
        Test.startTest();
        System.runAs(t.mgr1User) {
            ApprovalService.submit(r.Id, 'Leave');
        }
        Test.stopTest();
        Assert.areEqual('Aprovado', reload(r.Id).Status__c);
        Assert.isTrue(NoopApprovalHandler.calls.contains('approved:' + r.Id));
    }

    @IsTest
    static void secondLevelFallsBackAndSkipsRequester() {
        bypassModules();
        useTwoSteps();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Position__c target = HrTestDataFactory.position();
        Promotion_Request__c p = new Promotion_Request__c(
            Employee__c = t.emp1.Id,
            Proposed_Position__c = target.Id,
            Justification__c = 'ZZTEST-Justificativa',
            Effective_Date__c = Date.today().addDays(30)
        );
        Test.startTest();
        System.runAs(t.mgr1User) {
            insert p;
            // Segundo nivel do emp1 e o CEO sem usuario: cai no gestor direto, que e o proprio solicitante.
            ApprovalService.submit(p.Id, 'Promotion');
        }
        Test.stopTest();
        Approval_Step__c pending = [
            SELECT Approver_Type__c
            FROM Approval_Step__c
            WHERE Promotion_Request__c = :p.Id AND Status__c = 'Pendente'
        ];
        Assert.areEqual('HR_Team', pending.Approver_Type__c);
        Assert.areEqual('Pendente', [SELECT Status__c FROM Promotion_Request__c WHERE Id = :p.Id].Status__c);
    }

    @IsTest
    static void invalidSubmissionsAreRejected() {
        bypassModules();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Request__c r = newLeave(t.emp1, t.emp1User);
        System.runAs(t.emp1User) {
            ApprovalService.testSteps = new List<HR_Approval_Step__mdt>();
            assertFails(r.Id, 'Leave', 'Nenhuma etapa');
            assertFails(r.Id, 'Ferias', 'desconhecido');
            ApprovalService.testSteps = new List<HR_Approval_Step__mdt>{ step('Leave', 1, 'Direct_Manager', 'ClasseQueNaoExiste') };
            assertFails(r.Id, 'Leave', 'não encontrada');
            ApprovalService.testSteps = new List<HR_Approval_Step__mdt>{ step('Leave', 1, 'Direct_Manager', 'HrSettings') };
            assertFails(r.Id, 'Leave', 'não implementa');
        }
        System.runAs(t.emp2User) {
            ApprovalService.testSteps = null;
            assertFails(r.Id, 'Leave', 'não encontrada ou sem acesso');
        }
        ApprovalService.testSteps = new List<HR_Approval_Step__mdt>{ step('Leave', 1, 'HR_Team', null) };
        System.runAs(t.emp1User) {
            ApprovalService.submit(r.Id, 'Leave');
            assertFails(r.Id, 'Leave', 'rascunho');
        }
    }

    @IsTest
    static void realMetadataStepsAreConfigured() {
        Assert.areEqual(2, ApprovalService.stepsFor('Leave').size());
        Assert.areEqual('Direct_Manager', ApprovalService.stepsFor('Leave')[0].Approver_Type__c);
        Assert.areEqual('Second_Level_Manager', ApprovalService.stepsFor('Promotion')[0].Approver_Type__c);
    }

    @IsTest
    static void controllerWrapsService() {
        bypassModules();
        useTwoSteps();
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Request__c r = newLeave(t.emp1, t.emp1User);
        System.runAs(t.emp1User) {
            ApprovalService.submit(r.Id, 'Leave');
            Assert.areEqual(1, ApprovalController.getSteps(r.Id).size(), 'Solicitante ve as etapas');
        }
        Approval_Step__c first = pendingStep(r.Id);
        Test.startTest();
        System.runAs(t.mgr1User) {
            Assert.areEqual(1, ApprovalController.getPending().size());
            try {
                ApprovalController.decide(first.Id, false, null);
                Assert.fail('Erro de negocio vira AuraHandledException');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('comentário'));
            }
            ApprovalController.decide(first.Id, true, 'Ok');
        }
        Test.stopTest();
        Assert.areEqual(2, reload(r.Id).Current_Step__c);
    }

    private static void assertFails(Id requestId, String type, String expected) {
        try {
            ApprovalService.submit(requestId, type);
            Assert.fail('Deveria falhar: ' + expected);
        } catch (ApprovalService.ApprovalException e) {
            Assert.isTrue(e.getMessage().contains(expected), e.getMessage());
        }
    }
}
