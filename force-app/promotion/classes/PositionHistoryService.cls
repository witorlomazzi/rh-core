/**
 * Historico de cargo do colaborador.
 *
 * - createAdmission: cria o registro inicial (Change_Reason__c = Admissao). Chamado pelo seed (spec 18) e pela
 *   admissao (spec 15). Idempotente: ignora colaborador que ja tem historico.
 * - registerChanges: fecha o historico aberto e abre o novo (usado pela efetivacao de promocao).
 * - timeline: leitura em USER_MODE; salario so vem para quem tem acesso ao campo.
 *
 * Contexto de sistema (spec 02): criar e fechar historico exige gravar Salary__c, que o gestor e o colaborador nao
 * leem, e historicos de colaboradores que o usuario que disparou a acao pode nao enxergar (ex.: seed, admissao).
 * Todas as escritas ficam na classe interna Privileged e o chamador valida a regra de negocio antes.
 */
// Escritas de historico em contexto de sistema (spec 02) e leitura de Employee__c para o registro inicial.
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class PositionHistoryService {
    public static final String REASON_ADMISSION = 'Admissao';
    public static final String REASON_PROMOTION = 'Promocao';

    private static final Map<String, String> REASON_LABELS = new Map<String, String>{
        'Admissao' => 'Admissão',
        'Promocao' => 'Promoção',
        'Merito' => 'Mérito',
        'Transferencia' => 'Transferência'
    };

    /** Uma mudanca de cargo a registrar. */
    public class Change {
        public Id employeeId;
        public Id positionId;
        public Id departmentId;
        public Decimal salary;
        public Date startDate;
        public String reason;
        public Id promotionRequestId;

        public Change(Id employeeId, Id positionId, Id departmentId, Decimal salary, Date startDate, String reason, Id promotionRequestId) {
            this.employeeId = employeeId;
            this.positionId = positionId;
            this.departmentId = departmentId;
            this.salary = salary;
            this.startDate = startDate;
            this.reason = reason;
            this.promotionRequestId = promotionRequestId;
        }
    }

    public class HistoryEntry {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public String departmentName;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public String reason;
        @AuraEnabled
        public String reasonLabel;
        @AuraEnabled
        public Decimal salary;
        @AuraEnabled
        public Boolean isCurrent;
    }

    public class HistoryResult {
        @AuraEnabled
        public Boolean salaryVisible;
        @AuraEnabled
        public List<HistoryEntry> entries = new List<HistoryEntry>();
    }

    /** Cria o historico de admissao dos colaboradores que ainda nao tem historico. Devolve quantos criou. */
    public static Integer createAdmission(Set<Id> employeeIds) {
        if (employeeIds == null || employeeIds.isEmpty()) {
            return 0;
        }
        return new Privileged().createAdmission(employeeIds);
    }

    /**
     * Fecha o historico aberto de cada colaborador (End_Date__c = data da mudanca - 1) e abre o novo. Cada
     * colaborador deve aparecer no maximo uma vez na lista; repeticoes sao ignoradas.
     */
    public static void registerChanges(List<Change> changes) {
        if (changes == null || changes.isEmpty()) {
            return;
        }
        new Privileged().registerChanges(changes);
    }

    /** Linha do tempo do colaborador visivel ao usuario atual. */
    public static HistoryResult timeline(Id employeeId) {
        HistoryResult result = new HistoryResult();
        result.salaryVisible = PositionHistorySelector.salaryVisible();
        for (Position_History__c h : PositionHistorySelector.byEmployee(employeeId)) {
            HistoryEntry e = new HistoryEntry();
            e.id = h.Id;
            e.positionName = h.Position__r == null ? null : h.Position__r.Name;
            e.departmentName = h.Department__r == null ? null : h.Department__r.Name;
            e.startDate = h.Start_Date__c;
            e.endDate = h.End_Date__c;
            e.reason = h.Change_Reason__c;
            e.reasonLabel = REASON_LABELS.containsKey(h.Change_Reason__c) ? REASON_LABELS.get(h.Change_Reason__c) : h.Change_Reason__c;
            e.isCurrent = h.End_Date__c == null;
            e.salary = result.salaryVisible && h.isSet('Salary__c') ? h.Salary__c : null;
            result.entries.add(e);
        }
        return result;
    }

    private without sharing class Privileged {
        Integer createAdmission(Set<Id> employeeIds) {
            Set<Id> withHistory = PositionHistorySelector.systemEmployeesWithHistory(employeeIds);
            List<Position_History__c> toInsert = new List<Position_History__c>();
            for (Employee__c e : [
                SELECT Id, Position__c, Department__c, Salary__c, Hire_Date__c
                FROM Employee__c
                WHERE Id IN :employeeIds
                WITH SYSTEM_MODE
            ]) {
                if (withHistory.contains(e.Id) || e.Position__c == null || e.Hire_Date__c == null) {
                    continue;
                }
                toInsert.add(
                    new Position_History__c(
                        Employee__c = e.Id,
                        Position__c = e.Position__c,
                        Department__c = e.Department__c,
                        Salary__c = e.Salary__c,
                        Start_Date__c = e.Hire_Date__c,
                        Change_Reason__c = REASON_ADMISSION
                    )
                );
            }
            insert toInsert;
            return toInsert.size();
        }

        void registerChanges(List<Change> changes) {
            Set<Id> employeeIds = new Set<Id>();
            for (Change c : changes) {
                employeeIds.add(c.employeeId);
            }
            Map<Id, Position_History__c> openByEmployee = new Map<Id, Position_History__c>();
            for (Position_History__c h : PositionHistorySelector.systemOpenByEmployees(employeeIds)) {
                openByEmployee.put(h.Employee__c, h);
            }
            List<Position_History__c> toClose = new List<Position_History__c>();
            List<Position_History__c> toOpen = new List<Position_History__c>();
            Set<Id> handled = new Set<Id>();
            for (Change c : changes) {
                if (!handled.add(c.employeeId)) {
                    continue;
                }
                Position_History__c open = openByEmployee.get(c.employeeId);
                if (open != null) {
                    // Nunca fecha antes do inicio do proprio registro (mudanca no mesmo dia da admissao).
                    Date endDate = c.startDate.addDays(-1);
                    if (open.Start_Date__c != null && endDate < open.Start_Date__c) {
                        endDate = open.Start_Date__c;
                    }
                    toClose.add(new Position_History__c(Id = open.Id, End_Date__c = endDate));
                }
                toOpen.add(
                    new Position_History__c(
                        Employee__c = c.employeeId,
                        Position__c = c.positionId,
                        Department__c = c.departmentId,
                        Salary__c = c.salary,
                        Start_Date__c = c.startDate,
                        Change_Reason__c = c.reason,
                        Promotion_Request__c = c.promotionRequestId
                    )
                );
            }
            update toClose;
            insert toOpen;
        }
    }
}
