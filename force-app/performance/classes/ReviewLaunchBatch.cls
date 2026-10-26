/**
 * Lancamento do ciclo em lotes de 200 colaboradores, usado por ReviewCycleService.launch quando ha mais de 200
 * colaboradores elegiveis. Idempotente (Unique_Key__c): reexecutar nao duplica. O ciclo so muda para
 * Autoavaliacao no fim, se nenhum lote teve erro.
 *
 * Contexto de sistema (spec 02, ReviewCycleService.launch). O papel de RH ja foi checado em launch().
 */
// Contexto de sistema da spec 02: criacao de avaliacoes para todos os colaboradores ativos.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ReviewLaunchBatch implements Database.Batchable<SObject>, Database.Stateful {
    private final Id cycleId;
    private Integer errors = 0;
    private Integer created = 0;

    public ReviewLaunchBatch(Id cycleId) {
        this.cycleId = cycleId;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return ReviewCycleService.eligibleLocator();
    }

    public void execute(Database.BatchableContext context, List<Employee__c> scope) {
        Review_Cycle__c cycle = ReviewCycleService.loadCycle(cycleId);
        ReviewCycleService.LaunchResult result = new ReviewCycleService.LaunchResult();
        ReviewCycleService.createRecords(cycle, scope, result);
        errors += result.errors;
        created += result.reviewsCreated;
    }

    public void finish(Database.BatchableContext context) {
        if (errors == 0) {
            ReviewCycleService.completeLaunch(cycleId);
        } else {
            System.debug(LoggingLevel.WARN, 'Lancamento do ciclo ' + cycleId + ' com ' + errors + ' erro(s); o ciclo segue Planejado.');
        }
    }
}
