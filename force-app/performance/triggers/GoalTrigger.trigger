trigger GoalTrigger on Goal__c(before insert, before update) {
    new GoalTriggerHandler().run();
}
