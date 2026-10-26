trigger JobOpeningTrigger on Job_Opening__c(before insert, before update, after update) {
    new JobOpeningTriggerHandler().run();
}
