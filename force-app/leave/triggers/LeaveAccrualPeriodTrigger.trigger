trigger LeaveAccrualPeriodTrigger on Leave_Accrual_Period__c(before insert, before update) {
    new LeaveAccrualPeriodTriggerHandler().run();
}
