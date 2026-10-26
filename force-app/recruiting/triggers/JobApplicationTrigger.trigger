trigger JobApplicationTrigger on Job_Application__c(
    before insert,
    before update,
    after insert,
    after update,
    after delete,
    after undelete
) {
    new JobApplicationTriggerHandler().run();
}
