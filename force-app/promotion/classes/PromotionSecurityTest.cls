/**
 * Testes de seguranca da spec 02 para promocoes e historico de cargo:
 * 1. colaborador A nao ve dado do colaborador B; 2. gestor ve subordinado direto e indireto; 3. gestor nao ve outra
 * equipe; 4. usuario sem permission set nao recebe dado; 5. gestor nao le campo [S].
 */
@IsTest
private class PromotionSecurityTest {
    @TestSetup
    static void setup() {
        PromotionTestSupport.createAll();
    }

    private static Id requestOf(User requester, Id employeeId, Id positionId) {
        PromotionService.SubmitResult r;
        System.runAs(requester) {
            r = PromotionService.createAndSubmit(employeeId, positionId, Date.today().addDays(10), 'ZZTEST-Seguranca');
        }
        return r.requestId;
    }

    private static Integer visibleRequests(User u, Id requestId) {
        Integer n = 0;
        System.runAs(u) {
            try {
                n = [SELECT COUNT() FROM Promotion_Request__c WHERE Id = :requestId WITH USER_MODE];
            } catch (System.SecurityException e) {
                n = 0;
            } catch (QueryException e) {
                n = 0;
            }
        }
        return n;
    }

    private static PositionHistoryService.HistoryResult historyAs(User u, Id employeeId) {
        PositionHistoryService.HistoryResult result;
        System.runAs(u) {
            result = PromotionRequestController.getHistory(employeeId);
        }
        return result;
    }

    // ------------------------------------------------------------------------------------ historico de cargo

    @IsTest
    static void employeeSeesOnlyOwnHistoryAndNoSalary() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        PositionHistoryService.HistoryResult own = historyAs(c.tree.emp2User, null);
        System.assertEquals(1, own.entries.size(), 'Proprio historico');
        System.assertEquals(false, own.salaryVisible);
        System.assertEquals(null, own.entries[0].salary, 'Colaborador nao ve salario do proprio historico');

        PositionHistoryService.HistoryResult other = historyAs(c.tree.emp2User, c.tree.emp1.Id);
        System.assertEquals(0, other.entries.size(), 'Colega sem relacao de gestao: nada');
    }

    @IsTest
    static void managerSeesDirectAndIndirectReportsWithoutSalary() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        for (Id employeeId : new List<Id>{ c.tree.emp1.Id, c.tree.emp4.Id }) {
            PositionHistoryService.HistoryResult r = historyAs(c.tree.mgr1User, employeeId);
            System.assertEquals(1, r.entries.size(), 'Direto e indireto');
            System.assertEquals(null, r.entries[0].salary);
            System.assertEquals(false, r.salaryVisible);
        }
    }

    @IsTest
    static void managerDoesNotSeeAnotherTeam() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        System.assertEquals(0, historyAs(c.tree.mgr1User, c.tree.emp3.Id).entries.size());
        System.runAs(c.tree.mgr1User) {
            try {
                PromotionRequestController.getFormContext(c.tree.emp3.Id);
                System.assert(false, 'Colaborador de outra equipe');
            } catch (AuraHandledException e) {
                System.assertEquals(PromotionService.MSG_NOT_IN_CHAIN, e.getMessage());
            }
        }
    }

    @IsTest
    static void userWithoutPermissionSetsGetsAnExceptionNeverData() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        User target = c.tree.emp2User;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            delete [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :target.Id AND PermissionSet.IsOwnedByProfile = FALSE];
        }
        System.runAs(target) {
            try {
                PromotionRequestController.getHistory(null);
                System.assert(false, 'Sem permission set nao ha acesso');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Não foi possível'));
            }
            try {
                PromotionRequestController.getTeam();
                System.assert(false, 'Sem permission set nao ha acesso');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Não foi possível'));
            }
        }
        System.assertEquals(0, visibleRequests(target, c.tree.emp1.Id), 'Nem o objeto de promocao e acessivel');
    }

    // ------------------------------------------------------------------------------------ campos [S]

    @IsTest
    static void managerCannotReadSalaryFieldsOfThePromotionRequest() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId = requestOf(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id);
        System.runAs(c.tree.mgr1User) {
            Map<String, Schema.SObjectField> fields = Schema.SObjectType.Promotion_Request__c.fields.getMap();
            System.assertEquals(false, fields.get('Current_Salary__c').getDescribe().isAccessible());
            System.assertEquals(false, fields.get('Proposed_Salary__c').getDescribe().isAccessible());
            System.assertEquals(false, fields.get('Increase_Percent__c').getDescribe().isAccessible());

            List<Promotion_Request__c> visible = PromotionRequestSelector.byIds(new Set<Id>{ requestId });
            System.assertEquals(1, visible.size(), 'O gestor le a propria solicitacao, sem salario');

            try {
                PromotionRequestSelector.byIdsWithSalary(new Set<Id>{ requestId });
                System.assert(false, 'Consulta com salario deve falhar para o gestor');
            } catch (QueryException e) {
                System.assert(true);
            }

            List<Promotion_Request__c> raw = [SELECT Id, Current_Salary__c, Proposed_Salary__c FROM Promotion_Request__c WHERE Id = :requestId];
            Promotion_Request__c stripped = (Promotion_Request__c) Security.stripInaccessible(AccessType.READABLE, raw).getRecords()[0];
            System.assertEquals(false, stripped.isSet('Current_Salary__c'), 'stripInaccessible remove o salario');
            System.assertEquals(false, stripped.isSet('Proposed_Salary__c'));
        }
    }

    @IsTest
    static void managerCannotWriteStatusOrSalaryDirectly() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId = requestOf(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id);
        System.runAs(c.tree.mgr1User) {
            Promotion_Request__c status = new Promotion_Request__c(Id = requestId, Status__c = 'Aprovado');
            try {
                update as user status;
                System.assert(false, 'Status e somente leitura para o gestor');
            } catch (DmlException e) {
                System.assert(true);
            }
            Promotion_Request__c salary = new Promotion_Request__c(Id = requestId, Proposed_Salary__c = 99999);
            try {
                update as user salary;
                System.assert(false, 'Salario e restrito ao RH');
            } catch (DmlException e) {
                System.assert(true);
            }
        }
        System.assertEquals('Pendente', [SELECT Status__c FROM Promotion_Request__c WHERE Id = :requestId].Status__c);
    }

    @IsTest
    static void managerCannotOpenTheHrReview() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId = requestOf(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id);
        System.runAs(c.tree.mgr1User) {
            try {
                PromotionRequestController.getHrReview(requestId);
                System.assert(false, 'Revisao do RH inclui salario');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Não foi possível'));
            }
            System.assertEquals(0, PromotionRequestController.getPendingForHr().size(), 'Lista do RH vazia para o gestor');
        }
    }

    @IsTest
    static void hrReadsSalaryOfRequestAndHistory() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId = requestOf(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id);
        System.runAs(c.tree.hrUser) {
            List<Promotion_Request__c> rows = PromotionRequestSelector.byIdsWithSalary(new Set<Id>{ requestId });
            System.assertEquals(PromotionTestSupport.BASE_SALARY, rows[0].Current_Salary__c);

            PositionHistoryService.HistoryResult h = PromotionRequestController.getHistory(c.tree.emp1.Id);
            System.assertEquals(true, h.salaryVisible);
            System.assertEquals(PromotionTestSupport.BASE_SALARY, h.entries[0].salary);

            PromotionService.HrReview review = PromotionRequestController.getHrReview(requestId);
            System.assertEquals(true, review.canDecide);
            System.assertEquals(5000, review.bandMin);
            System.assertEquals(8000, review.bandMax);
            System.assertEquals(PromotionTestSupport.BASE_SALARY, review.currentSalary);
            System.assertEquals(1, PromotionRequestController.getPendingForHr().size());
        }
    }

    // ------------------------------------------------------------------------------------ visibilidade da solicitacao

    @IsTest
    static void requestIsVisibleOnlyToOwnerApproverAndHr() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        // Solicitacao do colaborador 4 feita pelo colaborador 1 (gestor dele); aprovador de 2o nivel: gestor 1.
        Id requestId = requestOf(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id);
        System.assertEquals(1, visibleRequests(c.tree.emp1User, requestId), 'Solicitante (dono)');
        System.assertEquals(1, visibleRequests(c.tree.mgr1User, requestId), 'Gestor de segundo nivel (share Approver_Chain__c)');
        System.assertEquals(1, visibleRequests(c.tree.hrUser, requestId), 'RH');
        System.assertEquals(0, visibleRequests(c.tree.emp2User, requestId), 'Outro gestor fora da cadeia');
    }

    @IsTest
    static void employeeNeverSeesTheRequestAboutHimself() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId = requestOf(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id);
        System.assertEquals(0, visibleRequests(c.tree.emp1User, requestId), 'O colaborador nao le a solicitacao');
        System.assertEquals(0, visibleRequests(c.tree.emp2User, requestId));
        System.assertEquals(1, visibleRequests(c.tree.mgr1User, requestId));
    }
}
