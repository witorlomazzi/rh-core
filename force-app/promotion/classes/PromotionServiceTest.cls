@IsTest
private class PromotionServiceTest {
    @TestSetup
    static void setup() {
        PromotionTestSupport.createAll();
    }

    // ------------------------------------------------------------------------------------------ utilidades

    private static PromotionService.SubmitResult submit(User u, Id employeeId, Id positionId, Date effectiveDate) {
        PromotionService.SubmitResult r;
        System.runAs(u) {
            r = PromotionService.createAndSubmit(employeeId, positionId, effectiveDate, 'ZZTEST-Entrega acima do esperado');
        }
        return r;
    }

    private static String submitError(User u, Id employeeId, Id positionId, Date effectiveDate) {
        try {
            submit(u, employeeId, positionId, effectiveDate);
            return null;
        } catch (PromotionService.PromotionException e) {
            return e.getMessage();
        }
    }

    private static Promotion_Request__c reload(Id requestId) {
        return [
            SELECT Id, Status__c, Current_Step__c, Current_Position__c, Current_Salary__c, Proposed_Salary__c, Requested_By__c, Effective_Date__c
            FROM Promotion_Request__c
            WHERE Id = :requestId
        ];
    }

    private static Approval_Step__c pendingStep(Id requestId) {
        return [
            SELECT Id, Step_Order__c, Approver__c, Approver_Type__c, Status__c
            FROM Approval_Step__c
            WHERE Promotion_Request__c = :requestId AND Status__c = 'Pendente'
            LIMIT 1
        ];
    }

    private static Employee__c reloadEmployee(Id employeeId) {
        return [SELECT Id, Position__c, Salary__c FROM Employee__c WHERE Id = :employeeId];
    }

    private static List<Position_History__c> historyOf(Id employeeId) {
        return [
            SELECT Id, Position__c, Salary__c, Start_Date__c, End_Date__c, Change_Reason__c, Promotion_Request__c
            FROM Position_History__c
            WHERE Employee__c = :employeeId
            ORDER BY Start_Date__c, CreatedDate
        ];
    }

    // ------------------------------------------------------------------------------------------ fluxo

    @IsTest
    static void fullFlowWithScheduledEffectivation() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Date effective = Date.today().addDays(10);

        PromotionService.SubmitResult result = submit(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id, effective);
        System.assertEquals(null, result.warning, 'Cargo B e o proximo da trilha de A');
        System.assertNotEquals(null, result.requestName);

        Promotion_Request__c req = reload(result.requestId);
        System.assertEquals('Pendente', req.Status__c);
        System.assertEquals(1, req.Current_Step__c);
        System.assertEquals(c.posA.Id, req.Current_Position__c, 'Snapshot do cargo');
        System.assertEquals(PromotionTestSupport.BASE_SALARY, req.Current_Salary__c, 'Snapshot do salario');
        System.assertEquals(c.tree.emp1User.Id, req.Requested_By__c);
        Approval_Step__c step1 = pendingStep(req.Id);
        System.assertEquals('Second_Level_Manager', step1.Approver_Type__c);
        System.assertEquals(c.tree.mgr1User.Id, step1.Approver__c, 'Gestor do gestor aprova a primeira etapa');

        System.runAs(c.tree.mgr1User) {
            PromotionService.managerDecide(req.Id, true, 'De acordo');
        }
        req = reload(req.Id);
        System.assertEquals('Pendente', req.Status__c);
        System.assertEquals(2, req.Current_Step__c);
        System.assertEquals('HR_Team', pendingStep(req.Id).Approver_Type__c);

        // O motor de aprovacao consome muitas consultas por decisao: a segunda metade do fluxo roda em limites novos.
        Test.startTest();
        System.runAs(c.tree.hrUser) {
            PromotionService.hrDecide(req.Id, 6000, true, null);
        }
        req = reload(req.Id);
        System.assertEquals('Aprovado', req.Status__c, 'Data futura: ainda nao efetivada');
        System.assertEquals(6000, req.Proposed_Salary__c);
        System.assertEquals(c.posA.Id, reloadEmployee(c.tree.emp4.Id).Position__c);
        System.assertEquals(1, historyOf(c.tree.emp4.Id).size());

        // O batch diario efetiva quando a data chega: simula a chegada da data.
        update new Promotion_Request__c(Id = req.Id, Effective_Date__c = Date.today());
        Database.executeBatch(new PromotionEffectivationBatch(), 50);
        Test.stopTest();

        System.assertEquals('Efetivado', reload(req.Id).Status__c);
        Employee__c emp = reloadEmployee(c.tree.emp4.Id);
        System.assertEquals(c.posB.Id, emp.Position__c);
        System.assertEquals(6000, emp.Salary__c);
        List<Position_History__c> history = historyOf(c.tree.emp4.Id);
        System.assertEquals(2, history.size());
        System.assertEquals('Admissao', history[0].Change_Reason__c);
        System.assertEquals(Date.today().addDays(-1), history[0].End_Date__c, 'Historico anterior fechado no dia anterior');
        System.assertEquals('Promocao', history[1].Change_Reason__c);
        System.assertEquals(c.posB.Id, history[1].Position__c);
        System.assertEquals(6000, history[1].Salary__c);
        System.assertEquals(Date.today(), history[1].Start_Date__c);
        System.assertEquals(null, history[1].End_Date__c, 'Novo historico fica aberto');
        System.assertEquals(req.Id, history[1].Promotion_Request__c);
    }

    @IsTest
    static void immediateEffectivationAndSkippedFirstStep() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        // O gestor 1 e o aprovador de segundo nivel e tambem o solicitante: a primeira etapa e pulada.
        PromotionService.SubmitResult result = submit(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id, Date.today());
        Promotion_Request__c req = reload(result.requestId);
        System.assertEquals('Pendente', req.Status__c);
        System.assertEquals(2, req.Current_Step__c, 'Etapa do gestor pulada, direto para o RH');
        Integer skippedSteps = 0;
        for (Approval_Step__c s : [SELECT Status__c, Comments__c FROM Approval_Step__c WHERE Promotion_Request__c = :req.Id]) {
            if (s.Status__c == 'Aprovado' && s.Comments__c == ApprovalService.SKIPPED_COMMENT) {
                skippedSteps++;
            }
        }
        System.assertEquals(1, skippedSteps);

        System.runAs(c.tree.hrUser) {
            PromotionService.hrDecide(req.Id, 5500, true, null);
        }
        System.assertEquals('Efetivado', reload(req.Id).Status__c, 'Data de hoje: efetivacao na hora');
        Employee__c emp = reloadEmployee(c.tree.emp1.Id);
        System.assertEquals(c.posB.Id, emp.Position__c);
        System.assertEquals(5500, emp.Salary__c);
        List<Position_History__c> history = historyOf(c.tree.emp1.Id);
        System.assertEquals(2, history.size());
        System.assertEquals(Date.today().addDays(-1), history[0].End_Date__c);
        System.assertEquals(null, history[1].End_Date__c);
        System.assert(PromotionService.notificationsSent > 0, 'Colaborador e gestor sao notificados');
    }

    @IsTest
    static void rejectionByManager() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult r1 = submit(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id, Date.today().addDays(5));

        Test.startTest();
        System.runAs(c.tree.mgr1User) {
            try {
                PromotionService.managerDecide(r1.requestId, false, null);
                System.assert(false, 'Rejeitar exige comentario');
            } catch (ApprovalService.ApprovalException e) {
                System.assert(e.getMessage().contains('comentário'));
            }
            PromotionService.managerDecide(r1.requestId, false, 'Sem orcamento');
        }
        Test.stopTest();
        System.assertEquals('Rejeitado', reload(r1.requestId).Status__c);
        System.assertEquals(0, [SELECT COUNT() FROM Approval_Step__c WHERE Promotion_Request__c = :r1.requestId AND Status__c = 'Pendente']);
        // Nova solicitacao do mesmo colaborador e possivel depois da rejeicao.
        System.assertEquals(null, submitError(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id, Date.today().addDays(5)));
    }

    @IsTest
    static void rejectionByHrNeedsNoSalary() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult r = submit(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id, Date.today().addDays(5));
        Test.startTest();
        System.runAs(c.tree.hrUser) {
            PromotionService.hrDecide(r.requestId, null, false, 'Fora do ciclo');
        }
        Test.stopTest();
        Promotion_Request__c req = reload(r.requestId);
        System.assertEquals('Rejeitado', req.Status__c);
        System.assertEquals(null, req.Proposed_Salary__c);
        System.assertEquals(c.posA.Id, reloadEmployee(c.tree.emp1.Id).Position__c);
    }

    @IsTest
    static void requesterCancelsPendingRequest() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult r = submit(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id, Date.today().addDays(5));
        System.runAs(c.tree.emp1User) {
            PromotionService.cancel(r.requestId);
        }
        System.assertEquals('Cancelado', reload(r.requestId).Status__c);
        System.runAs(c.tree.emp1User) {
            try {
                PromotionService.cancel(r.requestId);
                System.assert(false, 'Ja cancelada');
            } catch (PromotionService.PromotionException e) {
                System.assert(e.getMessage().contains('pendentes'));
            }
        }
    }

    // ------------------------------------------------------------------------------------------ regras P1 a P4

    @IsTest
    static void p1OnlyChainOfManagersCanRequest() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Date effective = Date.today().addDays(5);
        System.assertEquals(PromotionService.MSG_NOT_IN_CHAIN, submitError(c.tree.emp2User, c.tree.emp4.Id, c.posB.Id, effective), 'Colega sem relacao de gestao');
        System.assertEquals(PromotionService.MSG_NOT_IN_CHAIN, submitError(c.tree.mgr1User, c.tree.emp3.Id, c.posB.Id, effective), 'Equipe de outro gestor');
        System.assertEquals(PromotionService.MSG_NOT_IN_CHAIN, submitError(c.tree.mgr1User, c.tree.mgr1.Id, c.posB.Id, effective), 'Autopromocao');
        System.assertEquals(PromotionService.MSG_NOT_IN_CHAIN, submitError(c.tree.hrUser, c.tree.emp4.Id, c.posB.Id, effective), 'Usuario sem colaborador');
        System.assertEquals(0, [SELECT COUNT() FROM Promotion_Request__c]);
    }

    @IsTest
    static void p1AppliesToDirectDmlToo() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Promotion_Request__c r = new Promotion_Request__c(
            Employee__c = c.tree.emp3.Id,
            Proposed_Position__c = c.posB.Id,
            Justification__c = 'ZZTEST-x',
            Effective_Date__c = Date.today().addDays(3)
        );
        System.runAs(c.tree.mgr1User) {
            Database.SaveResult sr = Database.insert(r, false);
            System.assert(!sr.isSuccess());
            System.assertEquals(PromotionService.MSG_NOT_IN_CHAIN, sr.getErrors()[0].getMessage());
        }
    }

    @IsTest
    static void p2NewPositionMustDifferAndBeActive() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Date effective = Date.today().addDays(5);
        System.assertEquals(PromotionService.MSG_SAME_POSITION, submitError(c.tree.mgr1User, c.tree.emp1.Id, c.posA.Id, effective));
        System.assertEquals(PromotionService.MSG_INACTIVE_POSITION, submitError(c.tree.mgr1User, c.tree.emp1.Id, c.posX.Id, effective));
    }

    @IsTest
    static void p2OffTrackIsOnlyAWarning() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult r = submit(c.tree.mgr1User, c.tree.emp1.Id, c.posC.Id, Date.today().addDays(5));
        System.assertEquals(PromotionService.MSG_OFF_TRACK, r.warning);
        System.assertEquals('Pendente', reload(r.requestId).Status__c, 'O aviso nao bloqueia a solicitacao');
    }

    @IsTest
    static void p3EffectiveDateCannotBeInThePast() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.assertEquals(
            PromotionService.MSG_PAST_DATE,
            submitError(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id, Date.today().addDays(-1))
        );
        PromotionService.SubmitResult r = submit(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id, Date.today());
        System.assertNotEquals(null, r.requestId, 'Hoje e permitido');

        Promotion_Request__c change = new Promotion_Request__c(Id = r.requestId, Effective_Date__c = Date.today().addDays(-2));
        Database.SaveResult sr = Database.update(change, false);
        System.assert(!sr.isSuccess());
        System.assertEquals(PromotionService.MSG_PAST_DATE, sr.getErrors()[0].getMessage());
    }

    @IsTest
    static void p4OnlyOnePendingRequestPerEmployee() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Date effective = Date.today().addDays(5);
        submit(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id, effective);
        System.assertEquals(PromotionService.MSG_PENDING, submitError(c.tree.mgr1User, c.tree.emp4.Id, c.posC.Id, effective));
        System.assertEquals(1, [SELECT COUNT() FROM Promotion_Request__c WHERE Employee__c = :c.tree.emp4.Id], 'Nada ficou gravado');
    }

    @IsTest
    static void p4GuardsTheMoveToPendingAsWell() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Promotion_Request__c> drafts = new List<Promotion_Request__c>();
        for (Integer i = 0; i < 2; i++) {
            drafts.add(
                new Promotion_Request__c(
                    Employee__c = c.tree.emp1.Id,
                    Proposed_Position__c = c.posB.Id,
                    Justification__c = 'ZZTEST-rascunho ' + i,
                    Effective_Date__c = Date.today().addDays(4)
                )
            );
        }
        System.runAs(c.tree.mgr1User) {
            insert drafts;
        }
        // Dois rascunhos para o mesmo colaborador passando a Pendente no mesmo lote: o segundo e recusado.
        for (Promotion_Request__c d : drafts) {
            d.Status__c = 'Pendente';
        }
        List<Database.SaveResult> results = Database.update(drafts, false);
        System.assertEquals(1, (results[0].isSuccess() ? 1 : 0) + (results[1].isSuccess() ? 1 : 0));
        Database.SaveResult failed = results[0].isSuccess() ? results[1] : results[0];
        System.assertEquals(PromotionService.MSG_PENDING, failed.getErrors()[0].getMessage());
    }

    @IsTest
    static void justificationIsRequiredAndSnapshotCannotBeForged() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.runAs(c.tree.mgr1User) {
            try {
                PromotionService.createAndSubmit(c.tree.emp1.Id, c.posB.Id, Date.today().addDays(3), '  ');
                System.assert(false, 'Justificativa em branco');
            } catch (PromotionService.PromotionException e) {
                System.assertEquals(PromotionService.MSG_REQUIRED, e.getMessage());
            }
        }
        Promotion_Request__c noJustification = new Promotion_Request__c(
            Employee__c = c.tree.emp1.Id,
            Proposed_Position__c = c.posB.Id,
            Effective_Date__c = Date.today().addDays(3)
        );
        Promotion_Request__c forged = new Promotion_Request__c(
            Employee__c = c.tree.emp1.Id,
            Proposed_Position__c = c.posB.Id,
            Justification__c = 'ZZTEST-forjado',
            Effective_Date__c = Date.today().addDays(3),
            Current_Position__c = c.posC.Id,
            Current_Salary__c = 999999,
            Requested_By__c = c.tree.hrUser.Id
        );
        System.runAs(c.tree.mgr1User) {
            Database.SaveResult blank = Database.insert(noJustification, false);
            System.assertEquals(PromotionService.MSG_JUSTIFICATION, blank.getErrors()[0].getMessage());
            insert forged;
        }
        Promotion_Request__c saved = reload(forged.Id);
        System.assertEquals(c.posA.Id, saved.Current_Position__c, 'Snapshot vem do colaborador, nao do cliente');
        System.assertEquals(PromotionTestSupport.BASE_SALARY, saved.Current_Salary__c);
        System.assertEquals(c.tree.mgr1User.Id, saved.Requested_By__c);
    }

    // ------------------------------------------------------------------------------------------ regra P6

    @IsTest
    static void p6HrMustInformSalaryWithinBandOrJustify() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult r = submit(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id, Date.today().addDays(7));
        Id requestId = r.requestId;
        Test.startTest();
        System.runAs(c.tree.hrUser) {
            assertHrError(requestId, null, null, PromotionService.MSG_SALARY_REQUIRED);
            assertHrError(requestId, 0, null, PromotionService.MSG_SALARY_REQUIRED);
            assertHrError(requestId, 9000, null, PromotionService.MSG_OUT_OF_BAND);
            assertHrError(requestId, 4000, '  ', PromotionService.MSG_OUT_OF_BAND);
            PromotionService.hrDecide(requestId, 9000, true, 'Retencao de talento, aprovado pela diretoria');
        }
        Test.stopTest();
        Promotion_Request__c req = reload(requestId);
        System.assertEquals('Aprovado', req.Status__c);
        System.assertEquals(9000, req.Proposed_Salary__c);
    }

    private static void assertHrError(Id requestId, Decimal salary, String comments, String expected) {
        try {
            PromotionService.hrDecide(requestId, salary, true, comments);
            System.assert(false, 'Esperava: ' + expected);
        } catch (PromotionService.PromotionException e) {
            System.assertEquals(expected, e.getMessage());
        }
    }

    @IsTest
    static void p6PositionWithoutBandAcceptsAnySalary() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult r = submit(c.tree.mgr1User, c.tree.emp1.Id, c.posC.Id, Date.today().addDays(7));
        System.runAs(c.tree.hrUser) {
            PromotionService.hrDecide(r.requestId, 12345, true, null);
        }
        System.assertEquals('Aprovado', reload(r.requestId).Status__c);
    }

    @IsTest
    static void onlyHrDecidesTheHrStepAndOnlyWhenItIsPending() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult skipped = submit(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id, Date.today().addDays(7));
        System.runAs(c.tree.mgr1User) {
            try {
                PromotionService.hrDecide(skipped.requestId, 6000, true, null);
                System.assert(false, 'Gestor nao decide a etapa do RH');
            } catch (PromotionService.PromotionException e) {
                System.assertEquals(PromotionService.MSG_ONLY_HR, e.getMessage());
            }
        }
        // Pedido com a primeira etapa ainda pendente: o RH nao pode decidir antes.
        PromotionService.SubmitResult early = submit(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id, Date.today().addDays(7));
        System.runAs(c.tree.hrUser) {
            try {
                PromotionService.hrDecide(early.requestId, 6000, true, null);
                System.assert(false, 'Etapa do RH ainda nao chegou');
            } catch (PromotionService.PromotionException e) {
                System.assertEquals(PromotionService.MSG_NOT_AWAITING_HR, e.getMessage());
            }
        }
    }

    @IsTest
    static void onlyTheStepApproverDecidesTheManagerStep() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PromotionService.SubmitResult r = submit(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id, Date.today().addDays(7));
        System.runAs(c.tree.emp2User) {
            try {
                PromotionService.managerDecide(r.requestId, true, null);
                System.assert(false, 'Nao e o aprovador');
            } catch (Exception e) {
                System.assert(e instanceof PromotionService.PromotionException || e instanceof ApprovalService.ApprovalException);
            }
        }
        System.assertEquals('Pendente', reload(r.requestId).Status__c);
        System.assertEquals(1, reload(r.requestId).Current_Step__c);
    }

    @IsTest
    static void bandEvaluation() {
        System.assertEquals(PromotionService.BAND_NONE, PromotionService.evaluateBand(5000, null, null));
        System.assertEquals(null, PromotionService.evaluateBand(null, 5000, 8000));
        System.assertEquals(PromotionService.BAND_BELOW, PromotionService.evaluateBand(4999.99, 5000, 8000));
        System.assertEquals(PromotionService.BAND_ABOVE, PromotionService.evaluateBand(8000.01, 5000, 8000));
        System.assertEquals(PromotionService.BAND_WITHIN, PromotionService.evaluateBand(5000, 5000, 8000));
        System.assertEquals(PromotionService.BAND_WITHIN, PromotionService.evaluateBand(8000, 5000, 8000));
        System.assertEquals(PromotionService.BAND_WITHIN, PromotionService.evaluateBand(100, null, 8000));
    }

    // ------------------------------------------------------------------------------------------ efetivacao

    @IsTest
    static void effectivationIsIdempotentAndIgnoresWrongStatus() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.assertEquals(0, PromotionService.effectivate(null));
        System.assertEquals(0, PromotionService.effectivate(new Set<Id>()));

        List<Promotion_Request__c> rows = PromotionTestSupport.approvedRequests(
            new List<Employee__c>{ c.tree.emp1, c.tree.emp2 },
            c.posB.Id,
            6000,
            Date.today()
        );
        rows[1].Status__c = 'Pendente';
        TriggerHandler.bypass('PromotionRequestTriggerHandler');
        update rows[1];
        TriggerHandler.clearBypass('PromotionRequestTriggerHandler');

        Set<Id> ids = new Map<Id, Promotion_Request__c>(rows).keySet();
        System.assertEquals(1, PromotionService.effectivate(ids), 'So o Aprovado');
        System.assertEquals(0, PromotionService.effectivate(ids), 'Segunda execucao nao repete');
        System.assertEquals(2, historyOf(c.tree.emp1.Id).size());
        System.assertEquals(1, historyOf(c.tree.emp2.Id).size());
        System.assertEquals(c.posA.Id, reloadEmployee(c.tree.emp2.Id).Position__c);
    }

    @IsTest
    static void secondApprovedRequestOfTheSameEmployeeWaitsForTheNextRun() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Promotion_Request__c> rows = PromotionTestSupport.approvedRequests(
            new List<Employee__c>{ c.tree.emp1, c.tree.emp1 },
            c.posB.Id,
            6000,
            Date.today()
        );
        Set<Id> ids = new Map<Id, Promotion_Request__c>(rows).keySet();
        System.assertEquals(1, PromotionService.effectivate(ids));
        System.assertEquals(1, [SELECT COUNT() FROM Promotion_Request__c WHERE Status__c = 'Aprovado']);
        System.assertEquals(1, [SELECT COUNT() FROM Promotion_Request__c WHERE Status__c = 'Efetivado']);
    }

    @IsTest
    static void effectivationWithoutProposedSalaryKeepsCurrentSalary() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Promotion_Request__c> rows = PromotionTestSupport.approvedRequests(new List<Employee__c>{ c.tree.emp1 }, c.posB.Id, null, Date.today());
        PromotionService.effectivate(new Map<Id, Promotion_Request__c>(rows).keySet());
        Employee__c emp = reloadEmployee(c.tree.emp1.Id);
        System.assertEquals(c.posB.Id, emp.Position__c);
        System.assertEquals(PromotionTestSupport.BASE_SALARY, emp.Salary__c);
        System.assertEquals(PromotionTestSupport.BASE_SALARY, historyOf(c.tree.emp1.Id)[1].Salary__c);
    }

    // ------------------------------------------------------------------------------------------ lote na trigger

    @IsTest
    static void triggerValidatesAndSharesTwoHundredRequests() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Employee__c> team = new List<Employee__c>();
        for (Integer i = 0; i < 200; i++) {
            Employee__c e = HrTestDataFactory.buildEmployee(c.tree.mgr1.Id, null);
            e.Position__c = c.posA.Id;
            e.Salary__c = PromotionTestSupport.BASE_SALARY;
            team.add(e);
        }
        insert team;

        List<Promotion_Request__c> requests = new List<Promotion_Request__c>();
        for (Employee__c e : team) {
            requests.add(
                new Promotion_Request__c(
                    Employee__c = e.Id,
                    Proposed_Position__c = c.posB.Id,
                    Justification__c = 'ZZTEST-lote',
                    Effective_Date__c = Date.today().addDays(10)
                )
            );
        }
        Test.startTest();
        System.runAs(c.tree.mgr1User) {
            insert requests;
        }
        Test.stopTest();

        Decimal baseSalary = PromotionTestSupport.BASE_SALARY;
        System.assertEquals(200, [SELECT COUNT() FROM Promotion_Request__c WHERE Current_Salary__c = :baseSalary]);
        System.assertEquals(
            200,
            [SELECT COUNT() FROM Promotion_Request__Share WHERE RowCause = :PromotionSharingService.REASON AND ParentId IN :requests]
        );
    }

    @IsTest
    static void approvalHandlerDelegatesToTheService() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Promotion_Request__c> rows = PromotionTestSupport.approvedRequests(new List<Employee__c>{ c.tree.emp1 }, c.posB.Id, 6000, Date.today());
        PromotionApprovalHandler handler = new PromotionApprovalHandler();
        handler.onStepAdvanced(rows[0].Id, 2);
        handler.onRejected(rows[0].Id);
        System.assertEquals('Aprovado', reload(rows[0].Id).Status__c, 'Notificacoes nao mudam o status');
        handler.onApproved(rows[0].Id);
        System.assertEquals('Efetivado', reload(rows[0].Id).Status__c);
        handler.onApproved(c.tree.emp1.Id);
    }

    @IsTest
    static void approvalFutureDatedOnlyNotifiesTheRequester() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Promotion_Request__c> rows = PromotionTestSupport.approvedRequests(
            new List<Employee__c>{ c.tree.emp1 },
            c.posB.Id,
            6000,
            Date.today().addDays(30)
        );
        update new Promotion_Request__c(Id = rows[0].Id, Requested_By__c = c.tree.mgr1User.Id);
        new PromotionApprovalHandler().onApproved(rows[0].Id);
        System.assertEquals('Aprovado', reload(rows[0].Id).Status__c);
    }
}
