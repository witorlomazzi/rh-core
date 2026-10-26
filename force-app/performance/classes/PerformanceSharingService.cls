/**
 * Compartilhamento de Performance_Review__c (spec 02):
 *  - o avaliador (Reviewer__c) recebe Edit enquanto a avaliacao esta Pendente ou Em_Andamento e Read depois;
 *  - o restante da cadeia de gestores do colaborador recebe Read (motivo Manager_Chain__c);
 *  - o proprio colaborador recebe Read somente depois de Status__c = Liberada (motivo Employee_Release__c).
 *
 * Contexto de sistema (spec 02): criar e remover shares de avaliacoes que o usuario que disparou a mudanca nao
 * possui. Bulkificado: a cadeia e resolvida com duas consultas para qualquer numero de avaliacoes.
 */
// Contexto de sistema da spec 02: shares mantidos por Apex.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class PerformanceSharingService {
    public static final String CHAIN_REASON = Schema.Performance_Review__Share.RowCause.Manager_Chain__c;
    public static final String RELEASE_REASON = Schema.Performance_Review__Share.RowCause.Employee_Release__c;

    /** Recalcula os shares gerenciados das avaliacoes informadas (precisam ter OwnerId, Employee__c, Reviewer__c e Status__c). */
    public static void sync(List<Performance_Review__c> reviews) {
        if (reviews == null || reviews.isEmpty()) {
            return;
        }
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> reviewIds = new Set<Id>();
        for (Performance_Review__c r : reviews) {
            employeeIds.add(r.Employee__c);
            reviewIds.add(r.Id);
        }
        employeeIds.remove(null);
        Map<Id, Employee__c> employees = new Map<Id, Employee__c>(
            [SELECT Id, User__c, Hierarchy_Path__c FROM Employee__c WHERE Id IN :employeeIds]
        );
        Set<Id> chainEmployeeIds = new Set<Id>();
        for (Employee__c e : employees.values()) {
            chainEmployeeIds.addAll(EmployeeSharingService.pathIds(e.Hierarchy_Path__c));
        }
        Map<Id, Id> userByEmployee = new Map<Id, Id>();
        for (Employee__c m : [SELECT Id, User__c FROM Employee__c WHERE Id IN :chainEmployeeIds AND User__c != NULL]) {
            userByEmployee.put(m.Id, m.User__c);
        }
        Map<Id, Id> ownerByReview = new Map<Id, Id>();
        for (Performance_Review__c r : [SELECT Id, OwnerId FROM Performance_Review__c WHERE Id IN :reviewIds]) {
            ownerByReview.put(r.Id, r.OwnerId);
        }

        Map<String, Performance_Review__Share> desired = new Map<String, Performance_Review__Share>();
        for (Performance_Review__c r : reviews) {
            Id owner = ownerByReview.get(r.Id);
            Employee__c employee = employees.get(r.Employee__c);
            Boolean editable = r.Status__c == 'Pendente' || r.Status__c == 'Em_Andamento';
            if (r.Reviewer__c != null && r.Reviewer__c != owner) {
                put(desired, r.Id, r.Reviewer__c, CHAIN_REASON, editable ? 'Edit' : 'Read');
            }
            if (employee != null) {
                for (Id managerEmployeeId : EmployeeSharingService.pathIds(employee.Hierarchy_Path__c)) {
                    Id userId = userByEmployee.get(managerEmployeeId);
                    if (userId != null && userId != owner && userId != employee.User__c && userId != r.Reviewer__c) {
                        put(desired, r.Id, userId, CHAIN_REASON, 'Read');
                    }
                }
                if (r.Status__c == 'Liberada' && employee.User__c != null && employee.User__c != owner) {
                    put(desired, r.Id, employee.User__c, RELEASE_REASON, 'Read');
                }
            }
        }

        List<Performance_Review__Share> toDelete = new List<Performance_Review__Share>();
        for (Performance_Review__Share s : [
            SELECT Id, ParentId, UserOrGroupId, RowCause, AccessLevel
            FROM Performance_Review__Share
            WHERE ParentId IN :reviewIds AND RowCause IN (:CHAIN_REASON, :RELEASE_REASON)
        ]) {
            String k = key(s.ParentId, s.UserOrGroupId, s.RowCause);
            Performance_Review__Share wanted = desired.get(k);
            if (wanted != null && wanted.AccessLevel == s.AccessLevel) {
                desired.remove(k);
            } else {
                toDelete.add(s);
            }
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        if (!desired.isEmpty()) {
            // allOrNone false: usuario inativo nao recebe share e nao deve derrubar a transacao.
            for (Database.SaveResult r : Database.insert(desired.values(), false)) {
                if (!r.isSuccess()) {
                    System.debug(LoggingLevel.WARN, 'Share de avaliacao nao criado: ' + r.getErrors());
                }
            }
        }
    }

    private static void put(Map<String, Performance_Review__Share> desired, Id parentId, Id userId, String reason, String access) {
        String k = key(parentId, userId, reason);
        if (!desired.containsKey(k)) {
            desired.put(k, new Performance_Review__Share(ParentId = parentId, UserOrGroupId = userId, RowCause = reason, AccessLevel = access));
        }
    }

    private static String key(Id parentId, Id userId, String reason) {
        return String.valueOf(parentId) + '|' + String.valueOf(userId) + '|' + reason;
    }
}
