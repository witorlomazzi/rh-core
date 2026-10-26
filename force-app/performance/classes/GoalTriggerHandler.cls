/** Handler de Goal__c: delega as validacoes ao GoalService. */
public with sharing class GoalTriggerHandler extends TriggerHandler {
    protected override void beforeInsert() {
        GoalService.validateChanges((List<Goal__c>) Trigger.new, null);
    }

    protected override void beforeUpdate() {
        GoalService.validateChanges((List<Goal__c>) Trigger.new, (Map<Id, Goal__c>) Trigger.oldMap);
    }
}
