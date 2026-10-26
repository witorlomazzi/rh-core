/**
 * Regras de Employee__c: usuario unico, hierarquia sem ciclo e manutencao de hierarquia e compartilhamento.
 *
 * As consultas daqui rodam em modo sistema: em contexto de trigger, WITH USER_MODE com bind dispara erro de
 * plataforma (tmpVar1) e a validacao precisa enxergar colaboradores fora do alcance do usuario.
 */
public with sharing class EmployeeTriggerHandler extends TriggerHandler {
    public static final String CYCLE_MESSAGE = 'O gestor escolhido está abaixo deste colaborador na hierarquia.';
    public static final String DUPLICATE_USER_MESSAGE = 'Este usuário já está vinculado a outro colaborador.';

    private List<Employee__c> newList;
    private Map<Id, Employee__c> oldMap;

    public EmployeeTriggerHandler() {
        this.newList = (List<Employee__c>) Trigger.new;
        this.oldMap = (Map<Id, Employee__c>) Trigger.oldMap;
    }

    @TestVisible
    private EmployeeTriggerHandler(List<Employee__c> newList, Map<Id, Employee__c> oldMap) {
        this.newList = newList;
        this.oldMap = oldMap;
    }

    protected override void beforeInsert() {
        validateUniqueUser(newList);
    }

    protected override void beforeUpdate() {
        List<Employee__c> userChanged = new List<Employee__c>();
        List<Employee__c> managerChanged = new List<Employee__c>();
        for (Employee__c e : newList) {
            Employee__c old = oldMap.get(e.Id);
            if (e.User__c != old.User__c) {
                userChanged.add(e);
            }
            if (e.Manager__c != old.Manager__c) {
                managerChanged.add(e);
            }
        }
        validateUniqueUser(userChanged);
        validateNoCycle(managerChanged);
    }

    protected override void afterInsert() {
        Set<Id> roots = new Map<Id, Employee__c>(newList).keySet();
        Set<Id> managers = new Set<Id>();
        for (Employee__c e : newList) {
            managers.add(e.Manager__c);
        }
        apply(roots, managers);
    }

    protected override void afterUpdate() {
        Set<Id> roots = new Set<Id>();
        Set<Id> managers = new Set<Id>();
        for (Employee__c e : newList) {
            Employee__c old = oldMap.get(e.Id);
            if (e.Manager__c != old.Manager__c) {
                roots.add(e.Id);
                managers.add(e.Manager__c);
                managers.add(old.Manager__c);
            } else if (e.User__c != old.User__c) {
                roots.add(e.Id);
            }
        }
        apply(roots, managers);
    }

    protected override void afterDelete() {
        Set<Id> deleted = oldMap.keySet();
        Set<Id> managers = new Set<Id>();
        for (Employee__c e : oldMap.values()) {
            if (!deleted.contains(e.Manager__c)) {
                managers.add(e.Manager__c);
            }
        }
        EmployeeSharingService.updateDirectReportCounts(managers);
        EmployeeSharingService.recalculate(EmployeeSharingService.descendantsOf(deleted));
    }

    private void apply(Set<Id> roots, Set<Id> managers) {
        try {
            EmployeeSharingService.recalculate(roots);
            EmployeeSharingService.updateDirectReportCounts(managers);
        } catch (EmployeeSharingService.HierarchyException ex) {
            for (Employee__c e : newList) {
                e.addError(ex.getMessage());
            }
        }
    }

    private void validateUniqueUser(List<Employee__c> records) {
        Map<Id, Employee__c> byUser = new Map<Id, Employee__c>();
        for (Employee__c e : records) {
            if (e.User__c == null) {
                continue;
            }
            if (byUser.containsKey(e.User__c)) {
                e.User__c.addError(DUPLICATE_USER_MESSAGE);
            } else {
                byUser.put(e.User__c, e);
            }
        }
        if (byUser.isEmpty()) {
            return;
        }
        for (Employee__c existing : [SELECT Id, User__c FROM Employee__c WHERE User__c IN :byUser.keySet()]) {
            Employee__c candidate = byUser.get(existing.User__c);
            if (candidate != null && candidate.Id != existing.Id) {
                candidate.User__c.addError(DUPLICATE_USER_MESSAGE);
            }
        }
    }

    /**
     * Sobe a cadeia a partir do novo gestor usando os valores do proprio lote quando o gestor tambem esta sendo
     * alterado, e o caminho gravado quando nao esta. Encontrar o proprio colaborador significa ciclo.
     */
    private void validateNoCycle(List<Employee__c> records) {
        if (records.isEmpty()) {
            return;
        }
        Map<Id, Employee__c> inBatch = new Map<Id, Employee__c>(newList);
        Set<Id> outside = new Set<Id>();
        for (Employee__c e : records) {
            if (e.Manager__c != null && !inBatch.containsKey(e.Manager__c)) {
                outside.add(e.Manager__c);
            }
        }
        for (Employee__c e : newList) {
            if (e.Manager__c != null && !inBatch.containsKey(e.Manager__c)) {
                outside.add(e.Manager__c);
            }
        }
        Map<Id, Employee__c> outsideMap = new Map<Id, Employee__c>(
            [SELECT Id, Manager__c, Hierarchy_Path__c FROM Employee__c WHERE Id IN :outside]
        );
        for (Employee__c e : records) {
            if (e.Manager__c == null) {
                continue;
            }
            if (e.Manager__c == e.Id || reachesSelf(e.Id, e.Manager__c, inBatch, outsideMap)) {
                e.Manager__c.addError(CYCLE_MESSAGE);
            }
        }
    }

    private Boolean reachesSelf(Id selfId, Id startManager, Map<Id, Employee__c> inBatch, Map<Id, Employee__c> outsideMap) {
        Id current = startManager;
        Set<Id> seen = new Set<Id>();
        while (current != null && !seen.contains(current)) {
            if (current == selfId) {
                return true;
            }
            seen.add(current);
            if (inBatch.containsKey(current)) {
                current = inBatch.get(current).Manager__c;
            } else {
                Employee__c outsideManager = outsideMap.get(current);
                if (outsideManager == null) {
                    return false;
                }
                return new Set<Id>(EmployeeSharingService.pathIds(outsideManager.Hierarchy_Path__c)).contains(selfId);
            }
        }
        return current != null && current == selfId;
    }
}
