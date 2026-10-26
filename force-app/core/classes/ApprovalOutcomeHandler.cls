/**
 * Contrato dos handlers chamados pelo ApprovalService ao final de cada decisao.
 * Implementacoes: LeaveApprovalHandler (leave), PromotionApprovalHandler (promotion), NoopApprovalHandler (core).
 */
public interface ApprovalOutcomeHandler {
    void onApproved(Id requestId);
    void onRejected(Id requestId);
    void onStepAdvanced(Id requestId, Integer newStep);
}
