/** Handler de Self_Assessment__c: delega as validacoes ao SelfAssessmentService. */
public with sharing class SelfAssessmentTriggerHandler extends TriggerHandler {
    protected override void beforeInsert() {
        SelfAssessmentService.prepareInsert((List<Self_Assessment__c>) Trigger.new);
        SelfAssessmentService.validateChanges((List<Self_Assessment__c>) Trigger.new, null);
    }

    protected override void beforeUpdate() {
        SelfAssessmentService.validateChanges((List<Self_Assessment__c>) Trigger.new, (Map<Id, Self_Assessment__c>) Trigger.oldMap);
    }
}
