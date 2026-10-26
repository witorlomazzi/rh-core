/**
 * Regras de Onboarding_Task__c no trigger. Valem para qualquer caminho de gravacao (LWC, tela, API, Flow):
 *
 *  - O5: so o responsavel da tarefa ou o RH muda a situacao (o colaborador e o gestor tem Edit no objeto, entao a
 *    regra nao pode ficar so no servico);
 *  - Concluida em: preenchida ao concluir e limpa ao reabrir;
 *  - situacao do plano: Concluido quando nenhuma tarefa esta Pendente (OnboardingService.refreshPlanStatus).
 *
 * Os dados do plano sao atualizados em contexto de sistema dentro do servico (spec 02).
 */
public with sharing class OnboardingTaskTriggerHandler extends TriggerHandler {
    public static final String NOT_ASSIGNED_MESSAGE = OnboardingService.MSG_NOT_ASSIGNED;

    private List<Onboarding_Task__c> newList;
    private Map<Id, Onboarding_Task__c> oldMap;

    public OnboardingTaskTriggerHandler() {
        this.newList = (List<Onboarding_Task__c>) Trigger.new;
        this.oldMap = (Map<Id, Onboarding_Task__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        Datetime now = Datetime.now();
        for (Onboarding_Task__c t : newList) {
            if (t.Status__c == OnboardingService.TASK_DONE && t.Completed_Date__c == null) {
                t.Completed_Date__c = now;
            }
        }
    }

    protected override void beforeUpdate() {
        Datetime now = Datetime.now();
        Boolean hr = OnboardingService.isHr();
        Id currentUserId = UserInfo.getUserId();
        for (Onboarding_Task__c t : newList) {
            Onboarding_Task__c old = oldMap.get(t.Id);
            if (t.Status__c == old.Status__c) {
                continue;
            }
            if (!hr && (old.Assigned_To__c == null || old.Assigned_To__c != currentUserId)) {
                t.Status__c.addError(NOT_ASSIGNED_MESSAGE);
                continue;
            }
            if (t.Status__c == OnboardingService.TASK_DONE) {
                t.Completed_Date__c = now;
            } else {
                t.Completed_Date__c = null;
            }
        }
    }

    protected override void afterInsert() {
        OnboardingService.refreshPlanStatus(planIds(newList, null));
    }

    protected override void afterUpdate() {
        OnboardingService.refreshPlanStatus(planIds(newList, oldMap));
    }

    protected override void afterDelete() {
        OnboardingService.refreshPlanStatus(planIds(oldMap.values(), null));
    }

    /** Planos afetados. Com oldMap, so as tarefas cuja situacao mudou. */
    private Set<Id> planIds(List<Onboarding_Task__c> tasks, Map<Id, Onboarding_Task__c> previous) {
        Set<Id> result = new Set<Id>();
        for (Onboarding_Task__c t : tasks) {
            if (previous == null || previous.get(t.Id).Status__c != t.Status__c) {
                result.add(t.Plan__c);
            }
        }
        return result;
    }
}
