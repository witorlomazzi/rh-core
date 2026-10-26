/**
 * Consultas de Promotion_Request__c.
 *
 * byIds e byIdsWithSalary rodam em USER_MODE: o compartilhamento e a FLS decidem o que volta. byIds nao seleciona
 * campos salariais (o gestor nao os le); byIdsWithSalary e para o RH e falha para quem nao tem acesso ao salario.
 *
 * Os metodos system* rodam em modo sistema e so podem ser chamados por PromotionService (contexto de sistema da
 * spec 02: snapshot, efetivacao e checagens de regra que precisam enxergar pedidos fora do alcance do usuario).
 */
public inherited sharing class PromotionRequestSelector {
    public static List<Promotion_Request__c> byIds(Set<Id> ids) {
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Current_Position__c, Current_Position__r.Name, Proposed_Position__c,
                Proposed_Position__r.Name, Justification__c, Effective_Date__c, Status__c, Current_Step__c, Requested_By__c,
                Requested_By__r.Name
            FROM Promotion_Request__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    /** Para o RH: inclui salario e a faixa do cargo proposto. Falha para quem nao tem FLS nesses campos. */
    public static List<Promotion_Request__c> byIdsWithSalary(Set<Id> ids) {
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Current_Position__c, Current_Position__r.Name, Proposed_Position__c,
                Proposed_Position__r.Name, Justification__c, Effective_Date__c, Status__c, Current_Step__c, Requested_By__c,
                Requested_By__r.Name, Current_Salary__c, Proposed_Salary__c, Increase_Percent__c,
                Proposed_Position__r.Salary_Band__r.Name, Proposed_Position__r.Salary_Band__r.Min_Salary__c,
                Proposed_Position__r.Salary_Band__r.Max_Salary__c
            FROM Promotion_Request__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    // ------------------------------------------------------------------------------ modo sistema (PromotionService)

    /** Pedidos para efetivar, em ordem de data de efetivacao. */
    public static List<Promotion_Request__c> systemByIds(Set<Id> ids) {
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Proposed_Position__c, Proposed_Salary__c, Effective_Date__c,
                Status__c, Requested_By__c
            FROM Promotion_Request__c
            WHERE Id IN :ids
            WITH SYSTEM_MODE
            ORDER BY Effective_Date__c, CreatedDate
        ];
    }

    /** Pedidos aprovados cuja data de efetivacao ja chegou. */
    public static Database.QueryLocator dueForEffectivation(Date asOf) {
        return Database.getQueryLocator(
            [
                SELECT Id
                FROM Promotion_Request__c
                WHERE Status__c = 'Aprovado' AND Effective_Date__c <= :asOf
                WITH SYSTEM_MODE
                ORDER BY Effective_Date__c, CreatedDate
            ]
        );
    }

    /** Colaboradores que ja tem pedido Pendente, ignorando os pedidos informados (P4). */
    public static Set<Id> employeesWithPending(Set<Id> employeeIds, Set<Id> excludeRequestIds) {
        Set<Id> result = new Set<Id>();
        if (employeeIds.isEmpty()) {
            return result;
        }
        for (Promotion_Request__c r : [
            SELECT Employee__c
            FROM Promotion_Request__c
            WHERE Status__c = 'Pendente' AND Employee__c IN :employeeIds AND Id NOT IN :excludeRequestIds
            WITH SYSTEM_MODE
        ]) {
            result.add(r.Employee__c);
        }
        return result;
    }
}
