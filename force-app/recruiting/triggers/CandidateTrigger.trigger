trigger CandidateTrigger on Candidate__c(before insert, before update) {
    new CandidateTriggerHandler().run();
}
