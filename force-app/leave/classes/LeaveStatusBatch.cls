/**
 * Lote diario do ciclo de vida das ferias aprovadas: Aprovado com inicio hoje (ou antes) vira Em_Gozo e o
 * colaborador vira Ferias; Em_Gozo com fim anterior a hoje vira Concluido e o colaborador volta a Ativo, se estava
 * em Ferias. Ferias que ja terminaram sem o lote ter rodado vao direto para Concluido.
 *
 * Contexto de sistema (spec 02): atualiza o status de pedidos e colaboradores de todos, sem depender de quem agenda.
 */
// Contexto de sistema do lote diario (spec 02); status e campo somente leitura para os usuarios.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class LeaveStatusBatch implements Database.Batchable<SObject> {
    private Date runDate;

    public LeaveStatusBatch() {
        this(Date.today());
    }

    public LeaveStatusBatch(Date runDate) {
        this.runDate = runDate;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date cutoff = runDate;
        return Database.getQueryLocator(
            [
                SELECT Id, Status__c, Start_Date__c, End_Date__c, Employee__c
                FROM Leave_Request__c
                WHERE
                    (Status__c = 'Aprovado' AND Start_Date__c <= :cutoff)
                    OR (Status__c = 'Em_Gozo' AND End_Date__c < :cutoff)
                ORDER BY Start_Date__c
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        process((List<Leave_Request__c>) scope, runDate);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'LeaveStatusBatch concluido para ' + runDate);
    }

    /** Aplica as transicoes do dia. Publico para os testes e para execucao manual. */
    public static void process(List<Leave_Request__c> requests, Date runDate) {
        List<Leave_Request__c> requestUpdates = new List<Leave_Request__c>();
        Set<Id> startingEmployees = new Set<Id>();
        Set<Id> returningEmployees = new Set<Id>();
        for (Leave_Request__c r : requests) {
            if (r.Status__c == 'Aprovado' && r.Start_Date__c <= runDate) {
                if (r.End_Date__c < runDate) {
                    requestUpdates.add(new Leave_Request__c(Id = r.Id, Status__c = 'Concluido'));
                } else {
                    requestUpdates.add(new Leave_Request__c(Id = r.Id, Status__c = 'Em_Gozo'));
                    startingEmployees.add(r.Employee__c);
                }
            } else if (r.Status__c == 'Em_Gozo' && r.End_Date__c < runDate) {
                requestUpdates.add(new Leave_Request__c(Id = r.Id, Status__c = 'Concluido'));
                returningEmployees.add(r.Employee__c);
            }
        }
        returningEmployees.removeAll(startingEmployees);
        update requestUpdates;
        updateEmployees(startingEmployees, returningEmployees);
    }

    private static void updateEmployees(Set<Id> starting, Set<Id> returning) {
        Set<Id> all = new Set<Id>(starting);
        all.addAll(returning);
        all.remove(null);
        if (all.isEmpty()) {
            return;
        }
        List<Employee__c> changed = new List<Employee__c>();
        for (Employee__c e : [SELECT Id, Status__c FROM Employee__c WHERE Id IN :all]) {
            if (starting.contains(e.Id) && e.Status__c == 'Ativo') {
                changed.add(new Employee__c(Id = e.Id, Status__c = 'Ferias'));
            } else if (returning.contains(e.Id) && e.Status__c == 'Ferias') {
                changed.add(new Employee__c(Id = e.Id, Status__c = 'Ativo'));
            }
        }
        update changed;
    }
}
