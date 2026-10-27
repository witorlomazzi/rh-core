@IsTest
private class PositionHistoryServiceTest {
    @TestSetup
    static void setup() {
        PromotionTestSupport.createAll();
    }

    private static List<Position_History__c> historyOf(Id employeeId) {
        return [
            SELECT Position__c, Department__c, Salary__c, Start_Date__c, End_Date__c, Change_Reason__c, Promotion_Request__c
            FROM Position_History__c
            WHERE Employee__c = :employeeId
            ORDER BY Start_Date__c, CreatedDate
        ];
    }

    @IsTest
    static void admissionIsCreatedOnceFromTheEmployeeData() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Employee__c fresh = HrTestDataFactory.buildEmployee(c.tree.mgr1.Id, null);
        fresh.Position__c = c.posB.Id;
        fresh.Department__c = c.department.Id;
        fresh.Salary__c = 7000;
        fresh.Hire_Date__c = Date.today().addMonths(-3);
        insert fresh;
        Employee__c noPosition = HrTestDataFactory.employee(c.tree.mgr1.Id, null);

        Set<Id> ids = new Set<Id>{ fresh.Id, noPosition.Id, c.tree.emp1.Id };
        System.assertEquals(1, PositionHistoryService.createAdmission(ids), 'Sem cargo e com historico sao ignorados');
        System.assertEquals(0, PositionHistoryService.createAdmission(ids), 'Idempotente');

        List<Position_History__c> rows = historyOf(fresh.Id);
        System.assertEquals(1, rows.size());
        System.assertEquals('Admissao', rows[0].Change_Reason__c);
        System.assertEquals(c.posB.Id, rows[0].Position__c);
        System.assertEquals(c.department.Id, rows[0].Department__c);
        System.assertEquals(7000, rows[0].Salary__c);
        System.assertEquals(fresh.Hire_Date__c, rows[0].Start_Date__c);
        System.assertEquals(null, rows[0].End_Date__c);
        System.assertEquals(0, historyOf(noPosition.Id).size());
        System.assertEquals(0, PositionHistoryService.createAdmission(null));
        System.assertEquals(0, PositionHistoryService.createAdmission(new Set<Id>()));
    }

    @IsTest
    static void admissionSupportsTwoHundredEmployees() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Employee__c> team = new List<Employee__c>();
        for (Integer i = 0; i < 200; i++) {
            Employee__c e = HrTestDataFactory.buildEmployee(null, null);
            e.Position__c = c.posA.Id;
            e.Salary__c = 3500;
            team.add(e);
        }
        insert team;
        Test.startTest();
        Integer created = PositionHistoryService.createAdmission(new Map<Id, Employee__c>(team).keySet());
        Test.stopTest();
        System.assertEquals(200, created);
        System.assertEquals(200, [SELECT COUNT() FROM Position_History__c WHERE Employee__c IN :team AND Change_Reason__c = 'Admissao']);
    }

    @IsTest
    static void registerChangeClosesTheOpenRecordTheDayBefore() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Date start = Date.today().addDays(-10);
        PositionHistoryService.registerChanges(
            new List<PositionHistoryService.Change>{
                new PositionHistoryService.Change(c.tree.emp1.Id, c.posB.Id, c.department.Id, 6500, start, 'Merito', null),
                new PositionHistoryService.Change(c.tree.emp1.Id, c.posC.Id, c.department.Id, 1, start, 'Merito', null)
            }
        );
        List<Position_History__c> rows = historyOf(c.tree.emp1.Id);
        System.assertEquals(2, rows.size(), 'A repeticao do mesmo colaborador na lista e ignorada');
        System.assertEquals(start.addDays(-1), rows[0].End_Date__c);
        System.assertEquals(c.posB.Id, rows[1].Position__c);
        System.assertEquals('Merito', rows[1].Change_Reason__c);
        System.assertEquals(null, rows[1].End_Date__c);
    }

    @IsTest
    static void registerChangeNeverClosesBeforeTheRecordStarted() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Date hire = historyOf(c.tree.emp2.Id)[0].Start_Date__c;
        PositionHistoryService.registerChanges(
            new List<PositionHistoryService.Change>{
                new PositionHistoryService.Change(c.tree.emp2.Id, c.posB.Id, c.department.Id, 6000, hire, 'Promocao', null)
            }
        );
        System.assertEquals(hire, historyOf(c.tree.emp2.Id)[0].End_Date__c, 'Fecha no proprio dia de inicio, nunca antes');
    }

    @IsTest
    static void registerChangeWithoutOpenRecordJustOpensTheNewOne() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Employee__c e = HrTestDataFactory.employee(c.tree.mgr1.Id, null);
        PositionHistoryService.registerChanges(
            new List<PositionHistoryService.Change>{
                new PositionHistoryService.Change(e.Id, c.posB.Id, null, 6000, Date.today(), 'Transferencia', null)
            }
        );
        System.assertEquals(1, historyOf(e.Id).size());
        PositionHistoryService.registerChanges(null);
        PositionHistoryService.registerChanges(new List<PositionHistoryService.Change>());
    }

    @IsTest
    static void timelineIsOrderedAndLabelled() {
        // Org limpa: o administrador de teste nao tem permissao de campo sobre os campos do produto.
        User adminUser = HrTestDataFactory.user('zzadm', 'HR_Admin');
        System.runAs(adminUser) {
            PromotionTestSupport.Ctx c = PromotionTestSupport.load();
            PositionHistoryService.registerChanges(
                new List<PositionHistoryService.Change>{
                    new PositionHistoryService.Change(c.tree.emp1.Id, c.posB.Id, c.department.Id, 6500, Date.today(), 'Promocao', null)
                }
            );
            PositionHistoryService.HistoryResult r = PositionHistoryService.timeline(c.tree.emp1.Id);
            System.assertEquals(true, r.salaryVisible, 'O usuario de teste e administrador');
            System.assertEquals(2, r.entries.size());
            System.assertEquals('Promoção', r.entries[0].reasonLabel, 'Mais recente primeiro');
            System.assertEquals(true, r.entries[0].isCurrent);
            System.assertEquals(6500, r.entries[0].salary);
            System.assertEquals('ZZTEST-Cargo B', r.entries[0].positionName);
            System.assertEquals('ZZTEST-Departamento P', r.entries[0].departmentName);
            System.assertEquals('Admissão', r.entries[1].reasonLabel);
            System.assertEquals(false, r.entries[1].isCurrent);
            }
    }
}
