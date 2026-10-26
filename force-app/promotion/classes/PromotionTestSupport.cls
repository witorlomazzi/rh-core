/**
 * Dados de teste compartilhados pelos testes do modulo de promocoes. Chamado no @TestSetup de cada classe de teste.
 *
 * Arvore (HrTestDataFactory.orgTree): CEO > gestor 1, gestor 2; gestor 1 > colaboradores 1 e 2; gestor 2 > colaborador 3;
 * colaborador 1 > colaborador 4. Todos recebem o cargo A (faixa 3000 a 5000) e salario 4000. Cargo B e o proximo da
 * trilha de A (faixa 5000 a 8000); cargo C nao tem faixa; cargo X esta inativo.
 *
 * Os colaboradores 1 e 2 recebem tambem HR_Promotion_Manager: sao "gestores" nos cenarios (o colaborador 1 solicita
 * promocao do colaborador 4, que e seu subordinado e subordinado indireto do gestor 1, o aprovador de segundo nivel).
 * Limite de licencas: so os 4 usuarios da fabrica existem.
 */
@IsTest
public class PromotionTestSupport {
    public static final Decimal BASE_SALARY = 4000;

    public class Ctx {
        public HrTestDataFactory.OrgTree tree;
        public Job_Position__c posA;
        public Job_Position__c posB;
        public Job_Position__c posC;
        public Job_Position__c posX;
        public Department__c department;
    }

    public static void createAll() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.orgTree();
        Salary_Band__c bandA = HrTestDataFactory.salaryBand(3000, 5000);
        Salary_Band__c bandB = HrTestDataFactory.salaryBand(5000, 8000);
        Job_Position__c posB = HrTestDataFactory.position(bandB.Id, null);
        Job_Position__c posA = HrTestDataFactory.position(bandA.Id, posB.Id);
        Job_Position__c posC = HrTestDataFactory.position(null, null);
        Job_Position__c posX = HrTestDataFactory.position(bandB.Id, null);
        posA.Name = 'ZZTEST-Cargo A';
        posB.Name = 'ZZTEST-Cargo B';
        posC.Name = 'ZZTEST-Cargo C';
        posX.Name = 'ZZTEST-Cargo X';
        posX.Active__c = false;
        update new List<Job_Position__c>{ posA, posB, posC, posX };
        Department__c dept = HrTestDataFactory.department();
        dept.Name = 'ZZTEST-Departamento P';
        update dept;

        List<Employee__c> all = new List<Employee__c>{ t.ceo, t.mgr1, t.mgr2, t.emp1, t.emp2, t.emp3, t.emp4 };
        List<Employee__c> updates = new List<Employee__c>();
        for (Employee__c e : all) {
            updates.add(new Employee__c(Id = e.Id, Position__c = posA.Id, Department__c = dept.Id, Salary__c = BASE_SALARY));
        }
        update updates;
        PositionHistoryService.createAdmission(new Map<Id, Employee__c>(all).keySet());

        PermissionSet manager = [SELECT Id FROM PermissionSet WHERE Name = 'HR_Promotion_Manager' LIMIT 1];
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = t.emp1User.Id, PermissionSetId = manager.Id),
                new PermissionSetAssignment(AssigneeId = t.emp2User.Id, PermissionSetId = manager.Id)
            };
        }
    }

    public static Ctx load() {
        Ctx c = new Ctx();
        c.tree = HrTestDataFactory.loadOrgTree();
        for (Job_Position__c p : [SELECT Id, Name FROM Job_Position__c WHERE Name LIKE 'ZZTEST-Cargo %']) {
            if (p.Name == 'ZZTEST-Cargo A') {
                c.posA = p;
            } else if (p.Name == 'ZZTEST-Cargo B') {
                c.posB = p;
            } else if (p.Name == 'ZZTEST-Cargo C') {
                c.posC = p;
            } else if (p.Name == 'ZZTEST-Cargo X') {
                c.posX = p;
            }
        }
        c.department = [SELECT Id FROM Department__c WHERE Name = 'ZZTEST-Departamento P' LIMIT 1];
        return c;
    }

    /** Inserta pedidos ja aprovados, sem passar pela trigger (preparo de cenarios de efetivacao). */
    public static List<Promotion_Request__c> approvedRequests(List<Employee__c> employees, Id positionId, Decimal salary, Date effectiveDate) {
        List<Promotion_Request__c> rows = new List<Promotion_Request__c>();
        for (Employee__c e : employees) {
            rows.add(
                new Promotion_Request__c(
                    Employee__c = e.Id,
                    Proposed_Position__c = positionId,
                    Proposed_Salary__c = salary,
                    Justification__c = 'ZZTEST-Justificativa',
                    Effective_Date__c = effectiveDate,
                    Status__c = 'Aprovado'
                )
            );
        }
        TriggerHandler.bypass('PromotionRequestTriggerHandler');
        try {
            insert rows;
        } finally {
            TriggerHandler.clearBypass('PromotionRequestTriggerHandler');
        }
        return rows;
    }
}
