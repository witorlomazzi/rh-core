/**
 * Desfecho da aprovacao de ferias, chamado pelo ApprovalService (HR_Approval_Step__mdt, Outcome_Handler__c).
 * O motor ja grava o status; aqui o handler garante o status final de forma idempotente e avisa o colaborador
 * (e quem fez o pedido, se for outra pessoa) pela notificacao HR_Request_Decided.
 *
 * Contexto de sistema: o handler roda dentro da transacao de quem decidiu (gestor ou RH), que nao tem Edit em
 * Status__c nem leitura do usuario do colaborador. Le e grava apenas o necessario para o desfecho.
 */
// Contexto do motor de aprovacao (spec 02): grava o status final e le dados minimos para a notificacao.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class LeaveApprovalHandler implements ApprovalOutcomeHandler {
    public static final String TYPE_DECIDED = 'HR_Request_Decided';

    public void onApproved(Id requestId) {
        Leave_Request__c r = load(requestId);
        if (r == null) {
            return;
        }
        if (r.Status__c != 'Aprovado') {
            update new Leave_Request__c(Id = requestId, Status__c = 'Aprovado');
        }
        notifyOwner(
            r,
            'Férias aprovadas',
            'Suas férias de ' +
                LeaveRuleEngine.formatDate(r.Start_Date__c) +
                ' a ' +
                LeaveRuleEngine.formatDate(LeaveRuleEngine.endOf(r)) +
                ' foram aprovadas.'
        );
    }

    public void onRejected(Id requestId) {
        Leave_Request__c r = load(requestId);
        if (r == null) {
            return;
        }
        if (r.Status__c != 'Rejeitado') {
            update new Leave_Request__c(Id = requestId, Status__c = 'Rejeitado');
        }
        String body = 'Suas férias de ' + LeaveRuleEngine.formatDate(r.Start_Date__c) + ' foram rejeitadas.';
        String reason = rejectionReason(requestId);
        if (String.isNotBlank(reason)) {
            body += ' Motivo: ' + reason;
        }
        notifyOwner(r, 'Férias rejeitadas', body);
    }

    public void onStepAdvanced(Id requestId, Integer newStep) {
        // O aprovador da nova etapa ja e avisado pelo motor; o colaborador acompanha a etapa na lista de pedidos.
        System.debug(LoggingLevel.DEBUG, 'Solicitacao ' + requestId + ' avancou para a etapa ' + newStep);
    }

    private static Leave_Request__c load(Id requestId) {
        List<Leave_Request__c> rows = [
            SELECT Id, Name, Status__c, Start_Date__c, Days__c, Requested_By__c, Employee__r.User__c
            FROM Leave_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static String rejectionReason(Id requestId) {
        List<Approval_Step__c> steps = [
            SELECT Comments__c
            FROM Approval_Step__c
            WHERE Leave_Request__c = :requestId AND Status__c = 'Rejeitado'
            ORDER BY Decision_Date__c DESC NULLS LAST
            LIMIT 1
        ];
        return steps.isEmpty() ? null : steps[0].Comments__c;
    }

    private static void notifyOwner(Leave_Request__c r, String title, String body) {
        Set<String> recipients = new Set<String>();
        if (r.Employee__r != null && r.Employee__r.User__c != null) {
            recipients.add(String.valueOf(r.Employee__r.User__c));
        }
        if (r.Requested_By__c != null) {
            recipients.add(String.valueOf(r.Requested_By__c));
        }
        HrNotificationService.notify(recipients, r.Id, title, body, TYPE_DECIDED);
    }
}
