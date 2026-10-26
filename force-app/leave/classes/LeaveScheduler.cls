/**
 * Agendamento diario das ferias: uma unica execucao dispara o lote de periodos aquisitivos e o lote de status.
 * Para agendar: LeaveScheduler.scheduleDaily(). O horario padrao e 01:00; os dois lotes usam o mesmo agendamento.
 */
public with sharing class LeaveScheduler implements Schedulable {
    public static final String JOB_NAME = 'RH Core - Ferias diario';
    public static final String DEFAULT_CRON = '0 0 1 * * ?';
    public static final Integer BATCH_SIZE = 200;

    public static Id scheduleDaily() {
        return scheduleDaily(DEFAULT_CRON);
    }

    public static Id scheduleDaily(String cronExpression) {
        return System.schedule(JOB_NAME, cronExpression, new LeaveScheduler());
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LeaveAccrualBatch(), BATCH_SIZE);
        Database.executeBatch(new LeaveStatusBatch(), BATCH_SIZE);
    }
}
