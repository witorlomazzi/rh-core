/**
 * Recalculo de compartilhamento de candidaturas e candidatos. Serve de classe de recalculo de sharing do objeto
 * (botao Recalcular em Configuracao), de execucao manual para todas as vagas (new RecruitingSharingRecalcBatch())
 * e de destino quando a troca de gestor contratante afeta muitas candidaturas.
 * Contexto de sistema (spec 02).
 */
// Contexto de sistema da spec 02: recalculo de compartilhamento de candidaturas.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class RecruitingSharingRecalcBatch implements Database.Batchable<SObject> {
    private Set<Id> openingIds;

    /** Recalcula todas as candidaturas. */
    public RecruitingSharingRecalcBatch() {
    }

    /** Recalcula as candidaturas das vagas informadas. */
    public RecruitingSharingRecalcBatch(Set<Id> openingIds) {
        this.openingIds = openingIds;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        if (openingIds == null) {
            return Database.getQueryLocator([SELECT Id, Candidate__c, Job_Opening__c, OwnerId FROM Job_Application__c]);
        }
        return Database.getQueryLocator(
            [SELECT Id, Candidate__c, Job_Opening__c, OwnerId FROM Job_Application__c WHERE Job_Opening__c IN :openingIds]
        );
    }

    public void execute(Database.BatchableContext context, List<Job_Application__c> scope) {
        RecruitingSharingService.recalculate(scope);
    }

    public void finish(Database.BatchableContext context) {
        System.debug(LoggingLevel.INFO, 'Recalculo de compartilhamento de recrutamento concluido.');
    }
}
