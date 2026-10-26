/**
 * Consultas do Meu RH. Tudo em USER_MODE: o compartilhamento (proprio colaborador, cadeia de gestores, RH) e a FLS
 * decidem o que volta. Nenhum campo salarial e selecionado.
 */
public inherited sharing class MyHrSelector {
    private static final Set<String> UPCOMING_STATUSES = new Set<String>{ 'Pendente', 'Aprovado', 'Em_Gozo' };

    /** Plano de onboarding do colaborador (o mais recente), ou null. */
    public static Onboarding_Plan__c onboardingPlan(Id employeeId) {
        List<Onboarding_Plan__c> rows = [
            SELECT Id, Status__c
            FROM Onboarding_Plan__c
            WHERE Employee__c = :employeeId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Solicitacoes de ferias que ainda nao terminaram, da mais proxima para a mais distante. */
    public static List<Leave_Request__c> upcomingLeave(Set<Id> employeeIds, Date fromDate) {
        return [
            SELECT Id, Employee__c, Start_Date__c, End_Date__c, Days__c, Status__c
            FROM Leave_Request__c
            WHERE Employee__c IN :employeeIds AND Status__c IN :UPCOMING_STATUSES AND End_Date__c >= :fromDate
            WITH USER_MODE
            ORDER BY Start_Date__c, CreatedDate
        ];
    }

    /** Periodos aquisitivos dos colaboradores informados (uma consulta para toda a equipe). */
    public static List<Leave_Accrual_Period__c> periods(Set<Id> employeeIds) {
        return [
            SELECT Id, Employee__c, Concession_Deadline__c, Balance_Days__c, Status__c
            FROM Leave_Accrual_Period__c
            WHERE Employee__c IN :employeeIds
            WITH USER_MODE
            ORDER BY Concession_Deadline__c
        ];
    }

    /** Avaliacoes de desempenho do colaborador visiveis ao usuario, da mais recente para a mais antiga. */
    public static List<Performance_Review__c> reviews(Id employeeId) {
        return [
            SELECT Id, Review_Cycle__c, Review_Cycle__r.Name, Status__c, Final_Rating__c, Released_Date__c
            FROM Performance_Review__c
            WHERE Employee__c = :employeeId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
    }
}
