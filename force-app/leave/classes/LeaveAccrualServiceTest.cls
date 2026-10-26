/**
 * Testes da geracao de periodos aquisitivos: quantidade de periodos, idempotencia, tabela de faltas (art. 130),
 * status e lote de 200 colaboradores. Sem usuarios: o servico roda em contexto de sistema.
 */
@IsTest
private class LeaveAccrualServiceTest {
    private static Employee__c newEmployee(Date hireDate) {
        Employee__c e = HrTestDataFactory.buildEmployee(null, null);
        e.Hire_Date__c = hireDate;
        return e;
    }

    private static List<Leave_Accrual_Period__c> periodsOf(Id employeeId) {
        return [
            SELECT
                Id, Start_Date__c, End_Date__c, Concession_Deadline__c, Entitled_Days__c, Status__c, Unique_Key__c,
                Unjustified_Absences__c, Days_Taken__c, Balance_Days__c
            FROM Leave_Accrual_Period__c
            WHERE Employee__c = :employeeId
            ORDER BY Start_Date__c
        ];
    }

    // ------------------------------------------------------------------------------------------ regras puras

    @IsTest
    static void entitledDaysFollowsArticle130() {
        Assert.areEqual(30, LeaveAccrualService.entitledDays(null));
        Assert.areEqual(30, LeaveAccrualService.entitledDays(0));
        Assert.areEqual(30, LeaveAccrualService.entitledDays(5));
        Assert.areEqual(24, LeaveAccrualService.entitledDays(6));
        Assert.areEqual(24, LeaveAccrualService.entitledDays(10));
        Assert.areEqual(24, LeaveAccrualService.entitledDays(14));
        Assert.areEqual(18, LeaveAccrualService.entitledDays(15));
        Assert.areEqual(18, LeaveAccrualService.entitledDays(23));
        Assert.areEqual(12, LeaveAccrualService.entitledDays(24));
        Assert.areEqual(12, LeaveAccrualService.entitledDays(32));
        Assert.areEqual(0, LeaveAccrualService.entitledDays(33));
    }

    @IsTest
    static void entitledDaysWithoutRuleMatchIsZero() {
        LeaveAccrualService.testRules = new List<HR_Absence_Rule__mdt>{
            new HR_Absence_Rule__mdt(Min_Absences__c = 0, Max_Absences__c = 3, Leave_Days__c = 30)
        };
        Assert.areEqual(30, LeaveAccrualService.entitledDays(2));
        Assert.areEqual(0, LeaveAccrualService.entitledDays(10));
    }

    @IsTest
    static void statusForCoversEveryBranch() {
        Date today = Date.newInstance(2026, 6, 1);
        Date deadline = Date.newInstance(2026, 12, 1);
        Assert.areEqual('Perdido', LeaveAccrualService.statusFor(33, today.addDays(-1), deadline, 0, today, 60));
        Assert.areEqual('Em_Aquisicao', LeaveAccrualService.statusFor(0, today, deadline, 30, today, 60));
        Assert.areEqual('Concluido', LeaveAccrualService.statusFor(0, today.addDays(-1), deadline, 0, today, 60));
        Assert.areEqual('Concluido', LeaveAccrualService.statusFor(0, today.addDays(-1), deadline, null, today, 60));
        Assert.areEqual('Disponivel', LeaveAccrualService.statusFor(0, today.addDays(-1), deadline, 10, today, 60));
        Assert.areEqual(
            'Prazo_Proximo',
            LeaveAccrualService.statusFor(0, today.addDays(-1), today.addDays(60), 10, today, 60)
        );
        Assert.areEqual(
            'Prazo_Proximo',
            LeaveAccrualService.statusFor(0, today.addDays(-1), today.addDays(-5), 10, today, 60),
            'Prazo vencido com saldo continua em alerta'
        );
        Assert.areEqual(
            'Disponivel',
            LeaveAccrualService.statusFor(0, today.addDays(-1), today.addDays(61), 10, today, 60)
        );
    }

    @IsTest
    static void uniqueKeyAndPeriodEnd() {
        Assert.areEqual('VTR-1|2026-03-10', LeaveAccrualService.uniqueKey('VTR-1', Date.newInstance(2026, 3, 10)));
        Assert.areEqual(Date.newInstance(2027, 3, 9), LeaveAccrualService.periodEndDate(Date.newInstance(2026, 3, 10), 0, 12));
        Assert.areEqual(Date.newInstance(2029, 3, 9), LeaveAccrualService.periodEndDate(Date.newInstance(2026, 3, 10), 2, 12));
    }

    // ------------------------------------------------------------------------------------------ geracao

    @IsTest
    static void hireThreeYearsAgoGeneratesThreePeriods() {
        // Admissao ha 3 anos menos 1 dia: o 4o periodo so comecaria amanha.
        Date today = Date.today();
        Employee__c e = newEmployee(today.addYears(-3).addDays(1));
        insert e;
        LeaveAccrualService.Summary s = LeaveAccrualService.generate(new List<Employee__c>{ e }, today);

        List<Leave_Accrual_Period__c> periods = periodsOf(e.Id);
        Assert.areEqual(3, periods.size());
        Assert.areEqual(3, s.created);
        Assert.areEqual(e.Hire_Date__c, periods[0].Start_Date__c);
        Assert.areEqual(e.Hire_Date__c.addYears(1).addDays(-1), periods[0].End_Date__c);
        Assert.areEqual(periods[0].End_Date__c.addMonths(12), periods[0].Concession_Deadline__c);
        Assert.areEqual(periods[0].End_Date__c.addDays(1), periods[1].Start_Date__c);
        Assert.areEqual(e.Employee_Number__c + '|' + String.valueOf(e.Hire_Date__c), periods[0].Unique_Key__c);
        for (Leave_Accrual_Period__c p : periods) {
            Assert.areEqual(30, p.Entitled_Days__c);
        }
        Assert.areEqual('Em_Aquisicao', periods[2].Status__c, 'O periodo atual ainda esta em aquisicao');
        Assert.areEqual('Prazo_Proximo', periods[0].Status__c, 'Periodo com prazo concessivo vencido e saldo');
    }

    @IsTest
    static void exactlyThreeYearsGeneratesTheCurrentFourthPeriod() {
        Employee__c e = newEmployee(Date.today().addYears(-3));
        insert e;
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Assert.areEqual(4, periodsOf(e.Id).size());
    }

    @IsTest
    static void rerunningDoesNotDuplicateOrRewrite() {
        Employee__c e = newEmployee(Date.today().addYears(-3).addDays(1));
        insert e;
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        LeaveAccrualService.Summary second = LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Assert.areEqual(3, periodsOf(e.Id).size());
        Assert.areEqual(0, second.created);
        Assert.areEqual(0, second.updated);
        Assert.areEqual(0, second.errors);
    }

    @IsTest
    static void generateForEmployeeIdsLoadsTheEmployees() {
        Employee__c e = newEmployee(Date.today().addMonths(-14));
        insert e;
        LeaveAccrualService.Summary s = LeaveAccrualService.generateForEmployeeIds(new Set<Id>{ e.Id }, Date.today());
        Assert.areEqual(1, s.employees);
        List<Leave_Accrual_Period__c> periods = periodsOf(e.Id);
        Assert.areEqual(2, periods.size());
        Assert.areEqual('Disponivel', periods[0].Status__c, 'Prazo concessivo ainda longe');
    }

    @IsTest
    static void tenAbsencesGiveTwentyFourDays() {
        Employee__c e = newEmployee(Date.today().addMonths(-14));
        insert e;
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Leave_Accrual_Period__c first = periodsOf(e.Id)[0];
        update new Leave_Accrual_Period__c(Id = first.Id, Unjustified_Absences__c = 10);
        // O trigger recalcula o direito quando o RH altera as faltas.
        Assert.areEqual(24, periodsOf(e.Id)[0].Entitled_Days__c);
        // E o servico mantem o valor ao reexecutar.
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Assert.areEqual(24, periodsOf(e.Id)[0].Entitled_Days__c);
    }

    @IsTest
    static void thirtyThreeAbsencesLoseThePeriod() {
        Employee__c e = newEmployee(Date.today().addMonths(-14));
        insert e;
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Leave_Accrual_Period__c first = periodsOf(e.Id)[0];
        update new Leave_Accrual_Period__c(Id = first.Id, Unjustified_Absences__c = 33);
        Leave_Accrual_Period__c lost = periodsOf(e.Id)[0];
        Assert.areEqual(0, lost.Entitled_Days__c);
        Assert.areEqual('Perdido', lost.Status__c);
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Assert.areEqual('Perdido', periodsOf(e.Id)[0].Status__c);
        // Corrigindo as faltas, o periodo volta a ter direito.
        update new Leave_Accrual_Period__c(Id = first.Id, Unjustified_Absences__c = 2);
        Leave_Accrual_Period__c restored = periodsOf(e.Id)[0];
        Assert.areEqual(30, restored.Entitled_Days__c);
        Assert.areEqual('Disponivel', restored.Status__c);
    }

    @IsTest
    static void periodWithAllDaysUsedIsConcluded() {
        Employee__c e = newEmployee(Date.today().addMonths(-14));
        insert e;
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Leave_Accrual_Period__c first = periodsOf(e.Id)[0];
        LeaveTestData.insertRequest(first.Id, Date.today().addDays(60), 30, 0, 'Aprovado');
        LeaveAccrualService.generate(new List<Employee__c>{ e }, Date.today());
        Assert.areEqual('Concluido', periodsOf(e.Id)[0].Status__c);
    }

    @IsTest
    static void onlyCltEmployeesThatAreNotTerminatedAreEligible() {
        Employee__c intern = newEmployee(Date.today().addYears(-2));
        intern.Employment_Type__c = 'Estagio';
        Employee__c terminated = newEmployee(Date.today().addYears(-2));
        terminated.Status__c = 'Desligado';
        Employee__c future = newEmployee(Date.today().addDays(10));
        future.Status__c = 'Pre_Admissao';
        Employee__c clt = newEmployee(Date.today().addYears(-2));
        insert new List<Employee__c>{ intern, terminated, future, clt };
        LeaveAccrualService.Summary s = LeaveAccrualService.generate(
            new List<Employee__c>{ intern, terminated, future, clt },
            Date.today()
        );
        Assert.areEqual(1, s.employees);
        Assert.areEqual(0, periodsOf(intern.Id).size());
        Assert.areEqual(0, periodsOf(terminated.Id).size());
        Assert.areEqual(0, periodsOf(future.Id).size());
        Assert.areEqual(3, periodsOf(clt.Id).size());
    }

    @IsTest
    static void emptyListDoesNothing() {
        LeaveAccrualService.Summary s = LeaveAccrualService.generate(new List<Employee__c>(), Date.today());
        Assert.areEqual(0, s.employees);
        Assert.areEqual(0, s.created);
    }

    @IsTest
    static void batchOfTwoHundredEmployees() {
        List<Employee__c> employees = new List<Employee__c>();
        for (Integer i = 0; i < 200; i++) {
            employees.add(newEmployee(Date.today().addYears(-3).addDays(1)));
        }
        TriggerHandler.bypass('EmployeeTriggerHandler');
        insert employees;
        TriggerHandler.clearBypass('EmployeeTriggerHandler');

        LeaveAccrualService.Summary s = LeaveAccrualService.generate(employees, Date.today());
        Assert.areEqual(200, s.employees);
        Assert.areEqual(600, s.created);
        Assert.areEqual(0, s.errors);
        Assert.areEqual(600, [SELECT COUNT() FROM Leave_Accrual_Period__c WHERE Employee__c IN :employees]);
        // Segunda execucao: nada a gravar
        LeaveAccrualService.Summary again = LeaveAccrualService.generate(employees, Date.today());
        Assert.areEqual(0, again.created);
        Assert.areEqual(0, again.updated);
    }

    @IsTest
    static void accrualBatchGeneratesForAllEligibleEmployees() {
        Employee__c a = newEmployee(Date.today().addYears(-2).addDays(1));
        Employee__c b = newEmployee(Date.today().addMonths(-14));
        Employee__c lost = newEmployee(Date.today().addYears(-2));
        lost.Status__c = 'Desligado';
        insert new List<Employee__c>{ a, b, lost };
        Test.startTest();
        Database.executeBatch(new LeaveAccrualBatch(Date.today()), 200);
        Test.stopTest();
        Assert.areEqual(2, periodsOf(a.Id).size());
        Assert.areEqual(2, periodsOf(b.Id).size());
        Assert.areEqual(0, periodsOf(lost.Id).size());
    }

    @IsTest
    static void accrualBatchDefaultConstructorUsesToday() {
        Employee__c a = newEmployee(Date.today().addMonths(-14));
        insert a;
        Test.startTest();
        Database.executeBatch(new LeaveAccrualBatch(), 200);
        Test.stopTest();
        Assert.areEqual(2, periodsOf(a.Id).size());
    }
}
