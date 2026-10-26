/**
 * Handler de Performance_Review__c: travas no PerformanceReviewService e compartilhamento no
 * PerformanceSharingService (avaliador, cadeia de gestores e colaborador depois da liberacao).
 */
public with sharing class PerformanceReviewTriggerHandler extends TriggerHandler {
    protected override void beforeInsert() {
        PerformanceReviewService.prepareInsert((List<Performance_Review__c>) Trigger.new);
    }

    protected override void beforeUpdate() {
        PerformanceReviewService.validateChanges(
            (List<Performance_Review__c>) Trigger.new,
            (Map<Id, Performance_Review__c>) Trigger.oldMap
        );
    }

    protected override void afterInsert() {
        PerformanceSharingService.sync((List<Performance_Review__c>) Trigger.new);
    }

    protected override void afterUpdate() {
        Map<Id, Performance_Review__c> oldMap = (Map<Id, Performance_Review__c>) Trigger.oldMap;
        List<Performance_Review__c> changed = new List<Performance_Review__c>();
        for (Performance_Review__c r : (List<Performance_Review__c>) Trigger.new) {
            Performance_Review__c old = oldMap.get(r.Id);
            if (r.Reviewer__c != old.Reviewer__c || r.Status__c != old.Status__c) {
                changed.add(r);
            }
        }
        PerformanceSharingService.sync(changed);
    }
}
