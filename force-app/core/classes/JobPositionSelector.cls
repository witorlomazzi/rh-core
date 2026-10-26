/**
 * Consultas de Job_Position__c (OWD Public Read Only). Nao inclui campos salariais da faixa.
 */
public inherited sharing class JobPositionSelector {
    public static List<Job_Position__c> byIds(Set<Id> ids) {
        return [
            SELECT Id, Name, Code__c, Level__c, Career_Track__c, Salary_Band__c, Next_Position__c, Next_Position__r.Name, Active__c
            FROM Job_Position__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    public static List<Job_Position__c> active() {
        return [
            SELECT Id, Name, Code__c, Level__c, Career_Track__c, Salary_Band__c, Next_Position__c, Next_Position__r.Name, Active__c
            FROM Job_Position__c
            WHERE Active__c = TRUE
            WITH USER_MODE
            ORDER BY Name
        ];
    }
}
