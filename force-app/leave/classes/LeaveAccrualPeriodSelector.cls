/**
 * Consultas de Leave_Accrual_Period__c. As consultas de tela rodam em USER_MODE: o periodo herda o acesso do
 * colaborador (proprio, cadeia de gestores, RH). byEmployeesSystem e exclusivo do LeaveAccrualService.
 */
public inherited sharing class LeaveAccrualPeriodSelector {
    public static List<Leave_Accrual_Period__c> byEmployee(Id employeeId) {
        return [
            SELECT
                Id, Name, Employee__c, Start_Date__c, End_Date__c, Concession_Deadline__c, Unjustified_Absences__c,
                Entitled_Days__c, Days_Taken__c, Days_Sold__c, Days_Pending__c, Balance_Days__c, Status__c, Unique_Key__c
            FROM Leave_Accrual_Period__c
            WHERE Employee__c = :employeeId
            WITH USER_MODE
            ORDER BY Start_Date__c DESC
        ];
    }

    public static List<Leave_Accrual_Period__c> byIds(Set<Id> ids) {
        return [
            SELECT
                Id, Name, Employee__c, Start_Date__c, End_Date__c, Concession_Deadline__c, Unjustified_Absences__c,
                Entitled_Days__c, Days_Taken__c, Days_Sold__c, Days_Pending__c, Balance_Days__c, Status__c, Unique_Key__c
            FROM Leave_Accrual_Period__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    /**
     * Contexto de sistema (spec 02, LeaveAccrualService): a geracao diaria precisa enxergar os periodos de todos os
     * colaboradores, independentemente de quem executa o lote.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<Leave_Accrual_Period__c> byEmployeesSystem(Set<Id> employeeIds) {
        return [
            SELECT
                Id, Employee__c, Start_Date__c, End_Date__c, Concession_Deadline__c, Unjustified_Absences__c,
                Entitled_Days__c, Days_Taken__c, Days_Sold__c, Days_Pending__c, Balance_Days__c, Status__c, Unique_Key__c
            FROM Leave_Accrual_Period__c
            WHERE Employee__c IN :employeeIds
        ];
    }
}
