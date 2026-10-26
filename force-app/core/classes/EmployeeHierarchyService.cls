/**
 * Consultas da estrutura de gestao (cadeia de gestores) usadas para rotear aprovacoes e validar permissoes.
 *
 * Contexto de sistema: o colaborador nao tem acesso de leitura ao registro do proprio gestor (o compartilhamento
 * e de cima para baixo), mas o motor de aprovacao precisa saber quem e o gestor. Esta classe le apenas campos
 * estruturais (Id, Manager__c, User__c, Hierarchy_Path__c) e nunca devolve dado pessoal ou salarial.
 * Registrado em PROGRESSO.md (Divergencias e decisoes).
 */
// Leitura de campos estruturais da cadeia de gestores em contexto de sistema (ver comentario da classe).
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class EmployeeHierarchyService {
    /** Ids dos colaboradores da cadeia, do gestor direto ate a raiz. */
    public static List<Id> managerChainEmployeeIds(Id employeeId) {
        Employee__c e = load(employeeId);
        List<Id> result = new List<Id>();
        if (e == null || String.isBlank(e.Hierarchy_Path__c)) {
            return result;
        }
        List<String> parts = e.Hierarchy_Path__c.split(';');
        for (Integer i = parts.size() - 1; i >= 0; i--) {
            result.add(Id.valueOf(parts[i]));
        }
        return result;
    }

    /** Usuarios da cadeia de gestores, do gestor direto para cima. Gestores sem usuario sao ignorados. */
    public static List<Id> managerChainUserIds(Employee__c employee) {
        List<Id> chain = managerChainEmployeeIds(employee.Id);
        Map<Id, Id> userByEmployee = new Map<Id, Id>();
        for (Employee__c m : [SELECT Id, User__c FROM Employee__c WHERE Id IN :chain]) {
            userByEmployee.put(m.Id, m.User__c);
        }
        List<Id> result = new List<Id>();
        for (Id managerId : chain) {
            Id userId = userByEmployee.get(managerId);
            if (userId != null) {
                result.add(userId);
            }
        }
        return result;
    }

    /** Usuario do gestor direto, ou null. */
    public static Id directManagerUserId(Employee__c employee) {
        List<Id> chain = managerChainEmployeeIds(employee.Id);
        if (chain.isEmpty()) {
            return null;
        }
        return userOf(chain[0]);
    }

    /** Usuario do gestor do gestor; se nao houver segundo nivel, o gestor direto. */
    public static Id secondLevelManagerUserId(Employee__c employee) {
        List<Id> chain = managerChainEmployeeIds(employee.Id);
        if (chain.isEmpty()) {
            return null;
        }
        if (chain.size() >= 2) {
            Id second = userOf(chain[1]);
            if (second != null) {
                return second;
            }
        }
        return userOf(chain[0]);
    }

    /** Verdadeiro se managerEmployeeId esta acima de employeeId na hierarquia (qualquer nivel). */
    public static Boolean isInChainOf(Id managerEmployeeId, Id employeeId) {
        if (managerEmployeeId == null || employeeId == null || managerEmployeeId == employeeId) {
            return false;
        }
        return new Set<Id>(managerChainEmployeeIds(employeeId)).contains(managerEmployeeId);
    }

    private static Id userOf(Id employeeId) {
        List<Employee__c> rows = [SELECT User__c FROM Employee__c WHERE Id = :employeeId LIMIT 1];
        return rows.isEmpty() ? null : rows[0].User__c;
    }

    private static Employee__c load(Id employeeId) {
        if (employeeId == null) {
            return null;
        }
        List<Employee__c> rows = [
            SELECT Id, Manager__c, User__c, Hierarchy_Path__c
            FROM Employee__c
            WHERE Id = :employeeId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }
}
