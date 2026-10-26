/**
 * Controller fino dos LWCs de promocao (promotionRequestForm, promotionHrReview, positionHistoryTimeline).
 * Toda regra esta no PromotionService e no PositionHistoryService; aqui so se converte excecao em mensagem.
 */
public with sharing class PromotionRequestController {
    @AuraEnabled
    public static List<PromotionService.TeamMember> getTeam() {
        try {
            return PromotionService.teamMembers();
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static PromotionService.FormContext getFormContext(Id employeeId) {
        try {
            return PromotionService.formContext(employeeId);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static PromotionService.SubmitResult submitRequest(Id employeeId, Id proposedPositionId, Date effectiveDate, String justification) {
        try {
            return PromotionService.createAndSubmit(employeeId, proposedPositionId, effectiveDate, justification);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static void cancelRequest(Id requestId) {
        try {
            PromotionService.cancel(requestId);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static void managerDecide(Id requestId, Boolean approve, String comments) {
        try {
            PromotionService.managerDecide(requestId, approve, comments);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static List<ApprovalService.ApprovalItem> getPendingForHr() {
        try {
            return PromotionService.pendingForHr();
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static PromotionService.HrReview getHrReview(Id requestId) {
        try {
            return PromotionService.hrReview(requestId);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static void hrDecide(Id requestId, Decimal proposedSalary, Boolean approve, String comments) {
        try {
            PromotionService.hrDecide(requestId, proposedSalary, approve, comments);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /** Historico de cargo do colaborador; sem informar, o do proprio usuario. Salario so para quem tem acesso. */
    @AuraEnabled
    public static PositionHistoryService.HistoryResult getHistory(Id employeeId) {
        try {
            Id target = employeeId;
            if (target == null) {
                Employee__c me = EmployeeSelector.currentUserEmployee();
                if (me == null) {
                    PositionHistoryService.HistoryResult empty = new PositionHistoryService.HistoryResult();
                    empty.salaryVisible = PositionHistorySelector.salaryVisible();
                    return empty;
                }
                target = me.Id;
            }
            return PositionHistoryService.timeline(target);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    private static AuraHandledException toAura(Exception e) {
        Boolean expected = e instanceof PromotionService.PromotionException || e instanceof ApprovalService.ApprovalException;
        String message = expected ? e.getMessage() : 'Não foi possível concluir a operação. ' + e.getMessage();
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
