trigger EmployeeTrigger on Employee__c(
    before insert,
    before update,
    after insert,
    after update,
    after delete
) {
    new EmployeeTriggerHandler().run();
}
