/**
 * Efetiva diariamente as promocoes Aprovadas cuja data de efetivacao chegou (regra P7). Tambem e o Schedulable:
 * PromotionEffectivationBatch.scheduleDaily() agenda a execucao diaria as 02:00.
 *
 * Roda sem sharing porque e um processo de sistema (spec 02, PromotionService): atualiza colaboradores e historico
 * sem depender de quem o agendou. A escolha do escopo (50) deixa folga para as notificacoes por promocao.
 */
public without sharing class PromotionEffectivationBatch implements Database.Batchable<SObject>, Schedulable {
    public static final String CRON_DAILY = '0 0 2 * * ?';
    public static final String JOB_NAME = 'PromotionEffectivationBatch diario';
    public static final Integer DEFAULT_SCOPE = 50;

    public Database.QueryLocator start(Database.BatchableContext context) {
        return PromotionRequestSelector.dueForEffectivation(PromotionService.today());
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        PromotionService.effectivate(new Map<Id, SObject>(scope).keySet());
    }

    public void finish(Database.BatchableContext context) {
        // Nada a consolidar: cada promocao e efetivada de forma independente.
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new PromotionEffectivationBatch(), DEFAULT_SCOPE);
    }

    /** Agenda a execucao diaria. Chamado uma vez pelo seed ou pelo administrador. */
    public static Id scheduleDaily() {
        return System.schedule(JOB_NAME, CRON_DAILY, new PromotionEffectivationBatch());
    }
}
