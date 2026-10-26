/**
 * Compartilhamento de Promotion_Request__c (spec 02): o dono e quem solicitou. Leitura (motivo Approver_Chain__c)
 * para o aprovador da primeira etapa, o gestor de segundo nivel do colaborador, e para o grupo de RH. O colaborador
 * nao recebe acesso a solicitacao; depois de efetivada ele ve so o Position_History__c.
 *
 * O aprovador e resolvido com a mesma regra de EmployeeHierarchyService.secondLevelManagerUserId (gestor de segundo
 * nivel; sem ele, o gestor direto), mas em lote, a partir do Hierarchy_Path__c.
 *
 * Contexto de sistema (spec 02): criar e remover shares de pedidos que o solicitante nao pode compartilhar
 * (o gestor nao tem Modify All) e ler a cadeia de gestores de colaboradores fora do alcance do usuario.
 */
// Contexto de sistema da spec 02: shares Apex Managed Sharing e leitura da cadeia de gestores.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class PromotionSharingService {
    public static final String REASON = Schema.Promotion_Request__Share.RowCause.Approver_Chain__c;

    /** Recalcula os shares de motivo Approver_Chain__c dos pedidos: cria os que faltam e remove os que sobram. */
    public static void recalculate(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) {
            return;
        }
        List<Promotion_Request__c> requests = [
            SELECT Id, OwnerId, Employee__c
            FROM Promotion_Request__c
            WHERE Id IN :requestIds
            WITH SYSTEM_MODE
        ];
        Set<Id> employeeIds = new Set<Id>();
        for (Promotion_Request__c r : requests) {
            employeeIds.add(r.Employee__c);
        }
        Map<Id, Employee__c> employees = new Map<Id, Employee__c>(
            [
                SELECT Id, Hierarchy_Path__c
                FROM Employee__c
                WHERE Id IN :employeeIds
                WITH SYSTEM_MODE
            ]
        );
        Set<Id> chainIds = new Set<Id>();
        for (Employee__c e : employees.values()) {
            chainIds.addAll(EmployeeSharingService.pathIds(e.Hierarchy_Path__c));
        }
        Map<Id, Id> userByEmployee = new Map<Id, Id>();
        for (Employee__c m : [
            SELECT Id, User__c
            FROM Employee__c
            WHERE Id IN :chainIds AND User__c != NULL
            WITH SYSTEM_MODE
        ]) {
            userByEmployee.put(m.Id, m.User__c);
        }
        Id hrGroupId = hrGroupId();

        Map<String, Promotion_Request__Share> desired = new Map<String, Promotion_Request__Share>();
        for (Promotion_Request__c r : requests) {
            Employee__c emp = employees.get(r.Employee__c);
            if (emp == null) {
                continue;
            }
            Id approver = approverUserId(EmployeeSharingService.pathIds(emp.Hierarchy_Path__c), userByEmployee);
            if (approver != null && approver != r.OwnerId) {
                desired.put(key(r.Id, approver), newShare(r.Id, approver));
            }
            if (hrGroupId != null) {
                desired.put(key(r.Id, hrGroupId), newShare(r.Id, hrGroupId));
            }
        }

        List<Promotion_Request__Share> toDelete = new List<Promotion_Request__Share>();
        for (Promotion_Request__Share s : [
            SELECT Id, ParentId, UserOrGroupId
            FROM Promotion_Request__Share
            WHERE ParentId IN :requestIds AND RowCause = :REASON
        ]) {
            String k = key(s.ParentId, s.UserOrGroupId);
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
            // allOrNone false: usuario inativo nao recebe share e nao deve derrubar a solicitacao.
            for (Database.SaveResult r : Database.insert(desired.values(), false)) {
                if (!r.isSuccess()) {
                    System.debug(LoggingLevel.WARN, 'Share de promocao nao criado: ' + r.getErrors());
                }
            }
        }
    }

    /**
     * Usuario do gestor de segundo nivel; sem segundo nivel (ou sem usuario nele), o do gestor direto.
     * managerPath vai da raiz ate o gestor direto, como em Employee__c.Hierarchy_Path__c.
     */
    @TestVisible
    private static Id approverUserId(List<Id> managerPath, Map<Id, Id> userByEmployee) {
        if (managerPath.isEmpty()) {
            return null;
        }
        Id direct = managerPath[managerPath.size() - 1];
        if (managerPath.size() >= 2) {
            Id second = userByEmployee.get(managerPath[managerPath.size() - 2]);
            if (second != null) {
                return second;
            }
        }
        return userByEmployee.get(direct);
    }

    private static Id hrGroupId() {
        String devName = HrSettings.get().HR_Group_Developer_Name__c;
        List<Group> groups = [SELECT Id FROM Group WHERE DeveloperName = :devName AND Type = 'Regular' LIMIT 1];
        return groups.isEmpty() ? null : groups[0].Id;
    }

    private static String key(Id parentId, Id userOrGroupId) {
        return String.valueOf(parentId) + '|' + String.valueOf(userOrGroupId);
    }

    private static Promotion_Request__Share newShare(Id parentId, Id userOrGroupId) {
        return new Promotion_Request__Share(ParentId = parentId, UserOrGroupId = userOrGroupId, AccessLevel = 'Read', RowCause = REASON);
    }
}
