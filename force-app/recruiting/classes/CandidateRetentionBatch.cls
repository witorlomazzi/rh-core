/**
 * LGPD (C11): anonimiza candidatos sem candidatura ativa cuja ultima atividade e mais antiga que
 * HR_Setting__mdt.Candidate_Retention_Days__c. Candidato com candidatura em andamento ou contratada nunca e
 * anonimizado. Roda semanalmente (Schedulable) ou sob demanda: Database.executeBatch(new CandidateRetentionBatch()).
 *
 * Contexto de sistema (spec 02): anonimizar candidatos vencidos, que nenhum usuario operacional possui.
 */
// Contexto de sistema da spec 02: anonimizacao de candidatos vencidos (LGPD).
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class CandidateRetentionBatch implements Database.Batchable<SObject>, Schedulable {
    /** Todo domingo as 03:00. */
    public static final String WEEKLY_CRON = '0 0 3 ? * SUN';
    public static final String JOB_NAME = 'Retencao de candidatos (LGPD)';

    /** Agenda a execucao semanal. Devolve o Id do job agendado. */
    public static Id schedule() {
        return System.schedule(JOB_NAME, WEEKLY_CRON, new CandidateRetentionBatch());
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        Integer days = retentionDays();
        Date cutoff = Date.today().addDays(-days);
        Datetime cutoffTime = Datetime.now().addDays(-days);
        Set<String> protectedStages = RecruitingStageConfig.retentionProtectedStages();
        return Database.getQueryLocator(
            [
                SELECT Id
                FROM Candidate__c
                WHERE
                    Anonymized__c = FALSE
                    AND (Last_Activity_Date__c < :cutoff
                    OR (Last_Activity_Date__c = NULL AND CreatedDate < :cutoffTime))
                    AND Id NOT IN (SELECT Candidate__c FROM Job_Application__c WHERE Stage__c IN :protectedStages)
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<Candidate__c> scope) {
        Set<Id> ids = new Map<Id, Candidate__c>(scope).keySet();
        // anonymize repete a checagem de candidatura ativa: entre o start e o execute pode ter entrado uma nova.
        Integer done = CandidateService.anonymize(ids);
        System.debug(LoggingLevel.INFO, 'Candidatos anonimizados no lote: ' + done);
    }

    public void finish(Database.BatchableContext context) {
        System.debug(LoggingLevel.INFO, 'Retencao de candidatos concluida.');
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new CandidateRetentionBatch(), 200);
    }

    private static Integer retentionDays() {
        Decimal configured = HrSettings.get().Candidate_Retention_Days__c;
        return configured == null ? 180 : configured.intValue();
    }
}
