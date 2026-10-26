/**
 * Regras de Job_Application__c no trigger. Valem para qualquer caminho de gravacao (kanban, tela, API, Flow):
 *
 *  - insert: so vaga Aberta (C6), etapa inicial, chave unica candidato+vaga (C5), dono na fila (spec 02),
 *    historico inicial, contagem da vaga (C8), ultima atividade do candidato e compartilhamento (C9);
 *  - update: transicao guiada pela CMDT (C1), motivo e nota exigidos (C2), data de entrada na etapa, historico
 *    com dias na etapa anterior (C3), ultima atividade do candidato e aviso de contratacao (C10);
 *  - delete e undelete: contagem da vaga.
 *
 * Contexto de sistema (spec 02): a classe e without sharing porque mantem dados derivados que o usuario que moveu
 * a candidatura nao enxerga por inteiro (candidaturas dos outros gestores na contagem e na chave unica, historico,
 * candidato). Nenhuma regra de acesso do usuario e contornada: quem pode mover ja foi decidido pelo servico.
 */
// Contexto de sistema da spec 02: dados derivados de candidatura mantidos por Apex.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class JobApplicationTriggerHandler extends TriggerHandler {
    public static final String DUPLICATE_MESSAGE = 'Este candidato já se inscreveu nesta vaga.';
    public static final String CLOSED_OPENING_MESSAGE = 'Esta vaga não está aberta para novas candidaturas.';
    public static final String SCORE_MESSAGE = 'A nota deve estar entre 0 e 5.';
    public static final String CANDIDATE_LOCKED_MESSAGE = 'O candidato de uma candidatura não pode ser alterado.';
    private static final Decimal MILLIS_PER_DAY = 86400000;

    private List<Job_Application__c> newList;
    private Map<Id, Job_Application__c> oldMap;

    public JobApplicationTriggerHandler() {
        this.newList = (List<Job_Application__c>) Trigger.new;
        this.oldMap = (Map<Id, Job_Application__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        Map<Id, Job_Opening__c> openings = loadOpenings(newList);
        String initialStage = RecruitingStageConfig.initialStage();
        Id queueId = RecruitingQueue.id();
        Datetime now = Datetime.now();
        for (Job_Application__c a : newList) {
            if (String.isBlank(a.Stage__c)) {
                a.Stage__c = initialStage;
            } else if (a.Stage__c != initialStage) {
                a.Stage__c.addError(
                    'Toda candidatura começa na etapa ' + RecruitingStageConfig.label(initialStage) + '.'
                );
            }
            Job_Opening__c opening = openings.get(a.Job_Opening__c);
            if (opening != null && opening.Status__c != JobOpeningService.STATUS_OPEN) {
                a.Job_Opening__c.addError(CLOSED_OPENING_MESSAGE);
            }
            validateScore(a);
            a.Stage_Entered_Date__c = now;
            if (queueId != null) {
                a.OwnerId = queueId;
            }
        }
        applyUniqueKeys(newList);
    }

    protected override void beforeUpdate() {
        Datetime now = Datetime.now();
        List<Job_Application__c> keyChanged = new List<Job_Application__c>();
        for (Job_Application__c a : newList) {
            Job_Application__c old = oldMap.get(a.Id);
            if (a.Candidate__c != old.Candidate__c) {
                a.Candidate__c.addError(CANDIDATE_LOCKED_MESSAGE);
            }
            if (a.Job_Opening__c != old.Job_Opening__c) {
                keyChanged.add(a);
            }
            if (a.Score__c != old.Score__c) {
                validateScore(a);
            }
            if (a.Stage__c != old.Stage__c) {
                String error = RecruitingStageConfig.validate(old.Stage__c, a.Stage__c, a.Score__c, a.Rejection_Reason__c);
                if (error != null) {
                    a.Stage__c.addError(error);
                } else {
                    a.Stage_Entered_Date__c = now;
                }
            } else if (a.Stage_Entered_Date__c != old.Stage_Entered_Date__c) {
                // A data de entrada na etapa e mantida pelo trigger; edicao manual e ignorada.
                a.Stage_Entered_Date__c = old.Stage_Entered_Date__c;
            }
        }
        if (!keyChanged.isEmpty()) {
            applyUniqueKeys(keyChanged);
        }
    }

    protected override void afterInsert() {
        Datetime now = Datetime.now();
        List<Application_Stage_History__c> history = new List<Application_Stage_History__c>();
        Set<Id> candidateIds = new Set<Id>();
        Set<Id> openingIds = new Set<Id>();
        for (Job_Application__c a : newList) {
            history.add(historyRow(a.Id, null, a.Stage__c, null, now, JobApplicationService.takeNote(a.Id)));
            candidateIds.add(a.Candidate__c);
            openingIds.add(a.Job_Opening__c);
        }
        insert history;
        touchCandidates(candidateIds);
        JobOpeningService.refreshApplicationCounts(openingIds);
        RecruitingSharingService.recalculate(newList);
    }

    protected override void afterUpdate() {
        Datetime now = Datetime.now();
        List<Application_Stage_History__c> history = new List<Application_Stage_History__c>();
        Set<Id> candidateIds = new Set<Id>();
        Set<Id> hired = new Set<Id>();
        Set<Id> openingIds = new Set<Id>();
        List<Job_Application__c> reshare = new List<Job_Application__c>();
        for (Job_Application__c a : newList) {
            Job_Application__c old = oldMap.get(a.Id);
            if (a.Stage__c != old.Stage__c) {
                history.add(
                    historyRow(a.Id, old.Stage__c, a.Stage__c, daysBetween(old.Stage_Entered_Date__c, now), now, JobApplicationService.takeNote(a.Id))
                );
                candidateIds.add(a.Candidate__c);
                if (a.Stage__c == RecruitingStageConfig.HIRED_STAGE) {
                    hired.add(a.Id);
                }
            }
            if (a.Job_Opening__c != old.Job_Opening__c) {
                openingIds.add(a.Job_Opening__c);
                openingIds.add(old.Job_Opening__c);
                reshare.add(a);
            }
        }
        if (!history.isEmpty()) {
            insert history;
            touchCandidates(candidateIds);
        }
        if (!openingIds.isEmpty()) {
            JobOpeningService.refreshApplicationCounts(openingIds);
            RecruitingSharingService.recalculate(reshare);
        }
        if (!hired.isEmpty()) {
            JobApplicationService.onHired(hired);
        }
    }

    protected override void afterDelete() {
        Set<Id> openingIds = new Set<Id>();
        for (Job_Application__c a : oldMap.values()) {
            openingIds.add(a.Job_Opening__c);
        }
        JobOpeningService.refreshApplicationCounts(openingIds);
    }

    protected override void afterUndelete() {
        Set<Id> openingIds = new Set<Id>();
        for (Job_Application__c a : newList) {
            openingIds.add(a.Job_Opening__c);
        }
        JobOpeningService.refreshApplicationCounts(openingIds);
        RecruitingSharingService.recalculate(newList);
    }

    // -----------------------------------------------------------------------------------------------------

    private static Map<Id, Job_Opening__c> loadOpenings(List<Job_Application__c> applications) {
        Set<Id> ids = new Set<Id>();
        for (Job_Application__c a : applications) {
            ids.add(a.Job_Opening__c);
        }
        ids.remove(null);
        return new Map<Id, Job_Opening__c>([SELECT Id, Status__c FROM Job_Opening__c WHERE Id IN :ids]);
    }

    private static void validateScore(Job_Application__c a) {
        if (a.Score__c != null && (a.Score__c < 0 || a.Score__c > 5)) {
            a.Score__c.addError(SCORE_MESSAGE);
        }
    }

    /** C5: Unique_Key__c = CandidateId|OpeningId, com mensagem amigavel antes do erro de duplicidade do banco. */
    private static void applyUniqueKeys(List<Job_Application__c> applications) {
        Map<String, Job_Application__c> inBatch = new Map<String, Job_Application__c>();
        for (Job_Application__c a : applications) {
            if (a.Candidate__c == null || a.Job_Opening__c == null) {
                continue;
            }
            String key = String.valueOf(a.Candidate__c) + '|' + String.valueOf(a.Job_Opening__c);
            a.Unique_Key__c = key;
            if (inBatch.containsKey(key)) {
                a.Job_Opening__c.addError(DUPLICATE_MESSAGE);
            } else {
                inBatch.put(key, a);
            }
        }
        if (inBatch.isEmpty()) {
            return;
        }
        for (Job_Application__c existing : [
            SELECT Id, Unique_Key__c
            FROM Job_Application__c
            WHERE Unique_Key__c IN :inBatch.keySet()
        ]) {
            Job_Application__c candidate = inBatch.get(existing.Unique_Key__c);
            if (candidate != null && candidate.Id != existing.Id) {
                candidate.Job_Opening__c.addError(DUPLICATE_MESSAGE);
            }
        }
    }

    private static Application_Stage_History__c historyRow(
        Id applicationId,
        String fromStage,
        String toStage,
        Decimal days,
        Datetime changedAt,
        String note
    ) {
        return new Application_Stage_History__c(
            Job_Application__c = applicationId,
            From_Stage__c = fromStage,
            To_Stage__c = toStage,
            Changed_By__c = UserInfo.getUserId(),
            Changed_At__c = changedAt,
            Days_In_Previous_Stage__c = days,
            Note__c = note
        );
    }

    /** Dias (uma casa decimal) entre a entrada na etapa anterior e agora; null se a entrada nao foi registrada. */
    private static Decimal daysBetween(Datetime entered, Datetime now) {
        if (entered == null) {
            return null;
        }
        Decimal millis = now.getTime() - entered.getTime();
        return (millis / MILLIS_PER_DAY).setScale(1, RoundingMode.HALF_UP);
    }

    /** C3: a ultima atividade do candidato acompanha cada mudanca de etapa. */
    private static void touchCandidates(Set<Id> candidateIds) {
        candidateIds.remove(null);
        if (candidateIds.isEmpty()) {
            return;
        }
        List<Candidate__c> toUpdate = new List<Candidate__c>();
        for (Id id : candidateIds) {
            toUpdate.add(new Candidate__c(Id = id, Last_Activity_Date__c = Date.today()));
        }
        TriggerHandler.bypass('CandidateTriggerHandler');
        try {
            update toUpdate;
        } finally {
            TriggerHandler.clearBypass('CandidateTriggerHandler');
        }
    }
}
