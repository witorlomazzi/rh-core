/**
 * Testes de seguranca da spec 02 (itens 1, 2, 3 e 5) para EmployeeSelector e OrgChartController.
 * O item 4 (sem permission set) esta em EmployeeNoAccessTest, por limite de licencas por transacao.
 */
@IsTest
private class EmployeeSecurityTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.orgTree();
        update new Employee__c(Id = t.emp1.Id, Salary__c = 5000);
    }

    @IsTest
    static void employeeDoesNotSeePeer() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.emp1User) {
            Assert.isTrue(EmployeeSelector.byIds(new Set<Id>{ t.emp2.Id }).isEmpty(), 'Colega da mesma equipe');
            Assert.isTrue(OrgChartController.search('ZZTEST-EMP2').isEmpty(), 'Busca nao revela colega');
            Assert.areEqual(t.emp1.Id, EmployeeSelector.currentUserEmployee().Id, 'Ve o proprio cadastro');
        }
    }

    @IsTest
    static void managerSeesDirectAndIndirect() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.mgr1User) {
            Assert.areEqual(2, EmployeeSelector.byIds(new Set<Id>{ t.emp1.Id, t.emp4.Id }).size());
            Assert.areEqual(3, EmployeeSelector.subtree(t.mgr1.Id).size(), 'emp1, emp2 e emp4');
            Assert.areEqual(2, EmployeeSelector.directReports(t.mgr1.Id).size());
        }
    }

    @IsTest
    static void managerDoesNotSeeOtherTeam() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.mgr1User) {
            Assert.isTrue(EmployeeSelector.byIds(new Set<Id>{ t.emp3.Id, t.mgr2.Id }).isEmpty());
            Assert.isTrue(OrgChartController.search('ZZTEST-EMP3').isEmpty());
            Assert.isTrue(OrgChartController.children(t.mgr2.Id).isEmpty());
        }
    }

    @IsTest
    static void managerCannotReadSalary() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.mgr1User) {
            try {
                List<Employee__c> rows = [SELECT Id, Salary__c FROM Employee__c WHERE Id = :t.emp1.Id WITH USER_MODE];
                Assert.fail('Consulta de salario deveria falhar para o gestor: ' + rows);
            } catch (QueryException e) {
                Assert.isTrue(e.getMessage().length() > 0);
            }
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.READABLE,
                [SELECT Id, Salary__c FROM Employee__c WHERE Id = :t.emp1.Id]
            );
            Assert.isFalse(decision.getRecords()[0].isSet('Salary__c'), 'Salario removido por FLS');
        }
        System.runAs(t.hrUser) {
            Employee__c row = [SELECT Id, Salary__c FROM Employee__c WHERE Id = :t.emp1.Id WITH USER_MODE];
            Assert.areEqual(5000, row.Salary__c, 'RH le salario');
        }
    }

    @IsTest
    static void orgChartForEmployeeShowsManagerCardAndReports() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.emp1User) {
            OrgChartController.OrgChartView view = OrgChartController.getInitial(null);
            Assert.areEqual(t.emp1.Id, view.focus[0].id);
            Assert.areEqual(t.mgr1.Id, view.manager.id, 'Cartao do gestor');
            Assert.isFalse(view.manager.hasChildren, 'Nao expande a equipe do gestor');
            Assert.areEqual(1, view.reports.size());
            Assert.areEqual(t.emp4.Id, view.reports[0].id);
            Assert.isFalse(view.isHr);
        }
    }

    @IsTest
    static void orgChartForManagerUsesVisibleManagerAndRecordPage() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.mgr1User) {
            OrgChartController.OrgChartView view = OrgChartController.getInitial(t.emp1.Id);
            Assert.areEqual(t.emp1.Id, view.focus[0].id);
            Assert.areEqual(t.mgr1.Id, view.manager.id);
            Assert.isTrue(view.manager.hasChildren, 'Gestor visivel pode expandir');
            Assert.areEqual(3, OrgChartController.search('ZZTEST-EMP').size(), 'emp1, emp2 e emp4');
        }
    }

    @IsTest
    static void orgChartForHrStartsAtRoot() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.hrUser) {
            OrgChartController.OrgChartView view = OrgChartController.getInitial(null);
            Assert.isTrue(view.isHr);
            Assert.areEqual(1, view.focus.size());
            Assert.areEqual(t.ceo.Id, view.focus[0].id);
            Assert.areEqual(2, view.reports.size());
            Assert.areEqual('Z', view.focus[0].initials, 'Nome de uma palavra gera uma inicial');
        }
    }

    @IsTest
    static void searchNeedsTwoCharacters() {
        Assert.isTrue(OrgChartController.search('a').isEmpty());
        Assert.isTrue(OrgChartController.search(null).isEmpty());
        Assert.areEqual('MS', OrgChartController.initialsOf('maria da silva'));
        Assert.areEqual('A', OrgChartController.initialsOf('Ana'));
        Assert.areEqual('', OrgChartController.initialsOf(' '));
    }

    @IsTest
    static void userWithoutEmployeeGetsFriendlyMessage() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        update new Employee__c(Id = t.emp2.Id, User__c = null);
        System.runAs(t.emp2User) {
            OrgChartController.OrgChartView view = OrgChartController.getInitial(null);
            Assert.isTrue(view.focus.isEmpty());
            Assert.isTrue(view.emptyMessage.contains('não está vinculado'));
        }
    }
}
