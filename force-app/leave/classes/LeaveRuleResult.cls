/**
 * Resultado de uma regra de ferias avaliada pelo LeaveRuleEngine: codigo da regra (V1 a V12), se bloqueia o envio e
 * a mensagem em portugues explicando o problema. Tambem serve de DTO para as telas.
 */
public with sharing class LeaveRuleResult {
    @AuraEnabled
    public String code;
    @AuraEnabled
    public Boolean blocking;
    @AuraEnabled
    public String message;

    public LeaveRuleResult(String code, Boolean blocking, String message) {
        this.code = code;
        this.blocking = blocking;
        this.message = message;
    }
}
