trigger OnboardingTaskTrigger on Onboarding_Task__c(before insert, before update, after insert, after update, after delete) {
    new OnboardingTaskTriggerHandler().run();
}
