/**
 * Testes dos triggers de Leave_Request__c e Leave_Accrual_Period__c: colaborador preenchido pelo periodo, validacoes
 * basicas, trava de datas fora do rascunho, prazo concessivo e direito pela tabela de faltas. Inclui carga de 200.
 */
@IsTest
private class LeaveTriggerTest {
    private static Employee__c employee;
    private static Leave_Accrual_Period__c period;

    private static void prepare() {
        employee = HrTestDataFactory.employee(null, null);
        period = new Leave_Accrual_Period__c(
            Employee__c = employee.Id,
            Start_Date__c = Date.today().addYears(-2),
            End_Date__c = Date.today().addYears(-1).addDays(-1),
            Unique_Key__c = employee.Employee_Number__c + '|' + String.valueOf(Date.today().addYears(-2))
        );
        insert period;
    }

    // ------------------------------------------------------------------------------------------ periodo

    @IsTest
    static void periodInsertFillsDeadlineAndEntitlement() {
        prepare();
        Leave_Accrual_Period__c saved = LeaveTestData.reloadPeriod(period.Id);
        Assert.areEqual(period.End_Date__c.addMonths(12), saved.Concession_Deadline__c);
        Assert.areEqual(30, saved.Entitled_Days__c);
    }

    @IsTest
    static void periodInsertKeepsInformedEntitlement() {
        prepare();
        Leave_Accrual_Period__c informed = new Leave_Accrual_Period__c(
            Employee__c = employee.Id,
            Start_Date__c = Date.today().addYears(-4),
            End_Date__c = Date.today().addYears(-3).addDays(-1),
            Entitled_Days__c = 18,
            Concession_Deadline__c = Date.today().addYears(-2),
            Unique_Key__c = 'ZZTEST-K2'
        );
        insert informed;
        Leave_Accrual_Period__c saved = LeaveTestData.reloadPeriod(informed.Id);
        Assert.areEqual(18, saved.Entitled_Days__c);
        Assert.areEqual(Date.today().addYears(-2), saved.Concession_Deadline__c);
    }

    @IsTest
    static void periodInsertWithManyAbsencesIsLost() {
        prepare();
        Leave_Accrual_Period__c lost = new Leave_Accrual_Period__c(
            Employee__c = employee.Id,
            Start_Date__c = Date.today().addYears(-4),
            End_Date__c = Date.today().addYears(-3).addDays(-1),
            Unjustified_Absences__c = 40,
            Unique_Key__c = 'ZZTEST-K3'
        );
        insert lost;
        Leave_Accrual_Period__c saved = LeaveTestData.reloadPeriod(lost.Id);
        Assert.areEqual(0, saved.Entitled_Days__c);
        Assert.areEqual('Perdido', saved.Status__c);
    }

    @IsTest
    static void periodWithEndBeforeStartIsRejected() {
        prepare();
        Leave_Accrual_Period__c bad = new Leave_Accrual_Period__c(
            Employee__c = employee.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(-1),
            Unique_Key__c = 'ZZTEST-K4'
        );
        Database.SaveResult r = Database.insert(bad, false);
        Assert.isFalse(r.isSuccess());
        Assert.areEqual(LeaveAccrualPeriodTriggerHandler.DATES_MESSAGE, r.getErrors()[0].getMessage());
    }

    @IsTest
    static void periodEndChangeRecalculatesTheDeadline() {
        prepare();
        Date newEnd = period.End_Date__c.addDays(10);
        update new Leave_Accrual_Period__c(Id = period.Id, End_Date__c = newEnd);
        Assert.areEqual(newEnd.addMonths(12), LeaveTestData.reloadPeriod(period.Id).Concession_Deadline__c);
    }

    @IsTest
    static void periodHandlerCanBeBypassed() {
        prepare();
        TriggerHandler.bypass('LeaveAccrualPeriodTriggerHandler');
        Leave_Accrual_Period__c raw = new Leave_Accrual_Period__c(
            Employee__c = employee.Id,
            Start_Date__c = Date.today().addYears(-6),
            End_Date__c = Date.today().addYears(-5).addDays(-1),
            Unique_Key__c = 'ZZTEST-K5'
        );
        insert raw;
        TriggerHandler.clearBypass('LeaveAccrualPeriodTriggerHandler');
        Leave_Accrual_Period__c saved = LeaveTestData.reloadPeriod(raw.Id);
        Assert.isNull(saved.Concession_Deadline__c);
        Assert.isNull(saved.Entitled_Days__c);
    }

    // ------------------------------------------------------------------------------------------ solicitacao

    @IsTest
    static void requestInsertFillsTheEmployeeFromThePeriod() {
        prepare();
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today().addDays(60), 10, 0, 'Rascunho');
        Assert.areEqual(employee.Id, LeaveTestData.reloadRequest(r.Id).Employee__c);
        Assert.areEqual(Date.today().addDays(69), LeaveTestData.reloadRequest(r.Id).End_Date__c);
    }

    @IsTest
    static void requestWithoutDaysOrWithNegativeSoldIsRejected() {
        prepare();
        Database.SaveResult zero = Database.insert(
            new Leave_Request__c(Accrual_Period__c = period.Id, Start_Date__c = Date.today().addDays(60), Days__c = 0),
            false
        );
        Assert.isFalse(zero.isSuccess());
        Assert.areEqual(LeaveRequestTriggerHandler.DAYS_MESSAGE, zero.getErrors()[0].getMessage());
        Database.SaveResult negative = Database.insert(
            new Leave_Request__c(
                Accrual_Period__c = period.Id,
                Start_Date__c = Date.today().addDays(60),
                Days__c = 10,
                Sold_Days__c = -1
            ),
            false
        );
        Assert.isFalse(negative.isSuccess());
        Assert.areEqual(LeaveRequestTriggerHandler.SOLD_MESSAGE, negative.getErrors()[0].getMessage());
    }

    @IsTest
    static void datesCanChangeOnlyWhileDraft() {
        prepare();
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today().addDays(60), 10, 0, 'Rascunho');
        update new Leave_Request__c(Id = r.Id, Start_Date__c = Date.today().addDays(70), Days__c = 12);
        Assert.areEqual(12, LeaveTestData.reloadRequest(r.Id).Days__c);

        update new Leave_Request__c(Id = r.Id, Status__c = 'Pendente');
        Database.SaveResult blocked = Database.update(new Leave_Request__c(Id = r.Id, Days__c = 20), false);
        Assert.isFalse(blocked.isSuccess());
        Assert.areEqual(LeaveRequestTriggerHandler.LOCK_MESSAGE, blocked.getErrors()[0].getMessage());
        Database.SaveResult sold = Database.update(new Leave_Request__c(Id = r.Id, Sold_Days__c = 3), false);
        Assert.isFalse(sold.isSuccess());
        Database.SaveResult start = Database.update(new Leave_Request__c(Id = r.Id, Start_Date__c = Date.today().addDays(90)), false);
        Assert.isFalse(start.isSuccess());
        // Mudar so o status continua permitido (e o que o servico faz)
        update new Leave_Request__c(Id = r.Id, Status__c = 'Aprovado');
        Assert.areEqual('Aprovado', LeaveTestData.reloadRequest(r.Id).Status__c);
    }

    @IsTest
    static void bulkInsertOfTwoHundredRequests() {
        prepare();
        List<Leave_Request__c> requests = new List<Leave_Request__c>();
        for (Integer i = 0; i < 200; i++) {
            requests.add(
                new Leave_Request__c(
                    Accrual_Period__c = period.Id,
                    Start_Date__c = Date.today().addDays(60 + i),
                    Days__c = 1,
                    Sold_Days__c = 0,
                    Status__c = 'Rascunho'
                )
            );
        }
        insert requests;
        Assert.areEqual(200, [SELECT COUNT() FROM Leave_Request__c WHERE Employee__c = :employee.Id]);
        for (Leave_Request__c r : requests) {
            r.Notes__c = 'Atualizado';
        }
        update requests;
        Assert.areEqual(200, [SELECT COUNT() FROM Leave_Request__c WHERE Notes__c = 'Atualizado']);
    }
}
