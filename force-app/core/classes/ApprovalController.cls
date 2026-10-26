/**
 * Controller fino da caixa de aprovacoes (coreApprovalInbox).
 */
public with sharing class ApprovalController {
    @AuraEnabled
    public static List<ApprovalService.ApprovalItem> getPending() {
        try {
            return ApprovalService.pendingForCurrentUser();
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static void decide(Id stepId, Boolean approve, String comments) {
        try {
            ApprovalService.decide(stepId, approve, comments);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static List<Approval_Step__c> getSteps(Id requestId) {
        try {
            return ApprovalStepSelector.byRequest(requestId);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    private static AuraHandledException toAura(Exception e) {
        String message = e instanceof ApprovalService.ApprovalException
            ? e.getMessage()
            : 'Não foi possível concluir a operação. ' + e.getMessage();
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
