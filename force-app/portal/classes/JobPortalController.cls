/**
 * Porta de entrada do portal publico de vagas (spec 14). Chamado pelo usuario convidado do site.
 *
 * `without sharing` de proposito (spec 02, contexto de sistema permitido): o convidado nao tem acesso a objeto
 * nem a registro, entao nada seria lido ou gravado em modo de usuario. Em troca, o controller so devolve DTOs
 * com campos permitidos (G1), so enxerga vagas elegiveis (G2) e valida tudo que recebe antes de gravar (G3).
 * Nenhum metodo devolve Id de registro, de usuario, de gestor ou de recrutador.
 */
public without sharing class JobPortalController {
    /** Configuracao do formulario: versao do termo (G5) e relogio do servidor para o tempo minimo de envio (G3). */
    public class FormConfig {
        @AuraEnabled
        public String consentTextVersion;
        @AuraEnabled
        public Long renderedAt;
    }

    /** Resultado do envio. message e amigavel; field aponta o campo com erro, quando houver. */
    public class SubmitResult {
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String field;
    }

    @AuraEnabled(cacheable=true)
    public static List<PortalJobDto> getJobs() {
        return JobPortalService.listOpenJobs();
    }

    @AuraEnabled(cacheable=true)
    public static PortalJobDto getJob(String slug) {
        return JobPortalService.findOpenJob(slug);
    }

    @AuraEnabled
    public static FormConfig getFormConfig() {
        FormConfig config = new FormConfig();
        config.consentTextVersion = JobPortalService.consentTextVersion();
        config.renderedAt = Datetime.now().getTime();
        return config;
    }

    @AuraEnabled
    public static SubmitResult submitApplication(PortalApplicationInput input) {
        SubmitResult result = new SubmitResult();
        try {
            JobPortalService.submit(input);
            result.success = true;
            result.message = 'Candidatura enviada. Obrigado pelo interesse!';
        } catch (JobPortalService.PortalException e) {
            result.success = false;
            result.message = e.getMessage();
            result.field = e.field;
        } catch (Exception e) {
            // Detalhe tecnico fica so no log; o visitante recebe uma mensagem generica.
            System.debug(LoggingLevel.ERROR, 'Portal: falha inesperada ao enviar candidatura: ' + e.getMessage());
            result.success = false;
            result.message = JobPortalService.GENERIC_MESSAGE;
        }
        return result;
    }
}
