trigger ReviewCycleTrigger on Review_Cycle__c(before insert, before update) {
    new ReviewCycleTriggerHandler().run();
}
