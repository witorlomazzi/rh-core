/**
 * Consultas de Onboarding_Task__c. Sem prefixo: USER_MODE (o plano herda o compartilhamento do colaborador).
 * Prefixo system: modo sistema, so para OnboardingService e OnboardingTaskTriggerHandler (contexto de sistema da
 * spec 02). Em trigger, USER_MODE com bind dispara erro de plataforma (tmpVar1), por isso o handler usa as variantes
 * system.
 */
public inherited sharing class OnboardingTaskSelector {
    public static List<Onboarding_Task__c> byPlanIds(Set<Id> planIds) {
        return [
            SELECT
                Id,
                Name,
                Plan__c,
                Description__c,
                Status__c,
                Owner_Role__c,
                Due_Date__c,
                Due_Offset_Days__c,
                Order__c,
                Completed_Date__c,
                Assigned_To__c,
                Assigned_To__r.Name
            FROM Onboarding_Task__c
            WHERE Plan__c IN :planIds
            WITH USER_MODE
            ORDER BY Plan__c, Order__c NULLS LAST, Name
        ];
    }

    public static List<Onboarding_Task__c> byIds(Set<Id> ids) {
        return [
            SELECT Id, Name, Plan__c, Status__c, Owner_Role__c, Due_Date__c, Assigned_To__c
            FROM Onboarding_Task__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    /** Tarefas pendentes dos planos, com o papel e o prazo-base, para recalcular datas e responsaveis. */
    public static List<Onboarding_Task__c> pendingByPlanIds(Set<Id> planIds) {
        return [
            SELECT Id, Plan__c, Owner_Role__c, Due_Date__c, Due_Offset_Days__c, Order__c, Assigned_To__c
            FROM Onboarding_Task__c
            WHERE Plan__c IN :planIds AND Status__c = 'Pendente'
            WITH USER_MODE
        ];
    }

    /** Total por plano e situacao: Map plano -> (situacao -> quantidade), em USER_MODE. */
    public static Map<Id, Map<String, Integer>> countsByPlan(Set<Id> planIds) {
        List<AggregateResult> rows = [
            SELECT Plan__c planId, Status__c taskStatus, COUNT(Id) total
            FROM Onboarding_Task__c
            WHERE Plan__c IN :planIds
            WITH USER_MODE
            GROUP BY Plan__c, Status__c
        ];
        return toCounts(rows);
    }

    /** Pendentes com prazo anterior a data informada, por plano. */
    public static Map<Id, Integer> overdueByPlan(Set<Id> planIds, Date today) {
        Map<Id, Integer> result = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Plan__c planId, COUNT(Id) total
            FROM Onboarding_Task__c
            WHERE Plan__c IN :planIds AND Status__c = 'Pendente' AND Due_Date__c < :today
            WITH USER_MODE
            GROUP BY Plan__c
        ]) {
            result.put((Id) ar.get('planId'), Integer.valueOf(ar.get('total')));
        }
        return result;
    }

    // ------------------------------------------------------------------------------ modo sistema

    /** Total por plano e situacao em modo sistema (situacao do plano a partir das tarefas). */
    public static Map<Id, Map<String, Integer>> systemCountsByPlan(Set<Id> planIds) {
        List<AggregateResult> rows = [
            SELECT Plan__c planId, Status__c taskStatus, COUNT(Id) total
            FROM Onboarding_Task__c
            WHERE Plan__c IN :planIds
            WITH SYSTEM_MODE
            GROUP BY Plan__c, Status__c
        ];
        return toCounts(rows);
    }

    private static Map<Id, Map<String, Integer>> toCounts(List<AggregateResult> rows) {
        Map<Id, Map<String, Integer>> result = new Map<Id, Map<String, Integer>>();
        for (AggregateResult ar : rows) {
            Id planId = (Id) ar.get('planId');
            if (!result.containsKey(planId)) {
                result.put(planId, new Map<String, Integer>());
            }
            result.get(planId).put((String) ar.get('taskStatus'), Integer.valueOf(ar.get('total')));
        }
        return result;
    }
}
