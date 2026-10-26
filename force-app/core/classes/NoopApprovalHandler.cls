/**
 * Handler neutro: permite usar e testar o motor de aprovacao sem os modulos. Registra as chamadas para os testes.
 */
public with sharing class NoopApprovalHandler implements ApprovalOutcomeHandler {
    @TestVisible
    private static List<String> calls = new List<String>();

    public void onApproved(Id requestId) {
        calls.add('approved:' + requestId);
    }

    public void onRejected(Id requestId) {
        calls.add('rejected:' + requestId);
    }

    public void onStepAdvanced(Id requestId, Integer newStep) {
        calls.add('advanced:' + requestId + ':' + newStep);
    }
}
