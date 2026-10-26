/**
 * Compartilhamento com o gestor contratante (spec 02, C9).
 *
 * Candidatura e candidato pertencem a fila de recrutamento (OWD privado). O usuario do Hiring_Manager__c da vaga
 * recebe Edit na candidatura e Read no candidato, com o motivo Hiring_Manager__c. Um candidato com candidaturas
 * em vagas de gestores diferentes e compartilhado com cada um deles; ao remover o acesso de um gestor, o
 * compartilhamento do candidato so sai se nenhuma outra candidatura dele depender do mesmo gestor.
 *
 * Contexto de sistema (spec 02): criar e remover shares de qualquer candidatura, independente de quem alterou a
 * vaga ou a candidatura.
 */
// Contexto de sistema da spec 02: shares de candidatura e candidato mantidos por Apex.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class RecruitingSharingService {
    public static final String APPLICATION_REASON = Schema.Job_Application__Share.RowCause.Hiring_Manager__c;
    public static final String CANDIDATE_REASON = Schema.Candidate__Share.RowCause.Hiring_Manager__c;
    /** Acima disso o recalculo por vaga vai para batch, para nao estourar limites de DML. */
    public static final Integer SYNC_LIMIT = 1000;

    /**
     * Recalcula os shares das candidaturas informadas e dos candidatos delas. Usa Id, Candidate__c, Job_Opening__c
     * e OwnerId de cada candidatura.
     */
    public static void recalculate(List<Job_Application__c> applications) {
        if (applications == null || applications.isEmpty()) {
            return;
        }
        Set<Id> openingIds = new Set<Id>();
        Set<Id> candidateIds = new Set<Id>();
        Map<Id, Job_Application__c> byId = new Map<Id, Job_Application__c>();
        for (Job_Application__c a : applications) {
            openingIds.add(a.Job_Opening__c);
            candidateIds.add(a.Candidate__c);
            byId.put(a.Id, a);
        }
        Map<Id, Id> managerUserByOpening = managerUsers(openingIds);

        // Shares desejados da candidatura: um por candidatura, para o gestor da vaga.
        Map<String, Job_Application__Share> desiredApplication = new Map<String, Job_Application__Share>();
        for (Job_Application__c a : applications) {
            Id userId = managerUserByOpening.get(a.Job_Opening__c);
            if (userId != null && userId != a.OwnerId) {
                desiredApplication.put(key(a.Id, userId), newApplicationShare(a.Id, userId));
            }
        }

        // Shares desejados do candidato: consideram todas as candidaturas dele, nao so as do lote.
        Map<String, Candidate__Share> desiredCandidate = new Map<String, Candidate__Share>();
        Set<Id> allOpeningIds = new Set<Id>(openingIds);
        List<Job_Application__c> candidateApplications = [
            SELECT Id, Candidate__c, Job_Opening__c, OwnerId
            FROM Job_Application__c
            WHERE Candidate__c IN :candidateIds
        ];
        for (Job_Application__c a : candidateApplications) {
            allOpeningIds.add(a.Job_Opening__c);
        }
        Map<Id, Id> allManagers = managerUsers(allOpeningIds);
        for (Job_Application__c a : candidateApplications) {
            Id userId = allManagers.get(a.Job_Opening__c);
            if (userId != null && userId != a.OwnerId) {
                desiredCandidate.put(key(a.Candidate__c, userId), newCandidateShare(a.Candidate__c, userId));
            }
        }

        syncApplicationShares(byId.keySet(), desiredApplication);
        syncCandidateShares(candidateIds, desiredCandidate);
    }

    /** Refaz os shares de todas as candidaturas das vagas (C9: o gestor contratante mudou). */
    public static void recalculateForOpenings(Set<Id> openingIds) {
        if (openingIds == null || openingIds.isEmpty()) {
            return;
        }
        Integer total = [SELECT COUNT() FROM Job_Application__c WHERE Job_Opening__c IN :openingIds];
        if (total > SYNC_LIMIT && !System.isBatch() && !System.isFuture() && !System.isQueueable()) {
            Database.executeBatch(new RecruitingSharingRecalcBatch(openingIds), 200);
            return;
        }
        recalculate(
            [SELECT Id, Candidate__c, Job_Opening__c, OwnerId FROM Job_Application__c WHERE Job_Opening__c IN :openingIds]
        );
    }

    // -----------------------------------------------------------------------------------------------------

    /** Usuario do gestor contratante de cada vaga (via Employee__c.User__c). Vagas sem gestor ficam de fora. */
    private static Map<Id, Id> managerUsers(Set<Id> openingIds) {
        Map<Id, Id> result = new Map<Id, Id>();
        for (Job_Opening__c o : [
            SELECT Id, Hiring_Manager__r.User__c
            FROM Job_Opening__c
            WHERE Id IN :openingIds AND Hiring_Manager__c != NULL
        ]) {
            Id userId = o.Hiring_Manager__r.User__c;
            if (userId != null) {
                result.put(o.Id, userId);
            }
        }
        return result;
    }

    private static void syncApplicationShares(Set<Id> applicationIds, Map<String, Job_Application__Share> desired) {
        List<Job_Application__Share> toDelete = new List<Job_Application__Share>();
        for (Job_Application__Share s : [
            SELECT Id, ParentId, UserOrGroupId
            FROM Job_Application__Share
            WHERE ParentId IN :applicationIds AND RowCause = :APPLICATION_REASON
        ]) {
            String k = key(s.ParentId, s.UserOrGroupId);
            if (desired.containsKey(k)) {
                desired.remove(k);
            } else {
                toDelete.add(s);
            }
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        save(desired.values());
    }

    private static void syncCandidateShares(Set<Id> candidateIds, Map<String, Candidate__Share> desired) {
        List<Candidate__Share> toDelete = new List<Candidate__Share>();
        for (Candidate__Share s : [
            SELECT Id, ParentId, UserOrGroupId
            FROM Candidate__Share
            WHERE ParentId IN :candidateIds AND RowCause = :CANDIDATE_REASON
        ]) {
            String k = key(s.ParentId, s.UserOrGroupId);
            if (desired.containsKey(k)) {
                desired.remove(k);
            } else {
                toDelete.add(s);
            }
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        save(desired.values());
    }

    private static void save(List<SObject> shares) {
        if (shares.isEmpty()) {
            return;
        }
        // allOrNone false: usuario inativo nao recebe share e nao deve derrubar a transacao.
        for (Database.SaveResult r : Database.insert(shares, false)) {
            if (!r.isSuccess()) {
                System.debug(LoggingLevel.WARN, 'Share de recrutamento nao criado: ' + r.getErrors());
            }
        }
    }

    private static String key(Id parentId, Id userId) {
        return String.valueOf(parentId) + '|' + String.valueOf(userId);
    }

    private static Job_Application__Share newApplicationShare(Id applicationId, Id userId) {
        return new Job_Application__Share(
            ParentId = applicationId,
            UserOrGroupId = userId,
            AccessLevel = 'Edit',
            RowCause = APPLICATION_REASON
        );
    }

    private static Candidate__Share newCandidateShare(Id candidateId, Id userId) {
        return new Candidate__Share(
            ParentId = candidateId,
            UserOrGroupId = userId,
            AccessLevel = 'Read',
            RowCause = CANDIDATE_REASON
        );
    }
}
