trigger LeaveRequestTrigger on Leave_Request__c(before insert, before update) {
    new LeaveRequestTriggerHandler().run();
}
