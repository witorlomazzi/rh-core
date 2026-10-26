/**
 * Recalculo de compartilhamento de subarvores grandes, em blocos encadeados de 200 colaboradores.
 * Contexto de sistema herdado de EmployeeSharingService (spec 02).
 */
// Contexto de sistema da spec 02 herdado de EmployeeSharingService.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class EmployeeSharingQueueable implements Queueable {
    private final List<Id> pending;

    public EmployeeSharingQueueable(List<Id> employeeIds) {
        this.pending = employeeIds;
    }

    public void execute(QueueableContext context) {
        List<Id> chunk = new List<Id>();
        List<Id> rest = new List<Id>();
        for (Integer i = 0; i < pending.size(); i++) {
            if (i < EmployeeSharingService.SYNC_SHARE_LIMIT) {
                chunk.add(pending[i]);
            } else {
                rest.add(pending[i]);
            }
        }
        EmployeeSharingService.recalculateShares(
            [SELECT Id, OwnerId, User__c, Hierarchy_Path__c FROM Employee__c WHERE Id IN :chunk]
        );
        if (!rest.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new EmployeeSharingQueueable(rest));
        }
    }
}
