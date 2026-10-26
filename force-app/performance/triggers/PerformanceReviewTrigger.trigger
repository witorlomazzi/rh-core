trigger PerformanceReviewTrigger on Performance_Review__c(before insert, before update, after insert, after update) {
    new PerformanceReviewTriggerHandler().run();
}
