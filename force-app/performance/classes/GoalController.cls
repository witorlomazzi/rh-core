/**
 * Controller fino das metas do colaborador (performanceMyCycle). As regras ficam no GoalService e no trigger.
 */
public with sharing class GoalController {
    /** Cria (goalId nulo) ou atualiza uma meta do colaborador atual. Devolve o Id da meta. */
    @AuraEnabled
    public static Id saveGoal(Id goalId, Id cycleId, String name, String target, String description, Decimal weight, Decimal selfScore) {
        try {
            if (goalId != null) {
                GoalService.modify(goalId, name, target, description, weight, selfScore);
                return goalId;
            }
            Employee__c me = EmployeeSelector.currentUserEmployee();
            if (me == null) {
                throw new ReviewErrors.ReviewException('Seu usuário não está vinculado a um colaborador.');
            }
            return GoalService.create(me.Id, cycleId, name, target, description, weight).Id;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static void setScore(Id goalId, Decimal selfScore) {
        try {
            GoalService.score(goalId, selfScore);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    /** Remover uma meta e cancela-la: ela deixa de contar na soma de 100%. */
    @AuraEnabled
    public static void cancelGoal(Id goalId) {
        try {
            GoalService.cancel(goalId);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }
}
