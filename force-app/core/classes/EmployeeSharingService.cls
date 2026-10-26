/**
 * Mantem a hierarquia (Hierarchy_Path__c, Hierarchy_Depth__c, Direct_Reports_Count__c) e o compartilhamento de
 * Employee__c: leitura para o proprio usuario (Self__c) e para cada usuario da cadeia de gestores (Manager_Chain__c).
 *
 * Contexto de sistema (spec 02): criar e remover shares e atualizar campos de hierarquia de qualquer colaborador,
 * inclusive de subarvores que o usuario que disparou a mudanca nao enxerga.
 */
public without sharing class EmployeeSharingService {
    public static final String SELF_REASON = Schema.Employee__Share.RowCause.Self__c;
    public static final String CHAIN_REASON = Schema.Employee__Share.RowCause.Manager_Chain__c;
    public static final Integer MAX_PATH_LENGTH = 255;
    /** Acima disso o recalculo de compartilhamento vai para Queueable encadeado. */
    public static final Integer SYNC_SHARE_LIMIT = 200;

    public class HierarchyException extends Exception {
    }

    /**
     * Recalcula caminho, profundidade e compartilhamento dos colaboradores informados e de toda a subarvore deles.
     */
    public static void recalculate(Set<Id> rootIds) {
        if (rootIds == null || rootIds.isEmpty()) {
            return;
        }
        Map<Id, Employee__c> affected = loadWithSubtrees(rootIds);
        Map<Id, String> newPaths = computePaths(affected);

        List<Employee__c> toUpdate = new List<Employee__c>();
        for (Employee__c e : affected.values()) {
            String path = newPaths.get(e.Id);
            Integer depth = String.isBlank(path) ? 0 : path.split(';').size();
            if (path != null && path.length() > MAX_PATH_LENGTH) {
                throw new HierarchyException('A hierarquia excede a profundidade máxima suportada.');
            }
            if (e.Hierarchy_Path__c != path || e.Hierarchy_Depth__c != depth) {
                e.Hierarchy_Path__c = path;
                e.Hierarchy_Depth__c = depth;
                toUpdate.add(new Employee__c(Id = e.Id, Hierarchy_Path__c = path, Hierarchy_Depth__c = depth));
            }
        }
        if (!toUpdate.isEmpty()) {
            TriggerHandler.bypass('EmployeeTriggerHandler');
            try {
                update toUpdate;
            } finally {
                TriggerHandler.clearBypass('EmployeeTriggerHandler');
            }
        }

        if (affected.size() > SYNC_SHARE_LIMIT && !System.isQueueable() && !System.isBatch()) {
            System.enqueueJob(new EmployeeSharingQueueable(new List<Id>(affected.keySet())));
        } else {
            recalculateShares(affected.values());
        }
    }

    /**
     * Recalcula os shares Self__c e Manager_Chain__c a partir do caminho gravado. Usado pelo servico, pela fila
     * e pelo batch de recalculo.
     */
    public static void recalculateShares(List<Employee__c> employees) {
        if (employees == null || employees.isEmpty()) {
            return;
        }
        Set<Id> chainEmployeeIds = new Set<Id>();
        for (Employee__c e : employees) {
            chainEmployeeIds.addAll(pathIds(e.Hierarchy_Path__c));
        }
        Map<Id, Id> userByEmployee = new Map<Id, Id>();
        for (Employee__c m : [SELECT Id, User__c FROM Employee__c WHERE Id IN :chainEmployeeIds AND User__c != NULL]) {
            userByEmployee.put(m.Id, m.User__c);
        }

        Map<String, Employee__Share> desired = new Map<String, Employee__Share>();
        for (Employee__c e : employees) {
            if (e.User__c != null && e.User__c != e.OwnerId) {
                desired.put(key(e.Id, e.User__c, SELF_REASON), newShare(e.Id, e.User__c, SELF_REASON));
            }
            for (Id managerId : pathIds(e.Hierarchy_Path__c)) {
                Id userId = userByEmployee.get(managerId);
                if (userId != null && userId != e.OwnerId && userId != e.User__c) {
                    desired.put(key(e.Id, userId, CHAIN_REASON), newShare(e.Id, userId, CHAIN_REASON));
                }
            }
        }

        Map<Id, Employee__c> byId = new Map<Id, Employee__c>(employees);
        List<Employee__Share> toDelete = new List<Employee__Share>();
        for (Employee__Share s : [
            SELECT Id, ParentId, UserOrGroupId, RowCause
            FROM Employee__Share
            WHERE ParentId IN :byId.keySet() AND RowCause IN (:SELF_REASON, :CHAIN_REASON)
        ]) {
            String k = key(s.ParentId, s.UserOrGroupId, s.RowCause);
            if (desired.containsKey(k)) {
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
                    System.debug(LoggingLevel.WARN, 'Share de colaborador nao criado: ' + r.getErrors());
                }
            }
        }
    }

    /** Atualiza Direct_Reports_Count__c dos gestores informados. */
    public static void updateDirectReportCounts(Set<Id> managerIds) {
        managerIds.remove(null);
        if (managerIds.isEmpty()) {
            return;
        }
        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (Id m : managerIds) {
            counts.put(m, 0);
        }
        for (AggregateResult ar : [
            SELECT Manager__c mgr, COUNT(Id) total
            FROM Employee__c
            WHERE Manager__c IN :managerIds
            GROUP BY Manager__c
        ]) {
            counts.put((Id) ar.get('mgr'), (Integer) ar.get('total'));
        }
        List<Employee__c> toUpdate = new List<Employee__c>();
        for (Employee__c m : [SELECT Id, Direct_Reports_Count__c FROM Employee__c WHERE Id IN :managerIds]) {
            Integer c = counts.get(m.Id);
            if (m.Direct_Reports_Count__c != c) {
                toUpdate.add(new Employee__c(Id = m.Id, Direct_Reports_Count__c = c));
            }
        }
        if (!toUpdate.isEmpty()) {
            TriggerHandler.bypass('EmployeeTriggerHandler');
            try {
                update toUpdate;
            } finally {
                TriggerHandler.clearBypass('EmployeeTriggerHandler');
            }
        }
    }

    /** Colaboradores cuja cadeia contem algum dos Ids (usado na exclusao de um gestor). */
    public static Set<Id> descendantsOf(Set<Id> employeeIds) {
        Set<Id> result = new Set<Id>();
        List<String> patterns = likePatterns(employeeIds);
        if (patterns.isEmpty()) {
            return result;
        }
        for (Employee__c e : [SELECT Id FROM Employee__c WHERE Hierarchy_Path__c LIKE :patterns]) {
            result.add(e.Id);
        }
        return result;
    }

    // ---------------------------------------------------------------------------------------------------------

    private static Map<Id, Employee__c> loadWithSubtrees(Set<Id> rootIds) {
        List<String> patterns = likePatterns(rootIds);
        return new Map<Id, Employee__c>(
            [
                SELECT Id, OwnerId, Manager__c, User__c, Hierarchy_Path__c, Hierarchy_Depth__c
                FROM Employee__c
                WHERE Id IN :rootIds OR Hierarchy_Path__c LIKE :patterns
            ]
        );
    }

    /** Caminho de cada colaborador afetado, seguindo Manager__c dentro do conjunto e o caminho gravado fora dele. */
    private static Map<Id, String> computePaths(Map<Id, Employee__c> affected) {
        Set<Id> outsideManagers = new Set<Id>();
        for (Employee__c e : affected.values()) {
            if (e.Manager__c != null && !affected.containsKey(e.Manager__c)) {
                outsideManagers.add(e.Manager__c);
            }
        }
        Map<Id, String> outsidePaths = new Map<Id, String>();
        for (Employee__c m : [SELECT Id, Hierarchy_Path__c FROM Employee__c WHERE Id IN :outsideManagers]) {
            outsidePaths.put(m.Id, m.Hierarchy_Path__c);
        }
        Map<Id, String> memo = new Map<Id, String>();
        for (Id employeeId : affected.keySet()) {
            pathOf(employeeId, affected, outsidePaths, memo, new Set<Id>());
        }
        return memo;
    }

    private static String pathOf(
        Id employeeId,
        Map<Id, Employee__c> affected,
        Map<Id, String> outsidePaths,
        Map<Id, String> memo,
        Set<Id> visiting
    ) {
        if (memo.containsKey(employeeId)) {
            return memo.get(employeeId);
        }
        if (visiting.contains(employeeId)) {
            throw new HierarchyException(EmployeeTriggerHandler.CYCLE_MESSAGE);
        }
        visiting.add(employeeId);
        Id managerId = affected.get(employeeId).Manager__c;
        String path;
        if (managerId == null) {
            path = null;
        } else {
            String managerPath = affected.containsKey(managerId)
                ? pathOf(managerId, affected, outsidePaths, memo, visiting)
                : outsidePaths.get(managerId);
            path = String.isBlank(managerPath) ? String.valueOf(managerId) : managerPath + ';' + managerId;
        }
        memo.put(employeeId, path);
        return path;
    }

    private static List<String> likePatterns(Set<Id> ids) {
        List<String> patterns = new List<String>();
        for (Id i : ids) {
            if (i != null) {
                patterns.add('%' + String.valueOf(i) + '%');
            }
        }
        return patterns;
    }

    public static List<Id> pathIds(String path) {
        List<Id> result = new List<Id>();
        if (String.isBlank(path)) {
            return result;
        }
        for (String part : path.split(';')) {
            if (String.isNotBlank(part)) {
                result.add(Id.valueOf(part));
            }
        }
        return result;
    }

    private static String key(Id parentId, Id userId, String reason) {
        return String.valueOf(parentId) + '|' + String.valueOf(userId) + '|' + reason;
    }

    private static Employee__Share newShare(Id parentId, Id userId, String reason) {
        return new Employee__Share(ParentId = parentId, UserOrGroupId = userId, AccessLevel = 'Read', RowCause = reason);
    }
}
