@IsTest
private class PromotionRequestControllerTest {
    @TestSetup
    static void setup() {
        PromotionTestSupport.createAll();
    }

    @IsTest
    static void teamHasDirectAndIndirectReportsOnly() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.runAs(c.tree.mgr1User) {
            Set<Id> ids = new Set<Id>();
            for (PromotionService.TeamMember m : PromotionRequestController.getTeam()) {
                ids.add(m.id);
                System.assertEquals('ZZTEST-Cargo A', m.positionName);
                System.assertEquals('ZZTEST-Departamento P', m.departmentName);
            }
            System.assertEquals(new Set<Id>{ c.tree.emp1.Id, c.tree.emp2.Id, c.tree.emp4.Id }, ids);
        }
        System.runAs(c.tree.hrUser) {
            System.assertEquals(0, PromotionRequestController.getTeam().size(), 'Usuario sem colaborador nao tem equipe');
        }
    }

    @IsTest
    static void teamSkipsTerminatedEmployees() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        update new Employee__c(Id = c.tree.emp2.Id, Status__c = 'Desligado');
        System.runAs(c.tree.mgr1User) {
            Set<Id> ids = new Set<Id>();
            for (PromotionService.TeamMember m : PromotionRequestController.getTeam()) {
                ids.add(m.id);
            }
            System.assertEquals(new Set<Id>{ c.tree.emp1.Id, c.tree.emp4.Id }, ids);
        }
    }

    @IsTest
    static void formContextHighlightsTheNextPositionOfTheTrack() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.runAs(c.tree.mgr1User) {
            PromotionService.FormContext ctx = PromotionRequestController.getFormContext(c.tree.emp1.Id);
            System.assertEquals(c.posA.Id, ctx.currentPositionId);
            System.assertEquals('ZZTEST-Cargo A', ctx.currentPositionName);
            System.assertEquals(c.posB.Id, ctx.nextPositionId);
            System.assertEquals('ZZTEST-Cargo B', ctx.nextPositionName);
            System.assertEquals(2, ctx.options.size(), 'Sem o cargo atual e sem o inativo');
            System.assertEquals(c.posB.Id, ctx.options[0].value, 'O proximo da trilha vem primeiro');
            System.assertEquals(true, ctx.options[0].isNext);
            System.assertEquals(false, ctx.options[1].isNext);
        }
    }

    @IsTest
    static void formContextWithoutTrackHasNoHighlight() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        update new Employee__c(Id = c.tree.emp1.Id, Position__c = c.posC.Id);
        System.runAs(c.tree.mgr1User) {
            PromotionService.FormContext ctx = PromotionRequestController.getFormContext(c.tree.emp1.Id);
            System.assertEquals(null, ctx.nextPositionId);
            for (PromotionService.PositionOption o : ctx.options) {
                System.assertEquals(false, o.isNext);
            }
        }
    }

    @IsTest
    static void submitReturnsNameAndWarning() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.runAs(c.tree.mgr1User) {
            PromotionService.SubmitResult ok = PromotionRequestController.submitRequest(c.tree.emp1.Id, c.posB.Id, Date.today().addDays(7), 'ZZTEST-ok');
            System.assertNotEquals(null, ok.requestName);
            System.assertEquals(null, ok.warning);
        }
        System.runAs(c.tree.mgr1User) {
            PromotionService.SubmitResult off = PromotionRequestController.submitRequest(c.tree.emp2.Id, c.posC.Id, Date.today().addDays(7), 'ZZTEST-fora');
            System.assertEquals(PromotionService.MSG_OFF_TRACK, off.warning);
        }
    }

    @IsTest
    static void submitErrorsBecomeFriendlyMessages() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.runAs(c.tree.mgr1User) {
            try {
                PromotionRequestController.submitRequest(c.tree.emp1.Id, c.posA.Id, Date.today().addDays(7), 'ZZTEST-x');
                System.assert(false, 'Mesmo cargo');
            } catch (AuraHandledException e) {
                System.assertEquals(PromotionService.MSG_SAME_POSITION, e.getMessage());
            }
            try {
                PromotionRequestController.submitRequest(null, c.posB.Id, Date.today(), 'x');
                System.assert(false, 'Campos obrigatorios');
            } catch (AuraHandledException e) {
                System.assertEquals(PromotionService.MSG_REQUIRED, e.getMessage());
            }
        }
    }

    @IsTest
    static void requesterCancelsThroughTheController() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.runAs(c.tree.emp1User) {
            PromotionService.SubmitResult r = PromotionRequestController.submitRequest(c.tree.emp4.Id, c.posB.Id, Date.today().addDays(7), 'ZZTEST-cancelar');
            PromotionRequestController.cancelRequest(r.requestId);
            System.assertEquals('Cancelado', [SELECT Status__c FROM Promotion_Request__c WHERE Id = :r.requestId].Status__c);
            try {
                PromotionRequestController.cancelRequest(r.requestId);
                System.assert(false, 'Ja cancelada');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('pendentes'));
            }
        }
    }

    @IsTest
    static void twoStepFlowThroughTheController() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId;
        System.runAs(c.tree.emp1User) {
            requestId = PromotionRequestController.submitRequest(c.tree.emp4.Id, c.posB.Id, Date.today().addDays(7), 'ZZTEST-fluxo').requestId;
        }
        System.runAs(c.tree.mgr1User) {
            PromotionRequestController.managerDecide(requestId, true, 'De acordo');
        }
        Test.startTest();
        System.runAs(c.tree.hrUser) {
            List<ApprovalService.ApprovalItem> items = PromotionRequestController.getPendingForHr();
            System.assertEquals(1, items.size());
            System.assertEquals(requestId, items[0].requestId);
            PromotionService.HrReview review = PromotionRequestController.getHrReview(requestId);
            System.assertEquals(true, review.canDecide);
            System.assertEquals('ZZTEST-Cargo B', review.proposedPositionName);
            PromotionRequestController.hrDecide(requestId, 6000, true, null);
            System.assertEquals(false, PromotionRequestController.getHrReview(requestId).canDecide, 'Ja decidida');
            System.assertEquals(0, PromotionRequestController.getPendingForHr().size());
        }
        Test.stopTest();
        System.assertEquals('Aprovado', [SELECT Status__c FROM Promotion_Request__c WHERE Id = :requestId].Status__c);
    }

    @IsTest
    static void decisionErrorsBecomeFriendlyMessages() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId;
        System.runAs(c.tree.emp1User) {
            requestId = PromotionRequestController.submitRequest(c.tree.emp4.Id, c.posB.Id, Date.today().addDays(7), 'ZZTEST-erros').requestId;
        }
        System.runAs(c.tree.emp2User) {
            try {
                PromotionRequestController.managerDecide(requestId, true, null);
                System.assert(false, 'Nao e o aprovador');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }
        }
        System.runAs(c.tree.mgr1User) {
            try {
                PromotionRequestController.managerDecide(requestId, false, null);
                System.assert(false, 'Rejeitar exige comentario');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('comentário'));
            }
            try {
                PromotionRequestController.hrDecide(requestId, 6000, true, null);
                System.assert(false, 'Gestor nao e RH');
            } catch (AuraHandledException e) {
                System.assertEquals(PromotionService.MSG_ONLY_HR, e.getMessage());
            }
        }
    }

    @IsTest
    static void historyDefaultsToTheCurrentUsersEmployee() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.runAs(c.tree.emp1User) {
            PositionHistoryService.HistoryResult own = PromotionRequestController.getHistory(null);
            System.assertEquals(1, own.entries.size());
            System.assertEquals('Admissão', own.entries[0].reasonLabel);
        }
        System.runAs(c.tree.hrUser) {
            PositionHistoryService.HistoryResult none = PromotionRequestController.getHistory(null);
            System.assertEquals(0, none.entries.size(), 'RH sem colaborador vinculado');
            System.assertEquals(true, none.salaryVisible);
        }
    }
}
