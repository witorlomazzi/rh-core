trigger SelfAssessmentTrigger on Self_Assessment__c(before insert, before update) {
    new SelfAssessmentTriggerHandler().run();
}
