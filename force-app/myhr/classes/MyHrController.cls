/**
 * Controller fino do Meu RH (myHrHome, myHrTeamOverview, myHrEmployeeReviews). A regra esta em MyHrService; aqui so
 * se converte excecao em mensagem para a tela.
 */
public with sharing class MyHrController {
    /** Colaborador atual, se e gestor, se e RH e os Ids que os componentes filhos usam, em uma chamada. */
    @AuraEnabled
    public static MyHrService.Context getContext() {
        try {
            return MyHrService.buildContext();
        } catch (Exception e) {
            throw toAura('Não foi possível carregar o Meu RH.', e);
        }
    }

    /** Equipe direta do gestor com saldo de ferias, proximas ferias e alerta de prazo concessivo. */
    @AuraEnabled
    public static MyHrService.TeamOverview getTeamOverview() {
        try {
            return MyHrService.teamOverview();
        } catch (Exception e) {
            throw toAura('Não foi possível carregar a equipe.', e);
        }
    }

    /** Avaliacoes do colaborador visiveis ao usuario. */
    @AuraEnabled
    public static List<MyHrService.ReviewRow> getEmployeeReviews(Id employeeId) {
        try {
            return MyHrService.reviews(employeeId);
        } catch (Exception e) {
            throw toAura('Não foi possível carregar as avaliações.', e);
        }
    }

    private static AuraHandledException toAura(String prefix, Exception e) {
        AuraHandledException ex = new AuraHandledException(prefix + ' ' + e.getMessage());
        ex.setMessage(prefix + ' ' + e.getMessage());
        return ex;
    }
}
