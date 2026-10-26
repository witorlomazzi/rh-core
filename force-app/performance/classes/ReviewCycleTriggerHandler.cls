/** Handler de Review_Cycle__c: delega as validacoes ao ReviewCycleService. */
public with sharing class ReviewCycleTriggerHandler extends TriggerHandler {
    protected override void beforeInsert() {
        ReviewCycleService.validateChanges((List<Review_Cycle__c>) Trigger.new, null);
    }

    protected override void beforeUpdate() {
        ReviewCycleService.validateChanges((List<Review_Cycle__c>) Trigger.new, (Map<Id, Review_Cycle__c>) Trigger.oldMap);
    }
}
