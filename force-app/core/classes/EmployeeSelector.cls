/**
 * Consultas de Employee__c sempre em USER_MODE: o compartilhamento (proprio, cadeia de gestores, RH)
 * e a FLS decidem o que volta. Nao seleciona campos salariais.
 */
public inherited sharing class EmployeeSelector {
    public static List<Employee__c> byIds(Set<Id> ids) {
        return [
            SELECT Id, Name, Employee_Number__c, User__c, Email__c, Department__c, Department__r.Name, Position__c,
                Position__r.Name, Manager__c, Manager__r.Name, Manager_User_Id__c, Hire_Date__c, Termination_Date__c,
                Status__c, Employment_Type__c, Work_Location__c, Direct_Reports_Count__c, Hierarchy_Path__c, Hierarchy_Depth__c
            FROM Employee__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    public static List<Employee__c> byUserIds(Set<Id> userIds) {
        return [
            SELECT Id, Name, Employee_Number__c, User__c, Email__c, Department__c, Department__r.Name, Position__c,
                Position__r.Name, Manager__c, Manager__r.Name, Manager_User_Id__c, Hire_Date__c, Termination_Date__c,
                Status__c, Employment_Type__c, Work_Location__c, Direct_Reports_Count__c, Hierarchy_Path__c, Hierarchy_Depth__c
            FROM Employee__c
            WHERE User__c IN :userIds
            WITH USER_MODE
        ];
    }

    /** Colaborador vinculado ao usuario atual, ou null. */
    public static Employee__c currentUserEmployee() {
        List<Employee__c> rows = byUserIds(new Set<Id>{ UserInfo.getUserId() });
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<Employee__c> directReports(Id managerId) {
        return [
            SELECT Id, Name, Employee_Number__c, User__c, Email__c, Department__c, Department__r.Name, Position__c,
                Position__r.Name, Manager__c, Manager__r.Name, Manager_User_Id__c, Hire_Date__c, Termination_Date__c,
                Status__c, Employment_Type__c, Work_Location__c, Direct_Reports_Count__c, Hierarchy_Path__c, Hierarchy_Depth__c
            FROM Employee__c
            WHERE Manager__c = :managerId
            WITH USER_MODE
            ORDER BY Name
        ];
    }

    /** Toda a subarvore abaixo do colaborador (diretos e indiretos), pelo caminho na hierarquia. */
    public static List<Employee__c> subtree(Id employeeId) {
        String pattern = '%' + String.valueOf(employeeId) + '%';
        return [
            SELECT Id, Name, Employee_Number__c, User__c, Email__c, Department__c, Department__r.Name, Position__c,
                Position__r.Name, Manager__c, Manager__r.Name, Manager_User_Id__c, Hire_Date__c, Termination_Date__c,
                Status__c, Employment_Type__c, Work_Location__c, Direct_Reports_Count__c, Hierarchy_Path__c, Hierarchy_Depth__c
            FROM Employee__c
            WHERE Hierarchy_Path__c LIKE :pattern
            WITH USER_MODE
            ORDER BY Hierarchy_Depth__c, Name
        ];
    }

    /** Busca por nome entre os colaboradores visiveis ao usuario. */
    public static List<Employee__c> searchByName(String term, Integer maxRows) {
        String pattern = '%' + term.trim() + '%';
        return [
            SELECT Id, Name, Employee_Number__c, User__c, Department__c, Department__r.Name, Position__c, Position__r.Name,
                Manager__c, Status__c, Direct_Reports_Count__c, Hierarchy_Depth__c
            FROM Employee__c
            WHERE Name LIKE :pattern
            WITH USER_MODE
            ORDER BY Name
            LIMIT :maxRows
        ];
    }

    /** Raizes da hierarquia (sem gestor) visiveis ao usuario. */
    public static List<Employee__c> roots() {
        return [
            SELECT Id, Name, Employee_Number__c, User__c, Department__c, Department__r.Name, Position__c, Position__r.Name,
                Manager__c, Status__c, Direct_Reports_Count__c, Hierarchy_Depth__c
            FROM Employee__c
            WHERE Manager__c = NULL AND Status__c != 'Desligado'
            WITH USER_MODE
            ORDER BY Name
        ];
    }
}
