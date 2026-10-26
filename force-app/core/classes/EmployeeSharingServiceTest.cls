@IsTest
private class EmployeeSharingServiceTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static Set<Id> shareUsers(Id employeeId, String reason) {
        Set<Id> result = new Set<Id>();
        for (Employee__Share s : [SELECT UserOrGroupId FROM Employee__Share WHERE ParentId = :employeeId AND RowCause = :reason]) {
            result.add(s.UserOrGroupId);
        }
        return result;
    }

    private static Employee__c reload(Id employeeId) {
        return [
            SELECT Id, Manager__c, Hierarchy_Path__c, Hierarchy_Depth__c, Direct_Reports_Count__c
            FROM Employee__c
            WHERE Id = :employeeId
        ];
    }

    @IsTest
    static void newEmployeeGetsSelfAndChainShares() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Assert.isTrue(shareUsers(t.emp1.Id, EmployeeSharingService.SELF_REASON).contains(t.emp1User.Id), 'Proprio usuario le o registro');
        Assert.isTrue(shareUsers(t.emp1.Id, EmployeeSharingService.CHAIN_REASON).contains(t.mgr1User.Id), 'Gestor direto le');
        Set<Id> chainOfEmp4 = shareUsers(t.emp4.Id, EmployeeSharingService.CHAIN_REASON);
        Assert.isTrue(chainOfEmp4.contains(t.emp1User.Id), 'Gestor direto do emp4');
        Assert.isTrue(chainOfEmp4.contains(t.mgr1User.Id), 'Gestor indireto do emp4');
        Assert.isFalse(shareUsers(t.emp3.Id, EmployeeSharingService.CHAIN_REASON).contains(t.mgr1User.Id), 'Outra equipe');
    }

    @IsTest
    static void pathDepthAndCounts() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Employee__c emp4 = reload(t.emp4.Id);
        Assert.areEqual(t.ceo.Id + ';' + t.mgr1.Id + ';' + t.emp1.Id, emp4.Hierarchy_Path__c);
        Assert.areEqual(3, emp4.Hierarchy_Depth__c);
        Employee__c ceo = reload(t.ceo.Id);
        Assert.isNull(ceo.Hierarchy_Path__c);
        Assert.areEqual(0, ceo.Hierarchy_Depth__c);
        Assert.areEqual(2, ceo.Direct_Reports_Count__c);
        Assert.areEqual(2, reload(t.mgr1.Id).Direct_Reports_Count__c);
        Assert.areEqual(1, reload(t.emp1.Id).Direct_Reports_Count__c);
    }

    @IsTest
    static void managerChangeRemovesOldSharesAndUpdatesSubtree() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Employee__c emp5 = HrTestDataFactory.employee(t.emp4.Id, null);

        Test.startTest();
        update new Employee__c(Id = t.emp1.Id, Manager__c = t.mgr2.Id);
        Test.stopTest();

        Assert.isFalse(shareUsers(t.emp1.Id, EmployeeSharingService.CHAIN_REASON).contains(t.mgr1User.Id), 'Share antigo removido');
        Assert.isFalse(shareUsers(t.emp4.Id, EmployeeSharingService.CHAIN_REASON).contains(t.mgr1User.Id), 'Subarvore perde o gestor antigo');
        Assert.isTrue(shareUsers(t.emp4.Id, EmployeeSharingService.CHAIN_REASON).contains(t.emp1User.Id), 'Gestor direto mantido');
        Assert.areEqual(t.ceo.Id + ';' + t.mgr2.Id + ';' + t.emp1.Id, reload(t.emp4.Id).Hierarchy_Path__c);
        Employee__c reloaded5 = reload(emp5.Id);
        Assert.areEqual(t.ceo.Id + ';' + t.mgr2.Id + ';' + t.emp1.Id + ';' + t.emp4.Id, reloaded5.Hierarchy_Path__c, 'Terceiro nivel da subarvore');
        Assert.areEqual(4, reloaded5.Hierarchy_Depth__c);
        Assert.areEqual(1, reload(t.mgr1.Id).Direct_Reports_Count__c);
        Assert.areEqual(2, reload(t.mgr2.Id).Direct_Reports_Count__c);
    }

    @IsTest
    static void userChangeMovesSelfShare() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Test.startTest();
        update new Employee__c(Id = t.emp2.Id, User__c = null);
        update new Employee__c(Id = t.emp3.Id, User__c = t.emp2User.Id);
        Test.stopTest();
        Assert.isTrue(shareUsers(t.emp2.Id, EmployeeSharingService.SELF_REASON).isEmpty(), 'Share proprio removido');
        Assert.isTrue(shareUsers(t.emp3.Id, EmployeeSharingService.SELF_REASON).contains(t.emp2User.Id), 'Share proprio novo');
    }

    @IsTest
    static void cycleIsBlocked() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        try {
            update new Employee__c(Id = t.mgr1.Id, Manager__c = t.emp4.Id);
            Assert.fail('Ciclo deveria ser bloqueado');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains(EmployeeTriggerHandler.CYCLE_MESSAGE), e.getMessage());
        }
        try {
            update new Employee__c(Id = t.mgr1.Id, Manager__c = t.mgr1.Id);
            Assert.fail('Gestor de si mesmo deveria ser bloqueado');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().length() > 0);
        }
    }

    @IsTest
    static void cycleInsideSameBatchIsBlocked() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        // mgr2 passa para baixo de emp3 e emp3 continua abaixo de mgr2: ciclo no mesmo lote
        List<Employee__c> changes = new List<Employee__c>{
            new Employee__c(Id = t.mgr2.Id, Manager__c = t.emp3.Id),
            new Employee__c(Id = t.emp3.Id, Manager__c = t.mgr2.Id)
        };
        List<Database.SaveResult> results = Database.update(changes, false);
        Assert.isFalse(results[0].isSuccess(), 'Ciclo no lote bloqueado');
    }

    @IsTest
    static void duplicateUserIsBlocked() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        try {
            HrTestDataFactory.employee(t.mgr2.Id, t.emp1User.Id);
            Assert.fail('Usuario duplicado deveria ser bloqueado');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains(EmployeeTriggerHandler.DUPLICATE_USER_MESSAGE), e.getMessage());
        }
        List<Employee__c> sameBatch = new List<Employee__c>{
            HrTestDataFactory.buildEmployee(null, t.hrUser.Id),
            HrTestDataFactory.buildEmployee(null, t.hrUser.Id)
        };
        Assert.isFalse(Database.insert(sameBatch, false)[1].isSuccess(), 'Duplicado dentro do lote');
    }

    @IsTest
    static void bulkOf200WithHierarchyInsideBatch() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        List<Employee__c> batch = new List<Employee__c>();
        for (Integer i = 0; i < 200; i++) {
            batch.add(HrTestDataFactory.buildEmployee(t.mgr2.Id, null));
        }
        insert batch;

        Test.startTest();
        for (Integer i = 0; i < 200; i++) {
            batch[i].Manager__c = i < 20 ? t.mgr1.Id : batch[Math.mod(i, 20)].Id;
        }
        update batch;
        Test.stopTest();

        Employee__c leaf = reload(batch[150].Id);
        Assert.areEqual(t.ceo.Id + ';' + t.mgr1.Id + ';' + batch[10].Id, leaf.Hierarchy_Path__c);
        Assert.areEqual(3, leaf.Hierarchy_Depth__c);
        Assert.areEqual(9, reload(batch[10].Id).Direct_Reports_Count__c);
        Assert.areEqual(22, reload(t.mgr1.Id).Direct_Reports_Count__c);
        Assert.areEqual(1, reload(t.mgr2.Id).Direct_Reports_Count__c, 'So o emp3 continua com o gestor 2');
        Assert.areEqual(
            200,
            [SELECT COUNT() FROM Employee__Share WHERE UserOrGroupId = :t.mgr1User.Id AND ParentId IN :batch AND RowCause = :EmployeeSharingService.CHAIN_REASON],
            'Gestor 1 recebe leitura dos 200'
        );
    }

    @IsTest
    static void largeSubtreeUsesQueueable() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        List<Employee__c> batch = new List<Employee__c>();
        for (Integer i = 0; i < 201; i++) {
            batch.add(HrTestDataFactory.buildEmployee(t.mgr2.Id, null));
        }
        insert batch;
        Test.startTest();
        // mgr2 + emp3 + 201 subordinados: acima do limite sincrono, vai para a fila
        update new Employee__c(Id = t.mgr2.Id, Manager__c = t.mgr1.Id);
        Test.stopTest();
        Set<Id> moved = new Map<Id, Employee__c>(batch).keySet().clone();
        moved.add(t.mgr2.Id);
        moved.add(t.emp3.Id);
        Assert.areEqual(
            200,
            [SELECT COUNT() FROM Employee__Share WHERE UserOrGroupId = :t.mgr1User.Id AND ParentId IN :moved],
            'Primeiro bloco processado pela fila'
        );
        Assert.areEqual(t.ceo.Id + ';' + t.mgr1.Id + ';' + t.mgr2.Id, reload(batch[0].Id).Hierarchy_Path__c, 'Caminho e sincrono');
    }

    @IsTest
    static void deletingManagerRecalculatesSubordinates() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Test.startTest();
        delete new Employee__c(Id = t.emp1.Id);
        Test.stopTest();
        Employee__c emp4 = reload(t.emp4.Id);
        Assert.isNull(emp4.Manager__c);
        Assert.isNull(emp4.Hierarchy_Path__c);
        Assert.areEqual(1, reload(t.mgr1.Id).Direct_Reports_Count__c);
        Assert.isTrue(shareUsers(t.emp4.Id, EmployeeSharingService.CHAIN_REASON).isEmpty());
    }

    @IsTest
    static void recalcBatchRestoresShares() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        delete [SELECT Id FROM Employee__Share WHERE RowCause = :EmployeeSharingService.CHAIN_REASON];
        Test.startTest();
        Database.executeBatch(new EmployeeSharingRecalcBatch());
        Test.stopTest();
        Assert.isTrue(shareUsers(t.emp4.Id, EmployeeSharingService.CHAIN_REASON).contains(t.mgr1User.Id));
    }

    @IsTest
    static void tooDeepHierarchyIsRejected() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        List<Employee__c> chain = new List<Employee__c>();
        for (Integer i = 0; i < 15; i++) {
            chain.add(HrTestDataFactory.buildEmployee(null, null));
        }
        insert chain;
        for (Integer i = 0; i < chain.size(); i++) {
            chain[i].Manager__c = i == 0 ? t.emp4.Id : chain[i - 1].Id;
        }
        try {
            update chain;
            Assert.fail('Hierarquia acima do limite do caminho deve ser recusada');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('profundidade'), e.getMessage());
        }
    }
}
