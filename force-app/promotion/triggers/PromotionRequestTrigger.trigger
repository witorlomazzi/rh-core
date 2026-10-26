trigger PromotionRequestTrigger on Promotion_Request__c(before insert, before update, after insert) {
    new PromotionRequestTriggerHandler().run();
}
