/**
 * Dados enviados pelo formulario publico de candidatura (spec 14, G3). Tudo aqui vem de um usuario anonimo e
 * nunca e confiavel: JobPortalService valida, limita e limpa cada campo.
 */
public class PortalApplicationInput {
    /** Identificador publico da vaga (Public_Slug__c). */
    @AuraEnabled
    public String slug;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String phone;
    @AuraEnabled
    public String city;
    @AuraEnabled
    public String linkedInUrl;
    /** Mensagem do candidato, gravada em Cover_Letter__c. */
    @AuraEnabled
    public String message;
    /** Aceite do termo de privacidade. */
    @AuraEnabled
    public Boolean consent;
    /** Honeypot: campo escondido que pessoas nao preenchem. */
    @AuraEnabled
    public String website;
    /** Momento (epoch ms, relogio do servidor) em que o formulario foi exibido. */
    @AuraEnabled
    public Long renderedAt;
}
