/**
 * Consultas de Review_Cycle__c. Os metodos publicos leem em USER_MODE; o metodo "ForValidation" le em modo
 * sistema porque roda dentro de trigger (USER_MODE com bind em trigger dispara erro de plataforma, tmpVar1) e a
 * validacao precisa conhecer o ciclo mesmo de quem nao tem acesso a ele.
 */
public inherited sharing class ReviewCycleSelector {
    public static Review_Cycle__c byId(Id cycleId) {
        List<Review_Cycle__c> rows = [
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c, Self_Review_Due__c, Manager_Review_Due__c, Rating_Scale_Max__c
            FROM Review_Cycle__c
            WHERE Id = :cycleId
            WITH USER_MODE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<Review_Cycle__c> recent(Integer maxRows) {
        return [
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c, Self_Review_Due__c, Manager_Review_Due__c, Rating_Scale_Max__c
            FROM Review_Cycle__c
            WITH USER_MODE
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT :maxRows
        ];
    }

    /** Modo sistema: usado por triggers e pelo servico de ciclo depois de checar o papel de RH. */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Map<Id, Review_Cycle__c> byIdsForValidation(Set<Id> cycleIds) {
        Set<Id> ids = cycleIds.clone();
        ids.remove(null);
        return new Map<Id, Review_Cycle__c>(
            [
                SELECT Id, Name, Status__c, Start_Date__c, End_Date__c, Self_Review_Due__c, Manager_Review_Due__c, Rating_Scale_Max__c
                FROM Review_Cycle__c
                WHERE Id IN :ids
            ]
        );
    }
}
