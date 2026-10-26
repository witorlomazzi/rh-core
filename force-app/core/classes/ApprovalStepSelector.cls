/**
 * Consultas de Approval_Step__c. Visibilidade de registro pelo compartilhamento (with sharing): o aprovador enxerga
 * a etapa pelo share Approver__c, o solicitante por ser o dono, o RH pelo share do grupo HR_Team.
 * FLS por stripInaccessible em vez de USER_MODE: o campo de pesquisa para um objeto que o usuario nao le (ex.:
 * Promotion_Request__c para o colaborador) faria a consulta inteira falhar em USER_MODE.
 */
public with sharing class ApprovalStepSelector {
    public class NoAccessException extends Exception {
    }

    private static void assertReadable() {
        if (!Schema.SObjectType.Approval_Step__c.isAccessible()) {
            throw new NoAccessException('Sem acesso às etapas de aprovação.');
        }
    }

    public static List<Approval_Step__c> pendingForUser(Id userId, Boolean includeHrTeamSteps) {
        assertReadable();
        List<Approval_Step__c> rows;
        if (includeHrTeamSteps) {
            rows = [
                SELECT Id, Name, Request_Type__c, Leave_Request__c, Promotion_Request__c, Step_Order__c, Approver_Type__c,
                    Approver__c, Status__c, CreatedDate, CreatedById
                FROM Approval_Step__c
                WHERE Status__c = 'Pendente' AND (Approver__c = :userId OR Approver_Type__c = 'HR_Team')
                ORDER BY CreatedDate
            ];
        } else {
            rows = [
                SELECT Id, Name, Request_Type__c, Leave_Request__c, Promotion_Request__c, Step_Order__c, Approver_Type__c,
                    Approver__c, Status__c, CreatedDate, CreatedById
                FROM Approval_Step__c
                WHERE Status__c = 'Pendente' AND Approver__c = :userId
                ORDER BY CreatedDate
            ];
        }
        return (List<Approval_Step__c>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
    }

    /** Historico de etapas de uma solicitacao, em ordem. */
    public static List<Approval_Step__c> byRequest(Id requestId) {
        assertReadable();
        List<Approval_Step__c> rows = [
            SELECT Id, Name, Request_Type__c, Step_Order__c, Approver_Type__c, Approver__c, Approver__r.Name, Status__c,
                Decided_By__c, Decided_By__r.Name, Decision_Date__c, Comments__c, CreatedDate
            FROM Approval_Step__c
            WHERE Leave_Request__c = :requestId OR Promotion_Request__c = :requestId
            ORDER BY Step_Order__c, CreatedDate
        ];
        return (List<Approval_Step__c>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
    }

    /** Le um campo que pode ter sido removido por stripInaccessible. */
    public static Object valueOf(SObject record, String fieldName) {
        return record.isSet(fieldName) ? record.get(fieldName) : null;
    }
}
