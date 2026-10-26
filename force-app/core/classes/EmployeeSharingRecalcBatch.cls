/**
 * Recalculo completo do compartilhamento de Employee__c. Registrado como classe de recalculo de sharing do objeto
 * (botao Recalcular em Configuracao) e executavel manualmente: Database.executeBatch(new EmployeeSharingRecalcBatch()).
 * Contexto de sistema (spec 02).
 */
// Contexto de sistema da spec 02: recalculo de compartilhamento de todos os colaboradores.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class EmployeeSharingRecalcBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id, OwnerId, User__c, Hierarchy_Path__c FROM Employee__c]);
    }

    public void execute(Database.BatchableContext context, List<Employee__c> scope) {
        EmployeeSharingService.recalculateShares(scope);
    }

    public void finish(Database.BatchableContext context) {
        System.debug(LoggingLevel.INFO, 'Recalculo de compartilhamento de colaboradores concluido.');
    }
}
