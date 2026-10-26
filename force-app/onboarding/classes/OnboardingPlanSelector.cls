/**
 * Consultas de Onboarding_Plan__c e dos colaboradores em pre-admissao.
 *
 * Os metodos sem prefixo rodam em USER_MODE: o compartilhamento do colaborador (que o plano herda) e a FLS decidem o
 * que volta. Os metodos system* rodam em modo sistema e so podem ser chamados por OnboardingService (contexto de
 * sistema da spec 02: atualizar a situacao do plano a partir de uma tarefa, e ler a candidatura contratada).
 */
public inherited sharing class OnboardingPlanSelector {
    public static List<Onboarding_Plan__c> byIds(Set<Id> ids) {
        return [
            SELECT
                Id,
                Name,
                Employee__c,
                Employee__r.Name,
                Employee__r.Status__c,
                Employee__r.Hire_Date__c,
                Job_Application__c,
                Start_Date__c,
                Status__c
            FROM Onboarding_Plan__c
            WHERE Id IN :ids
            WITH USER_MODE
        ];
    }

    /** Planos do colaborador, o mais recente primeiro. */
    public static List<Onboarding_Plan__c> byEmployeeIds(Set<Id> employeeIds) {
        return [
            SELECT
                Id,
                Name,
                Employee__c,
                Employee__r.Name,
                Employee__r.Status__c,
                Employee__r.Hire_Date__c,
                Job_Application__c,
                Start_Date__c,
                Status__c
            FROM Onboarding_Plan__c
            WHERE Employee__c IN :employeeIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC, Id DESC
        ];
    }

    /** Planos visiveis ao usuario, para a visao geral do RH. Sem concluidos por padrao. */
    public static List<Onboarding_Plan__c> overview(Boolean includeCompleted, Integer maxRows) {
        if (includeCompleted == true) {
            return [
                SELECT Id, Name, Employee__c, Employee__r.Name, Employee__r.Status__c, Start_Date__c, Status__c
                FROM Onboarding_Plan__c
                WITH USER_MODE
                ORDER BY Start_Date__c ASC NULLS LAST, CreatedDate DESC
                LIMIT :maxRows
            ];
        }
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Employee__r.Status__c, Start_Date__c, Status__c
            FROM Onboarding_Plan__c
            WHERE Status__c != 'Concluido'
            WITH USER_MODE
            ORDER BY Start_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT :maxRows
        ];
    }

    /** Colaboradores em pre-admissao visiveis ao usuario (tela de ativacao do RH). */
    public static List<Employee__c> preAdmissionEmployees(Integer maxRows) {
        return [
            SELECT
                Id,
                Name,
                Employee_Number__c,
                Email__c,
                Hire_Date__c,
                Position__c,
                Position__r.Name,
                Department__r.Name,
                Manager__c,
                Manager__r.Name,
                Employment_Type__c
            FROM Employee__c
            WHERE Status__c = 'Pre_Admissao'
            WITH USER_MODE
            ORDER BY Hire_Date__c ASC, Name
            LIMIT :maxRows
        ];
    }

    /** Colaboradores que podem ser gestor na ativacao. */
    public static List<Employee__c> managerCandidates(Integer maxRows) {
        return [
            SELECT Id, Name, Employee_Number__c
            FROM Employee__c
            WHERE Status__c != 'Desligado'
            WITH USER_MODE
            ORDER BY Name
            LIMIT :maxRows
        ];
    }

    /** Cargos ativos para a escolha de cargo na ativacao. */
    public static List<Job_Position__c> activePositions(Integer maxRows) {
        return [
            SELECT Id, Name
            FROM Job_Position__c
            WHERE Active__c = TRUE
            WITH USER_MODE
            ORDER BY Name
            LIMIT :maxRows
        ];
    }

    // ------------------------------------------------------------------------------ modo sistema (OnboardingService)

    public static List<Onboarding_Plan__c> systemByIds(Set<Id> ids) {
        return [
            SELECT Id, Status__c, Employee__r.Status__c
            FROM Onboarding_Plan__c
            WHERE Id IN :ids
            WITH SYSTEM_MODE
        ];
    }

    /** Candidaturas contratadas com os dados do candidato e da vaga (admissao). */
    public static List<Job_Application__c> systemApplications(Set<Id> applicationIds) {
        return [
            SELECT
                Id,
                Name,
                Employee__c,
                Candidate__r.Name,
                Candidate__r.Email__c,
                Job_Opening__r.Position__c,
                Job_Opening__r.Department__c,
                Job_Opening__r.Hiring_Manager__c,
                Job_Opening__r.Employment_Type__c
            FROM Job_Application__c
            WHERE Id IN :applicationIds
            WITH SYSTEM_MODE
        ];
    }

    /** Usuario de cada colaborador indicado (Id do colaborador -> Id do usuario). */
    public static Map<Id, Id> systemUserByEmployee(Set<Id> employeeIds) {
        Map<Id, Id> result = new Map<Id, Id>();
        for (Employee__c e : [SELECT Id, User__c FROM Employee__c WHERE Id IN :employeeIds WITH SYSTEM_MODE]) {
            result.put(e.Id, e.User__c);
        }
        return result;
    }

    /** True se ja existe outro colaborador com a matricula (mesmo fora do alcance do usuario). */
    public static Boolean systemEmployeeNumberTaken(String employeeNumber, Id exceptEmployeeId) {
        List<Employee__c> rows = [
            SELECT Id
            FROM Employee__c
            WHERE Employee_Number__c = :employeeNumber AND Id != :exceptEmployeeId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return !rows.isEmpty();
    }
}
