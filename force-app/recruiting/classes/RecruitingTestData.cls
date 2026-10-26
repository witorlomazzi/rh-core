/**
 * Dados de teste do modulo de recrutamento (prefixo ZZTEST-). Complementa HrTestDataFactory: nao cria usuarios,
 * porque a org de teste tem poucas licencas. Use a arvore de HrTestDataFactory.orgTree(): o RH (HR_Admin) faz o
 * papel de recrutador e o gestor 1 (HR_Manager) faz o de gestor contratante.
 */
@IsTest
public class RecruitingTestData {
    public static Job_Opening__c opening(String title, Id hiringManagerEmployeeId, String status) {
        Job_Opening__c o = new Job_Opening__c(
            Name = 'ZZTEST-' + title,
            Status__c = status,
            Hiring_Manager__c = hiringManagerEmployeeId,
            Openings_Count__c = 1
        );
        insert o;
        return reloadOpening(o.Id);
    }

    public static Candidate__c candidate(String label) {
        Candidate__c c = buildCandidate(label);
        insert c;
        return c;
    }

    public static Candidate__c buildCandidate(String label) {
        Integer n = HrTestDataFactory.nextSequence();
        return new Candidate__c(
            Name = 'ZZTEST-Candidato ' + label + ' ' + n,
            Email__c = 'ZZTEST-' + label + n + '@zztest.example.com',
            Source__c = 'Portal'
        );
    }

    public static Job_Application__c application(Id candidateId, Id openingId) {
        Job_Application__c a = new Job_Application__c(Candidate__c = candidateId, Job_Opening__c = openingId);
        insert a;
        return reloadApplication(a.Id);
    }

    /** Cria varios candidatos em um unico DML (testes de volume e de limite de SOQL). */
    public static List<Candidate__c> candidates(String label, Integer count) {
        List<Candidate__c> rows = new List<Candidate__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(buildCandidate(label + i));
        }
        insert rows;
        return rows;
    }

    /** Cria uma candidatura por candidato em um unico DML. Devolve as candidaturas com Id, sem recarregar. */
    public static List<Job_Application__c> applications(List<Candidate__c> candidates, Id openingId) {
        List<Job_Application__c> rows = new List<Job_Application__c>();
        for (Candidate__c c : candidates) {
            rows.add(new Job_Application__c(Candidate__c = c.Id, Job_Opening__c = openingId));
        }
        insert rows;
        return rows;
    }

    public static Job_Opening__c reloadOpening(Id id) {
        return [
            SELECT
                Id,
                Name,
                Status__c,
                Public_Slug__c,
                Hiring_Manager__c,
                Opened_Date__c,
                Closed_Date__c,
                Applications_Count__c
            FROM Job_Opening__c
            WHERE Id = :id
        ];
    }

    public static Job_Application__c reloadApplication(Id id) {
        return [
            SELECT
                Id,
                Name,
                OwnerId,
                Candidate__c,
                Job_Opening__c,
                Stage__c,
                Stage_Entered_Date__c,
                Score__c,
                Rejection_Reason__c,
                Cover_Letter__c,
                Unique_Key__c
            FROM Job_Application__c
            WHERE Id = :id
        ];
    }

    public static Candidate__c reloadCandidate(Id id) {
        return [
            SELECT
                Id,
                Name,
                OwnerId,
                Email__c,
                Email_Normalized__c,
                Phone__c,
                LinkedIn_URL__c,
                City__c,
                Source__c,
                Consent_Given__c,
                Consent_Date__c,
                Consent_Text_Version__c,
                Last_Activity_Date__c,
                Anonymized__c,
                Anonymized_Date__c
            FROM Candidate__c
            WHERE Id = :id
        ];
    }

    public static List<Application_Stage_History__c> history(Id applicationId) {
        return [
            SELECT Id, From_Stage__c, To_Stage__c, Days_In_Previous_Stage__c, Changed_By__c, Changed_At__c, Note__c
            FROM Application_Stage_History__c
            WHERE Job_Application__c = :applicationId
            ORDER BY Changed_At__c, CreatedDate, Id
        ];
    }

    /** Substituto do modulo de admissao: registra as candidaturas contratadas sem criar nada. */
    public class HiredRecorder implements HiredApplicationHandler {
        public Set<Id> handled = new Set<Id>();
        public Integer calls = 0;

        public void handle(Set<Id> applicationIds) {
            handled.addAll(applicationIds);
            calls++;
        }
    }

    /** Instala o registrador para que os testes nao dependam do modulo de admissao, se ele estiver na org. */
    public static HiredRecorder useRecorder() {
        HiredRecorder recorder = new HiredRecorder();
        JobApplicationService.testHandler = recorder;
        return recorder;
    }

    /** Move a candidatura pelo caminho mais curto ate a etapa informada, dando nota quando necessario. */
    public static void advanceTo(Id applicationId, String targetStage) {
        if (JobApplicationService.testHandler == null) {
            useRecorder();
        }
        List<String> path = new List<String>{ 'Triagem', 'Entrevista_RH', 'Entrevista_Tecnica', 'Proposta', 'Contratado' };
        String current = reloadApplication(applicationId).Stage__c;
        Boolean scored = false;
        for (String stage : path) {
            if (current == targetStage) {
                return;
            }
            Job_Application__c step = new Job_Application__c(Id = applicationId, Stage__c = stage);
            if (stage == 'Proposta' && !scored) {
                step.Score__c = 4;
                scored = true;
            }
            update step;
            current = stage;
        }
    }

    /** Envelhece a data de entrada na etapa sem passar pelas regras do trigger. */
    public static void ageStage(Id applicationId, Integer days) {
        TriggerHandler.bypass('JobApplicationTriggerHandler');
        try {
            update new Job_Application__c(Id = applicationId, Stage_Entered_Date__c = Datetime.now().addDays(-days));
        } finally {
            TriggerHandler.clearBypass('JobApplicationTriggerHandler');
        }
    }

    /** Envelhece a ultima atividade do candidato. */
    public static void ageCandidate(Id candidateId, Integer days) {
        TriggerHandler.bypass('CandidateTriggerHandler');
        try {
            update new Candidate__c(Id = candidateId, Last_Activity_Date__c = Date.today().addDays(-days));
        } finally {
            TriggerHandler.clearBypass('CandidateTriggerHandler');
        }
    }

    public static Set<Id> shareUsers(SObjectType shareType, Id parentId, String reason) {
        Set<Id> result = new Set<Id>();
        String soql =
            'SELECT UserOrGroupId FROM ' +
            String.valueOf(shareType) +
            ' WHERE ParentId = :parentId AND RowCause = :reason';
        for (SObject s : Database.query(soql)) {
            result.add((Id) s.get('UserOrGroupId'));
        }
        return result;
    }
}
