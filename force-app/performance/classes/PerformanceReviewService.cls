/**
 * Avaliacao do gestor: preenchimento pelo avaliador, calibracao pelo RH e as travas de Performance_Review__c.
 *
 * Status__c e somente leitura por FLS para gestor e colaborador (spec 02, principio 5): o servico valida quem
 * pode agir e grava a situacao em contexto de sistema, na classe interna Privileged. Os campos que o gestor
 * edita (nota e comentario) sao gravados com "as user".
 */
// Escrita de situacao e nota calibrada em contexto de sistema (spec 02, principio 5), depois de validar o papel.
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class PerformanceReviewService {
    public static final String PENDING = 'Pendente';
    public static final String IN_PROGRESS = 'Em_Andamento';
    public static final String SENT = 'Enviada';
    public static final String CALIBRATED = 'Calibrada';
    public static final String RELEASED = 'Liberada';

    /** Verdadeiro dentro de operacoes do proprio modulo (lancamento, calibracao, liberacao, situacao). */
    private static Boolean trusted = false;

    public static void beginTrusted() {
        trusted = true;
    }

    public static void endTrusted() {
        trusted = false;
    }

    public static Boolean isTrusted() {
        return trusted;
    }

    // ------------------------------------------------------------------------------------ gestor (avaliador)

    /**
     * Grava nota e comentario do avaliador. Com submitReview = false a avaliacao fica Em_Andamento; com true exige
     * nota e comentario e passa para Enviada (nao editavel depois).
     */
    public static Performance_Review__c saveManagerReview(Id reviewId, Decimal rating, String comments, Boolean submitReview) {
        Performance_Review__c review = PerformanceReviewSelector.byId(reviewId);
        if (review == null) {
            throw new ReviewErrors.ReviewException('Avaliação não encontrada ou sem acesso.');
        }
        if (review.Reviewer__c != UserInfo.getUserId()) {
            throw new ReviewErrors.ReviewException('Apenas o avaliador designado pode preencher esta avaliação.');
        }
        if (review.Review_Cycle__r.Status__c != ReviewCycleService.MANAGER_REVIEW) {
            throw new ReviewErrors.ReviewException('O ciclo não está na fase de avaliação do gestor.');
        }
        if (review.Status__c != PENDING && review.Status__c != IN_PROGRESS) {
            throw new ReviewErrors.ReviewException('Esta avaliação já foi enviada e não pode mais ser alterada.');
        }
        Boolean sending = submitReview == true;
        if (sending && (rating == null || String.isBlank(comments))) {
            throw new ReviewErrors.ReviewException('Informe a nota e o comentário para enviar a avaliação.');
        }
        Performance_Review__c changes = new Performance_Review__c(
            Id = reviewId,
            Manager_Rating__c = rating,
            Manager_Comments__c = comments
        );
        update as user changes;
        new Privileged().setStatus(reviewId, sending ? SENT : IN_PROGRESS);
        return PerformanceReviewSelector.byId(reviewId);
    }

    // ------------------------------------------------------------------------------------------ RH: calibracao

    /** RH ajusta a nota calibrada de uma avaliacao Enviada ou Calibrada com o ciclo em Calibracao. */
    public static void calibrate(Id reviewId, Decimal rating) {
        ReviewCycleService.requireHr();
        Performance_Review__c review = PerformanceReviewSelector.forServiceById(reviewId);
        if (review == null) {
            throw new ReviewErrors.ReviewException('Avaliação não encontrada.');
        }
        if (review.Review_Cycle__r.Status__c != ReviewCycleService.CALIBRATION) {
            throw new ReviewErrors.ReviewException('A calibração só é possível com o ciclo em Calibração.');
        }
        if (review.Status__c != SENT && review.Status__c != CALIBRATED) {
            throw new ReviewErrors.ReviewException('Só é possível calibrar uma avaliação já enviada pelo gestor.');
        }
        if (rating == null || rating < 1 || rating > review.Review_Cycle__r.Rating_Scale_Max__c) {
            throw new ReviewErrors.ReviewException(
                'A nota calibrada deve estar entre 1 e ' + review.Review_Cycle__r.Rating_Scale_Max__c.intValue() + '.'
            );
        }
        new Privileged().calibrate(reviewId, rating);
    }

    // --------------------------------------------------------------------------------------------------- trigger

    /** Define a chave unica e confirma que a criacao vem do lancamento do ciclo. Chamado em before insert. */
    public static void prepareInsert(List<Performance_Review__c> newList) {
        for (Performance_Review__c r : newList) {
            if (r.Employee__c != null && r.Review_Cycle__c != null && String.isBlank(r.Unique_Key__c)) {
                r.Unique_Key__c = GoalSelector.key(r.Employee__c, r.Review_Cycle__c);
            }
            if (!trusted) {
                r.addError('As avaliações são criadas apenas pelo lançamento do ciclo.');
            }
        }
    }

    /**
     * Travas de edicao (before update): so o avaliador designado grava nota e comentario, com o ciclo em
     * Avaliacao_Gestor e a avaliacao ainda Pendente ou Em_Andamento. Situacao, notas calibrada e final e data de
     * liberacao so mudam por operacoes do modulo; o avaliador so pode ser trocado pelo RH.
     */
    public static void validateChanges(List<Performance_Review__c> newList, Map<Id, Performance_Review__c> oldMap) {
        if (trusted) {
            return;
        }
        Set<Id> cycleIds = new Set<Id>();
        for (Performance_Review__c r : newList) {
            cycleIds.add(r.Review_Cycle__c);
        }
        Map<Id, Review_Cycle__c> cycles = ReviewCycleSelector.byIdsForValidation(cycleIds);
        Boolean hr = ReviewCycleService.isHr();
        Id me = UserInfo.getUserId();
        for (Performance_Review__c r : newList) {
            Performance_Review__c old = oldMap.get(r.Id);
            if (
                r.Employee__c != old.Employee__c ||
                r.Review_Cycle__c != old.Review_Cycle__c ||
                r.Unique_Key__c != old.Unique_Key__c ||
                r.Status__c != old.Status__c ||
                r.Calibrated_Rating__c != old.Calibrated_Rating__c ||
                r.Final_Rating__c != old.Final_Rating__c ||
                r.Released_Date__c != old.Released_Date__c
            ) {
                r.addError('Situação, notas final e calibrada e vínculos só mudam pelo fluxo do ciclo de avaliação.');
                continue;
            }
            Boolean open = old.Status__c == PENDING || old.Status__c == IN_PROGRESS;
            if (r.Reviewer__c != old.Reviewer__c && (!hr || !open)) {
                r.Reviewer__c.addError('Apenas o RH troca o avaliador, e somente antes do envio da avaliação.');
                continue;
            }
            if (r.Manager_Rating__c != old.Manager_Rating__c || r.Manager_Comments__c != old.Manager_Comments__c) {
                Review_Cycle__c cycle = cycles.get(r.Review_Cycle__c);
                if (old.Reviewer__c != me) {
                    r.addError('Apenas o avaliador designado pode preencher esta avaliação.');
                } else if (cycle == null || cycle.Status__c != ReviewCycleService.MANAGER_REVIEW) {
                    r.addError('O ciclo não está na fase de avaliação do gestor.');
                } else if (!open) {
                    r.addError('Esta avaliação já foi enviada e não pode mais ser alterada.');
                } else if (r.Manager_Rating__c != null && (r.Manager_Rating__c < 1 || r.Manager_Rating__c > cycle.Rating_Scale_Max__c)) {
                    r.Manager_Rating__c.addError('A nota deve estar entre 1 e ' + cycle.Rating_Scale_Max__c.intValue() + '.');
                }
            }
        }
    }

    // ------------------------------------------------------------------------------------------------ contexto de sistema

    // Contexto de sistema (spec 02): situacao e nota calibrada nao sao editaveis por FLS; o papel foi validado acima.
    private without sharing class Privileged {
        void setStatus(Id reviewId, String status) {
            beginTrusted();
            try {
                update new Performance_Review__c(Id = reviewId, Status__c = status);
            } finally {
                endTrusted();
            }
        }

        void calibrate(Id reviewId, Decimal rating) {
            beginTrusted();
            try {
                update new Performance_Review__c(Id = reviewId, Calibrated_Rating__c = rating, Status__c = CALIBRATED);
            } finally {
                endTrusted();
            }
        }
    }
}
