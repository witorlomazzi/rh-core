/**
 * Desfecho do motor de aprovacao para promocoes (configurado em HR_Approval_Step__mdt, Outcome_Handler__c).
 * Delega tudo ao PromotionService.
 */
public with sharing class PromotionApprovalHandler implements ApprovalOutcomeHandler {
    public void onApproved(Id requestId) {
        PromotionService.onApproved(requestId);
    }

    public void onRejected(Id requestId) {
        PromotionService.onRejected(requestId);
    }

    public void onStepAdvanced(Id requestId, Integer newStep) {
        PromotionService.onStepAdvanced(requestId, newStep);
    }
}
