/**
 * Consultas de Candidate__c sempre em USER_MODE: o gestor contratante so enxerga candidatos das proprias vagas.
 */
public inherited sharing class CandidateSelector {
    public static List<Candidate__c> byIds(Set<Id> candidateIds) {
        return [
            SELECT
                Id,
                Name,
                Email__c,
                Email_Normalized__c,
                Phone__c,
                LinkedIn_URL__c,
                City__c,
                Source__c,
                Consent_Given__c,
                Last_Activity_Date__c,
                Anonymized__c
            FROM Candidate__c
            WHERE Id IN :candidateIds
            WITH USER_MODE
        ];
    }

    /** Candidato visivel ao usuario com o e-mail informado (normalizado internamente), ou null. */
    public static Candidate__c byEmail(String email) {
        String normalized = CandidateService.normalizeEmail(email);
        List<Candidate__c> rows = [
            SELECT Id, Name, Email__c, Email_Normalized__c, Anonymized__c
            FROM Candidate__c
            WHERE Email_Normalized__c = :normalized
            WITH USER_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }
}
