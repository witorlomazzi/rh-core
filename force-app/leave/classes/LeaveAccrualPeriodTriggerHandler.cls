/**
 * Regras de Leave_Accrual_Period__c mantidas por Apex: fim do prazo concessivo e direito pela tabela de faltas.
 * Na insercao so preenche o que veio vazio (a carga de dados pode informar o direito); na edicao recalcula o direito
 * quando o RH altera as faltas, e marca o periodo como Perdido acima de 32 faltas.
 */
public with sharing class LeaveAccrualPeriodTriggerHandler extends TriggerHandler {
    public static final String DATES_MESSAGE = 'O fim do período aquisitivo não pode ser anterior ao início.';

    private List<Leave_Accrual_Period__c> newList;
    private Map<Id, Leave_Accrual_Period__c> oldMap;

    public LeaveAccrualPeriodTriggerHandler() {
        this.newList = (List<Leave_Accrual_Period__c>) Trigger.new;
        this.oldMap = (Map<Id, Leave_Accrual_Period__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        for (Leave_Accrual_Period__c p : newList) {
            validateDates(p);
            if (p.Concession_Deadline__c == null && p.End_Date__c != null) {
                p.Concession_Deadline__c = p.End_Date__c.addMonths(12);
            }
            if (p.Entitled_Days__c == null) {
                p.Entitled_Days__c = LeaveAccrualService.entitledDays(absencesOf(p));
            }
            if (absencesOf(p) > LeaveAccrualService.LOST_THRESHOLD) {
                p.Entitled_Days__c = 0;
                p.Status__c = 'Perdido';
            }
        }
    }

    protected override void beforeUpdate() {
        for (Leave_Accrual_Period__c p : newList) {
            Leave_Accrual_Period__c old = oldMap.get(p.Id);
            validateDates(p);
            if (p.End_Date__c != old.End_Date__c && p.End_Date__c != null) {
                p.Concession_Deadline__c = p.End_Date__c.addMonths(12);
            }
            if (absencesOf(p) != absencesOf(old)) {
                applyAbsences(p, old);
            }
        }
    }

    private void applyAbsences(Leave_Accrual_Period__c p, Leave_Accrual_Period__c old) {
        Integer absences = absencesOf(p);
        p.Entitled_Days__c = LeaveAccrualService.entitledDays(absences);
        if (absences > LeaveAccrualService.LOST_THRESHOLD) {
            p.Status__c = 'Perdido';
        } else if (old.Status__c == 'Perdido') {
            // Voltou a ter direito: o status certo sai dos dados do periodo; o lote diario ajusta o resto.
            HR_Setting__mdt settings = HrSettings.get();
            Integer warningDays = settings.Concession_Warning_Days__c == null ? 60 : settings.Concession_Warning_Days__c.intValue();
            p.Status__c = LeaveAccrualService.statusFor(
                absences,
                p.End_Date__c,
                p.Concession_Deadline__c,
                p.Entitled_Days__c,
                Date.today(),
                warningDays
            );
        }
    }

    private void validateDates(Leave_Accrual_Period__c p) {
        if (p.Start_Date__c != null && p.End_Date__c != null && p.End_Date__c < p.Start_Date__c) {
            p.End_Date__c.addError(DATES_MESSAGE);
        }
    }

    private static Integer absencesOf(Leave_Accrual_Period__c p) {
        return p.Unjustified_Absences__c == null ? 0 : p.Unjustified_Absences__c.intValue();
    }
}
