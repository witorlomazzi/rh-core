/**
 * Testes do lote diario de status das ferias e do agendador. Sem usuarios: tudo roda em contexto de sistema.
 */
@IsTest
private class LeaveBatchTest {
    private static Employee__c employee;
    private static Leave_Accrual_Period__c period;

    private static void prepare() {
        employee = HrTestDataFactory.employee(null, null);
        period = new Leave_Accrual_Period__c(
            Employee__c = employee.Id,
            Start_Date__c = Date.today().addYears(-2),
            End_Date__c = Date.today().addYears(-1).addDays(-1),
            Unique_Key__c = employee.Employee_Number__c + '|k'
        );
        insert period;
    }

    private static String statusOf(Id requestId) {
        return [SELECT Status__c FROM Leave_Request__c WHERE Id = :requestId].Status__c;
    }

    private static String employeeStatus() {
        return [SELECT Status__c FROM Employee__c WHERE Id = :employee.Id].Status__c;
    }

    @IsTest
    static void approvedRequestStartingTodayBecomesInProgress() {
        prepare();
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today(), 10, 0, 'Aprovado');
        Test.startTest();
        Database.executeBatch(new LeaveStatusBatch(), 200);
        Test.stopTest();
        Assert.areEqual('Em_Gozo', statusOf(r.Id));
        Assert.areEqual('Ferias', employeeStatus());
    }

    @IsTest
    static void inProgressRequestThatEndedIsConcludedAndEmployeeReturns() {
        prepare();
        update new Employee__c(Id = employee.Id, Status__c = 'Ferias');
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today().addDays(-10), 5, 0, 'Em_Gozo');
        Test.startTest();
        Database.executeBatch(new LeaveStatusBatch(Date.today()), 200);
        Test.stopTest();
        Assert.areEqual('Concluido', statusOf(r.Id));
        Assert.areEqual('Ativo', employeeStatus());
    }

    @IsTest
    static void inProgressRequestStillRunningIsKept() {
        prepare();
        update new Employee__c(Id = employee.Id, Status__c = 'Ferias');
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today().addDays(-3), 10, 0, 'Em_Gozo');
        Test.startTest();
        Database.executeBatch(new LeaveStatusBatch(), 200);
        Test.stopTest();
        Assert.areEqual('Em_Gozo', statusOf(r.Id));
        Assert.areEqual('Ferias', employeeStatus());
    }

    @IsTest
    static void futureRequestIsUntouched() {
        prepare();
        Leave_Request__c future = LeaveTestData.insertRequest(period.Id, Date.today().addDays(5), 10, 0, 'Aprovado');
        Leave_Request__c pending = LeaveTestData.insertRequest(period.Id, Date.today().addDays(-20), 10, 0, 'Pendente');
        Test.startTest();
        Database.executeBatch(new LeaveStatusBatch(), 200);
        Test.stopTest();
        Assert.areEqual('Aprovado', statusOf(future.Id));
        Assert.areEqual('Pendente', statusOf(pending.Id), 'Somente aprovados e em gozo mudam');
        Assert.areEqual('Ativo', employeeStatus());
    }

    @IsTest
    static void approvedRequestThatAlreadyEndedGoesStraightToConcluded() {
        prepare();
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today().addDays(-30), 10, 0, 'Aprovado');
        Test.startTest();
        Database.executeBatch(new LeaveStatusBatch(), 200);
        Test.stopTest();
        Assert.areEqual('Concluido', statusOf(r.Id));
        Assert.areEqual('Ativo', employeeStatus(), 'Colaborador nao foi para ferias');
    }

    @IsTest
    static void employeeOnLeaveOrTerminatedKeepsTheOwnStatus() {
        prepare();
        update new Employee__c(Id = employee.Id, Status__c = 'Afastado');
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today(), 10, 0, 'Aprovado');
        Test.startTest();
        Database.executeBatch(new LeaveStatusBatch(), 200);
        Test.stopTest();
        Assert.areEqual('Em_Gozo', statusOf(r.Id));
        Assert.areEqual('Afastado', employeeStatus());
    }

    @IsTest
    static void bulkOfTwoHundredRequests() {
        prepare();
        List<Leave_Request__c> requests = new List<Leave_Request__c>();
        for (Integer i = 0; i < 200; i++) {
            requests.add(
                new Leave_Request__c(
                    Accrual_Period__c = period.Id,
                    Start_Date__c = Date.today().addDays(-i),
                    Days__c = 1 + i,
                    Sold_Days__c = 0,
                    Status__c = 'Aprovado'
                )
            );
        }
        insert requests;
        LeaveStatusBatch.process(
            [SELECT Id, Status__c, Start_Date__c, End_Date__c, Employee__c FROM Leave_Request__c WHERE Id IN :requests],
            Date.today()
        );
        Assert.areEqual(0, [SELECT COUNT() FROM Leave_Request__c WHERE Id IN :requests AND Status__c = 'Aprovado']);
        Assert.areEqual(200, [SELECT COUNT() FROM Leave_Request__c WHERE Id IN :requests AND Status__c IN ('Em_Gozo', 'Concluido')]);
        Assert.areEqual('Ferias', employeeStatus());
    }

    @IsTest
    static void schedulerRunsBothBatches() {
        prepare();
        Leave_Request__c r = LeaveTestData.insertRequest(period.Id, Date.today(), 10, 0, 'Aprovado');
        Employee__c fresh = HrTestDataFactory.buildEmployee(null, null);
        fresh.Hire_Date__c = Date.today().addMonths(-14);
        insert fresh;
        Test.startTest();
        Id jobId = LeaveScheduler.scheduleDaily();
        CronTrigger job = [SELECT CronJobDetail.Name, CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(LeaveScheduler.JOB_NAME, job.CronJobDetail.Name);
        Assert.areEqual(LeaveScheduler.DEFAULT_CRON, job.CronExpression);
        new LeaveScheduler().execute(null);
        Test.stopTest();
        Assert.areEqual('Em_Gozo', statusOf(r.Id));
        Assert.areEqual(2, [SELECT COUNT() FROM Leave_Accrual_Period__c WHERE Employee__c = :fresh.Id]);
    }
}
