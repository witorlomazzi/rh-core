/**
 * Consultas de Self_Assessment__c. Leituras para a tela em USER_MODE (acesso herdado do colaborador pai);
 * o metodo "ForValidation" le em modo sistema porque roda em trigger (ver ReviewCycleSelector).
 */
public inherited sharing class SelfAssessmentSelector {
    public static List<Self_Assessment__c> byEmployee(Id employeeId) {
        return [
            SELECT
                Id, Name, Employee__c, Review_Cycle__c, Self_Rating__c, Strengths__c, Improvements__c, Submitted__c, Submitted_Date__c,
                Review_Cycle__r.Name, Review_Cycle__r.Status__c, Review_Cycle__r.Start_Date__c, Review_Cycle__r.Self_Review_Due__c,
                Review_Cycle__r.Manager_Review_Due__c, Review_Cycle__r.Rating_Scale_Max__c
            FROM Self_Assessment__c
            WHERE Employee__c = :employeeId
            WITH USER_MODE
            ORDER BY Review_Cycle__r.Start_Date__c DESC NULLS LAST, CreatedDate DESC
        ];
    }

    public static List<Self_Assessment__c> byCycleAndEmployees(Id cycleId, Set<Id> employeeIds) {
        return [
            SELECT Id, Name, Employee__c, Review_Cycle__c, Self_Rating__c, Strengths__c, Improvements__c, Submitted__c, Submitted_Date__c
            FROM Self_Assessment__c
            WHERE Review_Cycle__c = :cycleId AND Employee__c IN :employeeIds
            WITH USER_MODE
        ];
    }

    public static Self_Assessment__c byId(Id assessmentId) {
        List<Self_Assessment__c> rows = [
            SELECT
                Id, Name, Employee__c, Review_Cycle__c, Self_Rating__c, Strengths__c, Improvements__c, Submitted__c, Submitted_Date__c,
                Review_Cycle__r.Name, Review_Cycle__r.Status__c, Review_Cycle__r.Start_Date__c, Review_Cycle__r.Self_Review_Due__c,
                Review_Cycle__r.Manager_Review_Due__c, Review_Cycle__r.Rating_Scale_Max__c
            FROM Self_Assessment__c
            WHERE Id = :assessmentId
            WITH USER_MODE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Autoavaliacao do colaborador no ciclo, com os dados do ciclo. */
    public static Self_Assessment__c byEmployeeAndCycle(Id employeeId, Id cycleId) {
        List<Self_Assessment__c> rows = [
            SELECT
                Id, Name, Employee__c, Review_Cycle__c, Self_Rating__c, Strengths__c, Improvements__c, Submitted__c, Submitted_Date__c,
                Review_Cycle__r.Name, Review_Cycle__r.Status__c, Review_Cycle__r.Start_Date__c, Review_Cycle__r.Self_Review_Due__c,
                Review_Cycle__r.Manager_Review_Due__c, Review_Cycle__r.Rating_Scale_Max__c
            FROM Self_Assessment__c
            WHERE Employee__c = :employeeId AND Review_Cycle__c = :cycleId
            WITH USER_MODE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Total e enviadas no ciclo, na visao do usuario: indice 0 = total, indice 1 = enviadas. */
    public static List<Integer> countsByCycle(Id cycleId) {
        Integer total = 0;
        Integer submitted = 0;
        for (AggregateResult ar : [
            SELECT Submitted__c sub, COUNT(Id) qty
            FROM Self_Assessment__c
            WHERE Review_Cycle__c = :cycleId
            WITH USER_MODE
            GROUP BY Submitted__c
        ]) {
            Integer qty = (Integer) ar.get('qty');
            total += qty;
            if ((Boolean) ar.get('sub') == true) {
                submitted += qty;
            }
        }
        return new List<Integer>{ total, submitted };
    }

    /** Modo sistema: autoavaliacoes pelas chaves EmployeeId|CycleId, para validar a trava de envio nas metas. */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Map<String, Self_Assessment__c> byKeysForValidation(Set<String> keys) {
        Map<String, Self_Assessment__c> result = new Map<String, Self_Assessment__c>();
        for (Self_Assessment__c sa : [
            SELECT Id, Employee__c, Review_Cycle__c, Submitted__c, Unique_Key__c
            FROM Self_Assessment__c
            WHERE Unique_Key__c IN :keys
        ]) {
            result.put(sa.Unique_Key__c, sa);
        }
        return result;
    }
}
