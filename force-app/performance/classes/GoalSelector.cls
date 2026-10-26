/**
 * Consultas de Goal__c. As leituras para a tela usam USER_MODE (o acesso vem do colaborador pai); a soma de pesos
 * usada pelas validacoes de trigger le em modo sistema, pelo mesmo motivo do ReviewCycleSelector.
 */
public inherited sharing class GoalSelector {
    public static List<Goal__c> byEmployeeAndCycle(Id employeeId, Id cycleId) {
        return [
            SELECT Id, Name, Employee__c, Review_Cycle__c, Description__c, Target__c, Weight__c, Self_Score__c, Status__c
            FROM Goal__c
            WHERE Employee__c = :employeeId AND Review_Cycle__c = :cycleId
            WITH USER_MODE
            ORDER BY CreatedDate, Name
        ];
    }

    public static Goal__c byId(Id goalId) {
        List<Goal__c> rows = [
            SELECT Id, Name, Employee__c, Review_Cycle__c, Description__c, Target__c, Weight__c, Self_Score__c, Status__c
            FROM Goal__c
            WHERE Id = :goalId
            WITH USER_MODE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Soma dos pesos das metas ativas por colaborador e ciclo. Chave: EmployeeId|CycleId. Modo sistema. */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Map<String, Decimal> activeWeightSumsForValidation(Set<Id> employeeIds, Set<Id> cycleIds) {
        Map<String, Decimal> result = new Map<String, Decimal>();
        for (AggregateResult ar : [
            SELECT Employee__c emp, Review_Cycle__c cyc, SUM(Weight__c) total
            FROM Goal__c
            WHERE Employee__c IN :employeeIds AND Review_Cycle__c IN :cycleIds AND Status__c = 'Ativa'
            GROUP BY Employee__c, Review_Cycle__c
        ]) {
            result.put(key((Id) ar.get('emp'), (Id) ar.get('cyc')), (Decimal) ar.get('total'));
        }
        return result;
    }

    public static String key(Id employeeId, Id cycleId) {
        return String.valueOf(employeeId) + '|' + String.valueOf(cycleId);
    }
}
