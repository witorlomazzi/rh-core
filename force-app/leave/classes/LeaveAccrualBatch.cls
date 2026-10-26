/**
 * Lote diario de periodos aquisitivos: percorre os colaboradores CLT nao desligados e chama o LeaveAccrualService
 * para gerar os periodos que faltam e atualizar direito e status dos existentes (idempotente).
 *
 * Contexto de sistema (spec 02): roda para todos os colaboradores, independentemente de quem agenda o lote.
 */
// Contexto de sistema do lote diario (spec 02).
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class LeaveAccrualBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Date runDate;
    public Integer created = 0;
    public Integer updated = 0;
    public Integer errors = 0;

    public LeaveAccrualBatch() {
        this(Date.today());
    }

    public LeaveAccrualBatch(Date runDate) {
        this.runDate = runDate;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date cutoff = runDate;
        return Database.getQueryLocator(
            [
                SELECT Id, Employee_Number__c, Hire_Date__c, Status__c, Employment_Type__c
                FROM Employee__c
                WHERE
                    Employment_Type__c = 'CLT'
                    AND Status__c != 'Desligado'
                    AND Hire_Date__c != NULL
                    AND Hire_Date__c <= :cutoff
                ORDER BY Hire_Date__c
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        LeaveAccrualService.Summary s = LeaveAccrualService.generate((List<Employee__c>) scope, runDate);
        created += s.created;
        updated += s.updated;
        errors += s.errors;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'LeaveAccrualBatch: ' + created + ' criados, ' + updated + ' atualizados, ' + errors + ' erros.'
        );
    }
}
