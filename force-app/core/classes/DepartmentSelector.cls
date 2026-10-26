/**
 * Consultas de Department__c (OWD Public Read Only).
 */
public inherited sharing class DepartmentSelector {
    public static List<Department__c> byIds(Set<Id> ids) {
        return [
            SELECT Id, Name, Code__c, Parent_Department__c, Head__c, Cost_Center__c, Active__c
            FROM Department__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    public static List<Department__c> active() {
        return [
            SELECT Id, Name, Code__c, Parent_Department__c, Head__c, Cost_Center__c, Active__c
            FROM Department__c
            WHERE Active__c = TRUE
            WITH USER_MODE
            ORDER BY Name
        ];
    }
}
