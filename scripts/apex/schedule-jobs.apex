// RH Core: agenda os tres jobs recorrentes do produto. Executar uma vez por org, depois do seed.
// Projeto demonstrativo, empresa e dados ficticios.
//   - LeaveScheduler: periodos aquisitivos e status das ferias, todo dia as 01:00.
//   - PromotionEffectivationBatch: efetiva promocoes aprovadas cuja data chegou, todo dia as 02:00.
//   - CandidateRetentionBatch: anonimiza candidatos vencidos (LGPD), semanalmente.
// Idempotente: um job com o mesmo nome ja agendado e preservado.

Set<String> names = new Set<String>{ LeaveScheduler.JOB_NAME, PromotionEffectivationBatch.JOB_NAME, CandidateRetentionBatch.JOB_NAME };
Set<String> scheduled = new Set<String>();
for (CronTrigger t : [SELECT CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name IN :names AND State != 'DELETED']) {
    scheduled.add(t.CronJobDetail.Name);
}
Integer created = 0;
if (!scheduled.contains(LeaveScheduler.JOB_NAME)) {
    LeaveScheduler.scheduleDaily();
    created++;
}
if (!scheduled.contains(PromotionEffectivationBatch.JOB_NAME)) {
    PromotionEffectivationBatch.scheduleDaily();
    created++;
}
if (!scheduled.contains(CandidateRetentionBatch.JOB_NAME)) {
    CandidateRetentionBatch.schedule();
    created++;
}
System.debug('Jobs agendados agora: ' + created + '; ja existiam: ' + scheduled.size());
