/**
 * Consultas de Job_Position__c para o formulario de promocao, em USER_MODE.
 *
 * Existe porque JobPositionSelector (core) seleciona Salary_Band__c, e em USER_MODE essa consulta falha ("No such
 * column") para quem nao le o objeto Salary_Band__c (todo gestor e colaborador). Registrado como pedido ao core em
 * docs/execucao/modulos/promotion.md; quando o core corrigir, estes metodos podem voltar a usar o selector dele.
 */
public inherited sharing class PromotionPositionSelector {
    public static List<Job_Position__c> byIds(Set<Id> ids) {
        return [
            SELECT Id, Name, Level__c, Next_Position__c, Next_Position__r.Name, Active__c
            FROM Job_Position__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    public static List<Job_Position__c> active() {
        return [
            SELECT Id, Name, Level__c, Next_Position__c, Next_Position__r.Name, Active__c
            FROM Job_Position__c
            WHERE Active__c = TRUE
            WITH USER_MODE
            ORDER BY Name
        ];
    }
}
