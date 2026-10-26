/**
 * Trigger handler de Promotion_Request__c. Sem regra aqui: valida e grava o snapshot no PromotionService e
 * compartilha pelo PromotionSharingService. O nome da classe e usado pelos testes do core em
 * TriggerHandler.bypass(PromotionRequestTriggerHandler).
 */
public with sharing class PromotionRequestTriggerHandler extends TriggerHandler {
    private List<Promotion_Request__c> newList;
    private Map<Id, Promotion_Request__c> oldMap;

    public PromotionRequestTriggerHandler() {
        this.newList = (List<Promotion_Request__c>) Trigger.new;
        this.oldMap = (Map<Id, Promotion_Request__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        PromotionService.prepareNew(newList);
    }

    protected override void beforeUpdate() {
        PromotionService.validateUpdate(newList, oldMap);
    }

    protected override void afterInsert() {
        PromotionSharingService.recalculate(new Map<Id, Promotion_Request__c>(newList).keySet());
    }
}
