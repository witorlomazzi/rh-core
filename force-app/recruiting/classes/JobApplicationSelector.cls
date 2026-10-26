/**
 * Consultas de Job_Application__c e do historico de etapas, sempre em USER_MODE. O compartilhamento por gestor
 * contratante (RecruitingSharingService) decide quais candidaturas cada usuario enxerga.
 */
public inherited sharing class JobApplicationSelector {
    public static List<Job_Application__c> byIds(Set<Id> applicationIds) {
        return [
            SELECT
                Id,
                Name,
                Candidate__c,
                Candidate__r.Name,
                Job_Opening__c,
                Job_Opening__r.Name,
                Job_Opening__r.Status__c,
                Stage__c,
                Stage_Entered_Date__c,
                Score__c,
                Rejection_Reason__c,
                Source__c,
                Employee__c
            FROM Job_Application__c
            WHERE Id IN :applicationIds
            WITH USER_MODE
        ];
    }

    /** Candidaturas visiveis de uma vaga, mais antigas primeiro. */
    public static List<Job_Application__c> byOpening(Id openingId, Integer maxRows) {
        return [
            SELECT
                Id,
                Name,
                Candidate__c,
                Candidate__r.Name,
                Job_Opening__c,
                Stage__c,
                Stage_Entered_Date__c,
                Score__c,
                Rejection_Reason__c,
                Source__c
            FROM Job_Application__c
            WHERE Job_Opening__c = :openingId
            WITH USER_MODE
            ORDER BY CreatedDate, Id
            LIMIT :maxRows
        ];
    }

    /** Contagem de candidaturas visiveis por etapa em uma vaga. */
    public static List<AggregateResult> countByStage(Id openingId) {
        return [
            SELECT Stage__c stage, COUNT(Id) total
            FROM Job_Application__c
            WHERE Job_Opening__c = :openingId
            WITH USER_MODE
            GROUP BY Stage__c
        ];
    }

    /** Media de dias que as candidaturas da vaga passaram em cada etapa que ja deixaram. */
    public static List<AggregateResult> averageDaysByStage(Id openingId) {
        return [
            SELECT From_Stage__c stage, AVG(Days_In_Previous_Stage__c) avgDays
            FROM Application_Stage_History__c
            WHERE Job_Application__r.Job_Opening__c = :openingId AND From_Stage__c != NULL
            WITH USER_MODE
            GROUP BY From_Stage__c
        ];
    }

    /** Historico de etapas de uma candidatura, do mais antigo para o mais recente. */
    public static List<Application_Stage_History__c> historyOf(Id applicationId) {
        return [
            SELECT
                Id,
                From_Stage__c,
                To_Stage__c,
                Changed_At__c,
                Changed_By__c,
                Changed_By__r.Name,
                Days_In_Previous_Stage__c,
                Note__c
            FROM Application_Stage_History__c
            WHERE Job_Application__c = :applicationId
            WITH USER_MODE
            ORDER BY Changed_At__c, CreatedDate, Id
        ];
    }
}
