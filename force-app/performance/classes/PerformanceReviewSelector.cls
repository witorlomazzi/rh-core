/**
 * Consultas de Performance_Review__c. Os metodos publicos leem em USER_MODE: o compartilhamento (gestor, cadeia,
 * colaborador depois da liberacao, RH) decide as linhas e a FLS decide as colunas. Calibrated_Rating__c so e lido
 * pelos metodos "WithCalibration", chamados apenas para o RH (a consulta falha para quem nao tem a FLS).
 * Os metodos "ForService" leem em modo sistema, depois que o servico validou quem pode agir.
 */
public inherited sharing class PerformanceReviewSelector {
    public static Performance_Review__c byId(Id reviewId) {
        List<Performance_Review__c> rows = [
            SELECT
                Id, Name, Review_Cycle__c, Employee__c, Reviewer__c, Manager_Rating__c, Manager_Comments__c, Status__c,
                Released_Date__c, Final_Rating__c, Review_Cycle__r.Name, Review_Cycle__r.Status__c, Review_Cycle__r.Rating_Scale_Max__c, Review_Cycle__r.Self_Review_Due__c,
                Review_Cycle__r.Manager_Review_Due__c, Review_Cycle__r.Start_Date__c, Employee__r.Name, Employee__r.User__c, Employee__r.Position__r.Name
            FROM Performance_Review__c
            WHERE Id = :reviewId
            WITH USER_MODE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Avaliacoes do ciclo visiveis ao usuario, sem a nota calibrada. */
    public static List<Performance_Review__c> byCycle(Id cycleId) {
        return [
            SELECT
                Id, Name, Review_Cycle__c, Employee__c, Reviewer__c, Manager_Rating__c, Status__c, Final_Rating__c,
                Employee__r.Name, Employee__r.Position__r.Name
            FROM Performance_Review__c
            WHERE Review_Cycle__c = :cycleId
            WITH USER_MODE
            ORDER BY Employee__r.Name
        ];
    }

    /** Avaliacao liberada do colaborador no ciclo (o compartilhamento so existe depois da liberacao). */
    public static Performance_Review__c releasedFor(Id employeeId, Id cycleId) {
        List<Performance_Review__c> rows = [
            SELECT Id, Manager_Rating__c, Manager_Comments__c, Status__c, Released_Date__c, Final_Rating__c
            FROM Performance_Review__c
            WHERE Employee__c = :employeeId AND Review_Cycle__c = :cycleId AND Status__c = 'Liberada'
            WITH USER_MODE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Somente RH: linhas da calibracao, com a nota calibrada. */
    public static List<Performance_Review__c> byCycleWithCalibration(Id cycleId) {
        return [
            SELECT
                Id, Name, Employee__c, Reviewer__c, Manager_Rating__c, Calibrated_Rating__c, Status__c, Final_Rating__c,
                Employee__r.Name, Employee__r.Position__r.Name
            FROM Performance_Review__c
            WHERE Review_Cycle__c = :cycleId
            WITH USER_MODE
            ORDER BY Employee__r.Name
        ];
    }

    /** Somente RH: nota calibrada das avaliacoes informadas. */
    public static Map<Id, Decimal> calibratedByIds(Set<Id> reviewIds) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        for (Performance_Review__c r : [
            SELECT Id, Calibrated_Rating__c
            FROM Performance_Review__c
            WHERE Id IN :reviewIds
            WITH USER_MODE
        ]) {
            result.put(r.Id, r.Calibrated_Rating__c);
        }
        return result;
    }

    /** Contagem por situacao, na visao do usuario. */
    public static Map<String, Integer> countByStatus(Id cycleId) {
        Map<String, Integer> result = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT Status__c st, COUNT(Id) qty
            FROM Performance_Review__c
            WHERE Review_Cycle__c = :cycleId
            WITH USER_MODE
            GROUP BY Status__c
        ]) {
            result.put((String) ar.get('st'), (Integer) ar.get('qty'));
        }
        return result;
    }

    /** Avaliacoes do ciclo sem avaliador definido, na visao do usuario. */
    public static Integer countWithoutReviewer(Id cycleId) {
        return [SELECT COUNT() FROM Performance_Review__c WHERE Review_Cycle__c = :cycleId AND Reviewer__c = NULL WITH USER_MODE];
    }

    /**
     * Modo sistema: avaliacao com ciclo e nota calibrada, para calibrar, liberar e validar em trigger. Chamado
     * somente depois da checagem de RH ou do avaliador pelo servico.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<Performance_Review__c> forServiceByCycleAndStatuses(Id cycleId, Set<String> statuses) {
        return [
            SELECT
                Id, Review_Cycle__c, Employee__c, Reviewer__c, Manager_Rating__c, Calibrated_Rating__c, Status__c,
                Employee__r.User__c
            FROM Performance_Review__c
            WHERE Review_Cycle__c = :cycleId AND Status__c IN :statuses
        ];
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Performance_Review__c forServiceById(Id reviewId) {
        List<Performance_Review__c> rows = [
            SELECT
                Id, Review_Cycle__c, Employee__c, Reviewer__c, Manager_Rating__c, Calibrated_Rating__c, Status__c,
                Review_Cycle__r.Status__c, Review_Cycle__r.Rating_Scale_Max__c
            FROM Performance_Review__c
            WHERE Id = :reviewId
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Modo sistema: chaves ja existentes (EmployeeId|CycleId), para o lancamento idempotente. */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Set<String> existingKeys(Set<String> keys) {
        Set<String> result = new Set<String>();
        for (Performance_Review__c r : [SELECT Unique_Key__c FROM Performance_Review__c WHERE Unique_Key__c IN :keys]) {
            result.add(r.Unique_Key__c);
        }
        return result;
    }
}
