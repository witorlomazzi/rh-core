/**
 * Consultas de Position_History__c.
 *
 * byEmployee roda em USER_MODE e so inclui Salary__c quando o usuario tem acesso ao campo: quem nao tem (gestor,
 * colaborador) recebe o historico sem valores de salario, em vez de uma consulta que falha.
 *
 * Os metodos system* rodam em modo sistema e so sao usados por PositionHistoryService (contexto de sistema).
 */
public inherited sharing class PositionHistorySelector {
    public static Boolean salaryVisible() {
        return Schema.SObjectType.Position_History__c.fields.Salary__c.isAccessible();
    }

    /** Historico do colaborador, do mais recente para o mais antigo. */
    public static List<Position_History__c> byEmployee(Id employeeId) {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Employee__c',
            'Position__c',
            'Position__r.Name',
            'Department__c',
            'Department__r.Name',
            'Start_Date__c',
            'End_Date__c',
            'Change_Reason__c'
        };
        if (salaryVisible()) {
            fields.add('Salary__c');
        }
        String soql =
            'SELECT ' +
            String.join(fields, ', ') +
            ' FROM Position_History__c WHERE Employee__c = :employeeId ORDER BY Start_Date__c DESC, CreatedDate DESC';
        return Database.queryWithBinds(soql, new Map<String, Object>{ 'employeeId' => employeeId }, AccessLevel.USER_MODE);
    }

    // ------------------------------------------------------------------------------ modo sistema

    /** Historico em aberto (sem data final) dos colaboradores. */
    public static List<Position_History__c> systemOpenByEmployees(Set<Id> employeeIds) {
        return [
            SELECT Id, Employee__c, Start_Date__c
            FROM Position_History__c
            WHERE Employee__c IN :employeeIds AND End_Date__c = NULL
            WITH SYSTEM_MODE
        ];
    }

    /** Colaboradores que ja tem algum registro de historico. */
    public static Set<Id> systemEmployeesWithHistory(Set<Id> employeeIds) {
        Set<Id> result = new Set<Id>();
        for (Position_History__c h : [SELECT Employee__c FROM Position_History__c WHERE Employee__c IN :employeeIds WITH SYSTEM_MODE]) {
            result.add(h.Employee__c);
        }
        return result;
    }
}
