/**
 * Vaga como o portal publico a enxerga (spec 14, G1). So estes campos saem do servidor: nenhum Id de usuario,
 * gestor ou recrutador, nenhum Id de registro. A lista de vagas devolve description e requirements vazios para
 * manter a resposta pequena; o detalhe devolve tudo.
 */
public class PortalJobDto {
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String slug;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public String location;
    @AuraEnabled
    public String workModel;
    @AuraEnabled
    public String employmentType;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String requirements;
    @AuraEnabled
    public Date openedDate;
}
