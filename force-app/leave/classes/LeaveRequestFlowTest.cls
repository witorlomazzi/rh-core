/**
 * Fluxo completo de ferias (solicitar, gestor, RH) e seguranca da spec 02: colaborador nao ve colega, gestor ve a
 * equipe direta e indireta e nao ve outra equipe, colaborador nao altera o status por DML direto.
 * Arvore: gestor 1 (usuario) > colaboradores 1 e 2 (usuarios); colaborador 1 > colaborador 4; gestor 2 > colaborador 3.
 */
@IsTest
private class LeaveRequestFlowTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.orgTree();
        LeaveTestData.generatePeriods(new Set<Id>{ t.mgr1.Id, t.emp1.Id, t.emp2.Id, t.emp3.Id, t.emp4.Id });
    }

    private static Approval_Step__c pendingStep(Id requestId) {
        return [
            SELECT Id, Approver_Type__c, Approver__c, Step_Order__c
            FROM Approval_Step__c
            WHERE Leave_Request__c = :requestId AND Status__c = 'Pendente'
            LIMIT 1
        ];
    }

    private static Id submitAs(User u, Id periodId, Date start, Integer days, Integer sold) {
        Id requestId;
        System.runAs(u) {
            Leave_Request__c draft = LeaveRequestService.createDraft(periodId, start, days, sold, null);
            LeaveRequestService.SubmitResult result = LeaveRequestService.submit(draft.Id, false);
            Assert.isTrue(result.submitted, JSON.serialize(result.results));
            requestId = draft.Id;
        }
        return requestId;
    }

    // ------------------------------------------------------------------------------------------ fluxo

    @IsTest
    static void employeeManagerAndHrApproveRequest() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Date start = LeaveTestData.validMonday();

        Test.startTest();
        Id requestId = submitAs(t.emp1User, period.Id, start, 30, 0);

        Leave_Request__c pending = LeaveTestData.reloadRequest(requestId);
        Assert.areEqual('Pendente', pending.Status__c);
        Assert.areEqual(1, pending.Current_Step__c);
        Assert.areEqual(t.emp1.Id, pending.Employee__c);
        Assert.areEqual(t.emp1User.Id, pending.Requested_By__c);
        Assert.isTrue(pending.Rule_Check_Result__c.contains('"results"'), pending.Rule_Check_Result__c);
        Leave_Accrual_Period__c reserved = LeaveTestData.reloadPeriod(period.Id);
        Assert.areEqual(30, reserved.Days_Pending__c);
        Assert.areEqual(0, reserved.Balance_Days__c);

        Approval_Step__c managerStep = pendingStep(requestId);
        Assert.areEqual(t.mgr1User.Id, managerStep.Approver__c);
        System.runAs(t.mgr1User) {
            ApprovalService.decide(managerStep.Id, true, 'Combinado com a equipe');
        }
        Assert.areEqual('Pendente', LeaveTestData.reloadRequest(requestId).Status__c);
        Approval_Step__c hrStep = pendingStep(requestId);
        Assert.areEqual('HR_Team', hrStep.Approver_Type__c);
        System.runAs(t.hrUser) {
            ApprovalService.decide(hrStep.Id, true, null);
        }
        Test.stopTest();

        Assert.areEqual('Aprovado', LeaveTestData.reloadRequest(requestId).Status__c);
        Leave_Accrual_Period__c after = LeaveTestData.reloadPeriod(period.Id);
        Assert.areEqual(30, after.Days_Taken__c);
        Assert.areEqual(0, after.Days_Pending__c);
        Assert.areEqual(0, after.Balance_Days__c);
    }

    @IsTest
    static void managerRejectionEndsTheRequestAndReleasesTheBalance() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Id requestId = submitAs(t.emp1User, period.Id, LeaveTestData.validMonday(), 20, 10);
        // O abono pendente so entra no saldo depois da aprovacao (o roll-up Days_Sold__c filtra por status aprovado)
        Assert.areEqual(10, LeaveTestData.reloadPeriod(period.Id).Balance_Days__c);

        Test.startTest();
        Approval_Step__c step = pendingStep(requestId);
        System.runAs(t.mgr1User) {
            ApprovalService.decide(step.Id, false, 'Periodo de fechamento');
        }
        Test.stopTest();

        Assert.areEqual('Rejeitado', LeaveTestData.reloadRequest(requestId).Status__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Approval_Step__c WHERE Leave_Request__c = :requestId AND Status__c = 'Pendente']);
        Leave_Accrual_Period__c after = LeaveTestData.reloadPeriod(period.Id);
        Assert.areEqual(30, after.Balance_Days__c);
        Assert.areEqual(0, after.Days_Pending__c);
    }

    @IsTest
    static void approvalHandlerIsIdempotentAndNotifies() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, LeaveTestData.validMonday(), 10, 0, 'Pendente');
        LeaveApprovalHandler handler = new LeaveApprovalHandler();
        Integer before = HrNotificationService.sentCount;

        handler.onApproved(r.Id);
        Assert.areEqual('Aprovado', LeaveTestData.reloadRequest(r.Id).Status__c);
        handler.onApproved(r.Id);
        Assert.areEqual('Aprovado', LeaveTestData.reloadRequest(r.Id).Status__c);
        Assert.isTrue(HrNotificationService.sentCount > before, 'Colaborador notificado');

        Leave_Request__c other = LeaveTestData.insertRequest(period.Id, LeaveTestData.validMonday().addDays(60), 5, 0, 'Pendente');
        insert new Approval_Step__c(
            Request_Type__c = 'Leave',
            Leave_Request__c = other.Id,
            Step_Order__c = 1,
            Approver_Type__c = 'Direct_Manager',
            Status__c = 'Rejeitado',
            Comments__c = 'Sem cobertura',
            Decision_Date__c = System.now()
        );
        handler.onRejected(other.Id);
        Assert.areEqual('Rejeitado', LeaveTestData.reloadRequest(other.Id).Status__c);
        handler.onStepAdvanced(other.Id, 2);
        // Pedido inexistente nao quebra
        delete other;
        handler.onApproved(other.Id);
        handler.onRejected(other.Id);
    }

    // ------------------------------------------------------------------------------------------ motor no fluxo

    @IsTest
    static void blockedSubmitSavesTheCheckAndKeepsTheDraft() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Date tooSoon = LeaveTestData.nextWeekday(Date.today().addDays(10), 1);
        LeaveRequestService.SubmitResult result;
        Id draftId;
        System.runAs(t.emp1User) {
            Leave_Request__c draft = LeaveRequestService.createDraft(period.Id, tooSoon, 30, 0, null);
            draftId = draft.Id;
            // A excecao de antecedencia nao vale para colaborador
            result = LeaveRequestService.submit(draftId, true);
        }
        Assert.isFalse(result.submitted);
        Leave_Request__c saved = LeaveTestData.reloadRequest(draftId);
        Assert.areEqual('Rascunho', saved.Status__c);
        Assert.isTrue(saved.Rule_Check_Result__c.contains('ANTECEDENCIA'), saved.Rule_Check_Result__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Approval_Step__c WHERE Leave_Request__c = :draftId]);
    }

    @IsTest
    static void hrCanSubmitWithNoticeException() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Date tooSoon = LeaveTestData.nextWeekday(Date.today().addDays(10), 1);
        System.runAs(t.hrUser) {
            Leave_Request__c draft = LeaveRequestService.createDraft(period.Id, tooSoon, 30, 0, null);
            LeaveRequestService.SubmitResult result = LeaveRequestService.submit(draft.Id, true);
            Assert.isTrue(result.submitted, JSON.serialize(result.results));
            Assert.areEqual('Pendente', LeaveTestData.reloadRequest(draft.Id).Status__c);
            Assert.isTrue(LeaveRequestService.isHrAdmin());
        }
    }

    @IsTest
    static void teamConflictIsSavedAsAWarning() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Date start = LeaveTestData.validMonday();
        Leave_Accrual_Period__c colleague = LeaveTestData.firstPeriod(t.emp2.Id);
        LeaveTestData.insertRequest(colleague.Id, start.addDays(3), 10, 0, 'Aprovado');
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);

        Id requestId = submitAs(t.emp1User, period.Id, start, 14, 0);
        Leave_Request__c saved = LeaveTestData.reloadRequest(requestId);
        Assert.areEqual('Pendente', saved.Status__c, 'Conflito de equipe nao bloqueia');
        Assert.isNotNull(saved.Team_Conflict_Warning__c);
        Assert.isTrue(saved.Team_Conflict_Warning__c.contains('1 colega'), saved.Team_Conflict_Warning__c);
        Assert.isFalse(saved.Team_Conflict_Warning__c.contains('ZZTEST'), 'O aviso nao expoe nomes');
    }

    @IsTest
    static void checkReturnsResultsWithoutWriting() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp1User) {
            List<LeaveRuleResult> ok = LeaveRequestService.check(period.Id, LeaveTestData.validMonday(), 30, 0, null, false);
            Assert.isTrue(ok.isEmpty(), JSON.serialize(ok));
            Date friday = LeaveTestData.nextWeekday(Date.today().addDays(45), 5);
            List<LeaveRuleResult> blocked = LeaveRequestService.check(period.Id, friday, 14, 0, null, false);
            Assert.isTrue(LeaveRuleEngine.hasBlocking(blocked));
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Leave_Request__c WHERE Accrual_Period__c = :period.Id]);
    }

    @IsTest
    static void holidayBeforeStartBlocksTheRequest() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Date start = LeaveTestData.validMonday();
        HrTestDataFactory.holiday(start.addDays(2), null);
        System.runAs(t.emp1User) {
            List<LeaveRuleResult> results = LeaveRequestService.check(period.Id, start, 14, 0, null, false);
            Assert.areEqual(1, results.size(), JSON.serialize(results));
            Assert.areEqual(LeaveRuleEngine.R_V4, results[0].code);
        }
    }

    @IsTest
    static void secondRequestRespectsFractionRules() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Date start = LeaveTestData.validMonday();
        submitAs(t.emp1User, period.Id, start, 14, 0);
        System.runAs(t.emp1User) {
            // sobreposicao com o primeiro pedido
            List<LeaveRuleResult> overlap = LeaveRequestService.check(period.Id, start.addDays(7), 10, 0, null, false);
            Boolean found = false;
            for (LeaveRuleResult r : overlap) {
                found = found || r.code == LeaveRuleEngine.R_V11;
            }
            Assert.isTrue(found, JSON.serialize(overlap));
            // 14 + 16 e valido
            Assert.isTrue(LeaveRequestService.check(period.Id, start.addDays(42), 16, 0, null, false).isEmpty());
        }
    }

    // ------------------------------------------------------------------------------------------ cancelamento

    @IsTest
    static void employeeCancelsDraftAndPendingRequests() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Id pendingId = submitAs(t.emp1User, period.Id, LeaveTestData.validMonday(), 14, 0);
        Id draftId;
        System.runAs(t.emp1User) {
            draftId = LeaveRequestService.createDraft(period.Id, LeaveTestData.validMonday().addDays(70), 10, 0, 'Nota').Id;
            LeaveRequestService.cancel(draftId);
            LeaveRequestService.cancel(pendingId);
        }
        Assert.areEqual('Cancelado', LeaveTestData.reloadRequest(draftId).Status__c);
        Assert.areEqual('Cancelado', LeaveTestData.reloadRequest(pendingId).Status__c);
        Assert.areEqual(30, LeaveTestData.reloadPeriod(period.Id).Balance_Days__c);
    }

    @IsTest
    static void approvedRequestCannotBeCancelledByTheService() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Leave_Request__c approved = LeaveTestData.insertRequest(period.Id, LeaveTestData.validMonday(), 10, 0, 'Aprovado');
        System.runAs(t.emp1User) {
            try {
                LeaveRequestService.cancel(approved.Id);
                Assert.fail('Pedido aprovado nao pode ser cancelado pelo servico');
            } catch (LeaveRequestService.LeaveException e) {
                Assert.isTrue(e.getMessage().contains('rascunhos'), e.getMessage());
            }
        }
    }

    @IsTest
    static void submittingTwiceIsRefused() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Id requestId = submitAs(t.emp1User, period.Id, LeaveTestData.validMonday(), 14, 0);
        System.runAs(t.emp1User) {
            try {
                LeaveRequestService.submit(requestId, false);
                Assert.fail('Reenvio nao permitido');
            } catch (LeaveRequestService.LeaveException e) {
                Assert.isTrue(e.getMessage().contains('rascunho'), e.getMessage());
            }
        }
    }

    @IsTest
    static void awaitingLabelFollowsTheApprovalConfiguration() {
        Assert.isNull(LeaveRequestService.awaitingLabel('Aprovado', 1));
        Assert.areEqual('Aguardando o gestor', LeaveRequestService.awaitingLabel('Pendente', 1));
        Assert.areEqual('Aguardando o RH', LeaveRequestService.awaitingLabel('Pendente', 2));
        Assert.areEqual('Aguardando aprovação', LeaveRequestService.awaitingLabel('Pendente', 9));
        Assert.areEqual('Aguardando aprovação', LeaveRequestService.awaitingLabel('Pendente', null));
    }

    // ------------------------------------------------------------------------------------------ seguranca

    @IsTest
    static void employeeDoesNotSeeColleagueRequests() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        LeaveTestData.insertRequest(period.Id, LeaveTestData.validMonday(), 10, 0, 'Pendente');
        System.runAs(t.emp2User) {
            Assert.isTrue(LeaveRequestSelector.byEmployee(t.emp1.Id).isEmpty(), 'Colega nao ve pedido de colega');
            Assert.isTrue(LeaveAccrualPeriodSelector.byEmployee(t.emp1.Id).isEmpty(), 'Nem o periodo');
            try {
                LeaveRequestService.check(period.Id, LeaveTestData.validMonday(), 10, 0, null, false);
                Assert.fail('Colega nao pode verificar regras no periodo de outro');
            } catch (LeaveRequestService.LeaveException e) {
                Assert.isTrue(e.getMessage().contains('não encontrado'), e.getMessage());
            }
        }
        System.runAs(t.emp1User) {
            Assert.areEqual(1, LeaveRequestSelector.byEmployee(t.emp1.Id).size(), 'O dono ve o proprio pedido');
        }
    }

    @IsTest
    static void managerSeesDirectAndIndirectReportsButNotOtherTeams() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        LeaveTestData.insertRequest(LeaveTestData.firstPeriod(t.emp1.Id).Id, LeaveTestData.validMonday(), 10, 0, 'Pendente');
        LeaveTestData.insertRequest(LeaveTestData.firstPeriod(t.emp4.Id).Id, LeaveTestData.validMonday(), 10, 0, 'Pendente');
        LeaveTestData.insertRequest(LeaveTestData.firstPeriod(t.emp3.Id).Id, LeaveTestData.validMonday(), 10, 0, 'Pendente');
        System.runAs(t.mgr1User) {
            Assert.areEqual(1, LeaveRequestSelector.byEmployee(t.emp1.Id).size(), 'Subordinado direto');
            Assert.areEqual(1, LeaveRequestSelector.byEmployee(t.emp4.Id).size(), 'Subordinado indireto');
            Assert.isTrue(LeaveRequestSelector.byEmployee(t.emp3.Id).isEmpty(), 'Outra equipe fica fora');
        }
    }

    @IsTest
    static void managerCannotRequestVacationForTheEmployee() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.mgr1User) {
            try {
                LeaveRequestService.createDraft(period.Id, LeaveTestData.validMonday(), 10, 0, null);
                Assert.fail('Gestor nao solicita pelo colaborador');
            } catch (LeaveRequestService.LeaveException e) {
                Assert.isTrue(e.getMessage().contains('colaborador ou o RH'), e.getMessage());
            }
        }
    }

    @IsTest
    static void employeeCannotChangeStatusByDirectDml() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Leave_Request__c pending = LeaveTestData.insertRequest(period.Id, LeaveTestData.validMonday(), 10, 0, 'Pendente');
        System.runAs(t.emp1User) {
            try {
                update as user new Leave_Request__c(Id = pending.Id, Status__c = 'Aprovado');
                Assert.fail('Status__c e somente leitura para o colaborador');
            } catch (Exception e) {
                Assert.isFalse(e instanceof AssertException);
            }
            try {
                insert as user new Leave_Request__c(
                    Accrual_Period__c = period.Id,
                    Start_Date__c = LeaveTestData.validMonday().addDays(90),
                    Days__c = 5,
                    Status__c = 'Aprovado'
                );
                Assert.fail('Colaborador nao cria pedido ja aprovado');
            } catch (Exception e) {
                Assert.isFalse(e instanceof AssertException);
            }
        }
        Assert.areEqual('Pendente', LeaveTestData.reloadRequest(pending.Id).Status__c);
    }

    @IsTest
    static void employeeCannotEditDatesOfSubmittedRequest() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        Id requestId = submitAs(t.emp1User, period.Id, LeaveTestData.validMonday(), 14, 0);
        System.runAs(t.emp1User) {
            try {
                update as user new Leave_Request__c(Id = requestId, Days__c = 30);
                Assert.fail('Datas travadas fora do rascunho');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains('rascunho'), e.getMessage());
            }
        }
    }

    @IsTest
    static void employeeCannotWriteRuleCheckResult() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp1User) {
            Leave_Request__c draft = LeaveRequestService.createDraft(period.Id, LeaveTestData.validMonday(), 10, 0, null);
            try {
                update as user new Leave_Request__c(Id = draft.Id, Rule_Check_Result__c = '{"results":[]}');
                Assert.fail('Resultado do motor e somente leitura');
            } catch (Exception e) {
                Assert.isFalse(e instanceof AssertException);
            }
        }
    }
}
