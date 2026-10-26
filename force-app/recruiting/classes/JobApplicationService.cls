/**
 * Regras de candidatura. Base do kanban, do portal publico de vagas (spec 14) e da admissao (spec 15).
 *
 *  - apply: cria candidato (sem duplicar pessoa) e candidatura a partir de um DTO.
 *  - changeStage / changeStages: avanca etapa com a validacao guiada pela CMDT. A etapa so muda por aqui (ou por
 *    DML direto, que passa pelas mesmas regras no trigger); o gestor contratante nao tem FLS de edicao em
 *    Stage__c e o servico grava em contexto de sistema depois de validar acesso e transicao.
 *  - rate: grava a nota (0 a 5) como o proprio usuario.
 *  - onHired: avisa o modulo de admissao (interface HiredApplicationHandler).
 *
 * A classe herda o modo de compartilhamento de quem chama: o controller do kanban e `with sharing`, entao o
 * usuario so move candidaturas que enxerga e pode editar.
 */
public inherited sharing class JobApplicationService {
    public static final Decimal MIN_SCORE = 0;
    public static final Decimal MAX_SCORE = 5;
    public static final String HIRED_HANDLER_CLASS = 'OnboardingHiredHandler';

    public class RecruitingException extends Exception {
    }

    /** Pedido de mudanca de etapa. rejectionReason e score so sao necessarios quando a CMDT exige. */
    public class StageChange {
        public Id applicationId;
        public String toStage;
        public String rejectionReason;
        public Decimal score;

        public StageChange() {
        }

        public StageChange(Id applicationId, String toStage, String rejectionReason, Decimal score) {
            this.applicationId = applicationId;
            this.toStage = toStage;
            this.rejectionReason = rejectionReason;
            this.score = score;
        }
    }

    /** Observacoes que o trigger grava no historico da proxima mudanca de etapa de cada candidatura. */
    private static Map<Id, String> pendingNotes = new Map<Id, String>();

    @TestVisible
    private static HiredApplicationHandler testHandler;

    /** Registra a observacao que sera gravada no historico da proxima mudanca de etapa da candidatura. */
    public static void registerNote(Id applicationId, String note) {
        pendingNotes.put(applicationId, note);
    }

    /** Devolve e remove a observacao registrada para a candidatura (uso do trigger). */
    public static String takeNote(Id applicationId) {
        return pendingNotes.remove(applicationId);
    }

    /**
     * Cadastra a candidatura de uma pessoa a uma vaga. O candidato e reaproveitado pelo e-mail (C4). Se a
     * candidatura for recusada (vaga fechada, duplicada), o candidato recem-criado tambem e desfeito.
     */
    public static Job_Application__c apply(
        CandidateService.CandidateInput input,
        Id openingId,
        String source,
        String coverLetter
    ) {
        if (openingId == null) {
            throw new RecruitingException('Informe a vaga.');
        }
        Savepoint sp = Database.setSavepoint();
        try {
            Candidate__c candidate = CandidateService.upsertByEmail(input);
            Job_Application__c application = new Job_Application__c(
                Candidate__c = candidate.Id,
                Job_Opening__c = openingId,
                Source__c = source,
                Cover_Letter__c = coverLetter
            );
            insert application;
            return application;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new RecruitingException(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    public static Job_Application__c changeStage(
        Id applicationId,
        String toStage,
        String rejectionReason,
        Decimal score
    ) {
        List<Job_Application__c> rows = changeStages(
            new List<StageChange>{ new StageChange(applicationId, toStage, rejectionReason, score) }
        );
        return rows.isEmpty() ? null : rows[0];
    }

    /**
     * Muda a etapa de varias candidaturas de uma vez, tudo ou nada. Cada pedido e validado antes do DML (C1 e C2)
     * e o primeiro erro interrompe o lote com a mensagem da regra. Devolve as candidaturas ja atualizadas.
     */
    public static List<Job_Application__c> changeStages(List<StageChange> changes) {
        if (changes == null || changes.isEmpty()) {
            return new List<Job_Application__c>();
        }
        if (!Schema.sObjectType.Job_Application__c.isUpdateable()) {
            throw new RecruitingException('Você não tem permissão para mover candidaturas.');
        }
        Set<Id> ids = new Set<Id>();
        for (StageChange c : changes) {
            if (c == null || c.applicationId == null || String.isBlank(c.toStage)) {
                throw new RecruitingException('Informe a candidatura e a etapa de destino.');
            }
            if (!ids.add(c.applicationId)) {
                throw new RecruitingException('A mesma candidatura aparece mais de uma vez no lote.');
            }
        }
        // USER_MODE: so entra no lote o que o usuario enxerga.
        Map<Id, Job_Application__c> current = new Map<Id, Job_Application__c>(JobApplicationSelector.byIds(ids));

        List<Job_Application__c> toUpdate = new List<Job_Application__c>();
        for (StageChange c : changes) {
            Job_Application__c app = current.get(c.applicationId);
            if (app == null) {
                throw new RecruitingException('Candidatura não encontrada ou sem acesso.');
            }
            if (app.Stage__c == c.toStage) {
                continue;
            }
            Decimal score = c.score != null ? c.score : app.Score__c;
            String reason = String.isNotBlank(c.rejectionReason) ? c.rejectionReason : app.Rejection_Reason__c;
            assertValidScore(score);
            String error = RecruitingStageConfig.validate(app.Stage__c, c.toStage, score, reason);
            if (error != null) {
                throw new RecruitingException(error);
            }
            Job_Application__c patch = new Job_Application__c(Id = app.Id, Stage__c = c.toStage);
            if (c.score != null) {
                patch.Score__c = c.score;
            }
            if (String.isNotBlank(c.rejectionReason)) {
                patch.Rejection_Reason__c = c.rejectionReason;
            }
            toUpdate.add(patch);
        }
        if (!toUpdate.isEmpty()) {
            try {
                // Stage__c e somente leitura por FLS para o gestor contratante (spec 02): a gravacao em modo
                // sistema so acontece depois de validar acesso ao registro, permissao de edicao e transicao.
                update toUpdate;
            } catch (DmlException e) {
                throw new RecruitingException(e.getDmlMessage(0));
            }
        }
        return JobApplicationSelector.byIds(ids);
    }

    /** Grava a nota de 0 a 5 como o proprio usuario (respeita FLS e compartilhamento). */
    public static void rate(Id applicationId, Decimal score) {
        if (applicationId == null || score == null) {
            throw new RecruitingException('Informe a candidatura e a nota.');
        }
        assertValidScore(score);
        List<Job_Application__c> rows = JobApplicationSelector.byIds(new Set<Id>{ applicationId });
        if (rows.isEmpty()) {
            throw new RecruitingException('Candidatura não encontrada ou sem acesso.');
        }
        try {
            Job_Application__c patch = new Job_Application__c(Id = applicationId, Score__c = score);
            update as user patch;
        } catch (DmlException e) {
            throw new RecruitingException(e.getDmlMessage(0));
        }
    }

    /**
     * C10: avisa o modulo de admissao que as candidaturas foram contratadas. A implementacao
     * (OnboardingHiredHandler) e resolvida por nome; se nao existir, so registra em debug. Excecao da
     * implementacao propaga e desfaz a contratacao: nao pode existir contratado sem a admissao correspondente.
     */
    public static void onHired(Set<Id> applicationIds) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            return;
        }
        HiredApplicationHandler handler = testHandler;
        if (handler == null) {
            Type handlerType = Type.forName(HIRED_HANDLER_CLASS);
            if (handlerType == null) {
                System.debug(
                    LoggingLevel.INFO,
                    'Modulo de admissao nao instalado; contratacao registrada sem criar colaborador.'
                );
                return;
            }
            handler = (HiredApplicationHandler) handlerType.newInstance();
        }
        handler.handle(applicationIds);
    }

    private static void assertValidScore(Decimal score) {
        if (score != null && (score < MIN_SCORE || score > MAX_SCORE)) {
            throw new RecruitingException('A nota deve estar entre 0 e 5.');
        }
    }
}
