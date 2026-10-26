/**
 * Consultas de Job_Opening__c sempre em USER_MODE: FLS e compartilhamento do usuario decidem o que volta.
 */
public inherited sharing class JobOpeningSelector {
    public static Job_Opening__c byId(Id openingId) {
        List<Job_Opening__c> rows = byIds(new Set<Id>{ openingId });
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<Job_Opening__c> byIds(Set<Id> openingIds) {
        return [
            SELECT
                Id,
                Name,
                Status__c,
                Hiring_Manager__c,
                Recruiter__c,
                Public_Slug__c,
                Publish_On_Portal__c,
                Openings_Count__c,
                Applications_Count__c,
                Opened_Date__c,
                Closed_Date__c
            FROM Job_Opening__c
            WHERE Id IN :openingIds
            WITH USER_MODE
        ];
    }

    /** Vagas que ja tiveram ou tem funil (todas menos rascunho), para o seletor do kanban. */
    public static List<Job_Opening__c> forBoard(Integer maxRows) {
        return [
            SELECT Id, Name, Status__c, Applications_Count__c
            FROM Job_Opening__c
            WHERE Status__c != 'Rascunho'
            WITH USER_MODE
            ORDER BY Name
            LIMIT :maxRows
        ];
    }
}
