/**
 * Geracao e manutencao dos periodos aquisitivos (CLT art. 130 e 134). Para cada colaborador CLT que nao foi
 * desligado, gera todos os periodos desde a admissao ate o atual, calcula o direito pela tabela de faltas
 * (HR_Absence_Rule__mdt) e o status. Idempotente por Unique_Key__c: reexecutar nao duplica; so grava o que mudou.
 *
 * Contexto de sistema (spec 02): a geracao diaria precisa ler e gravar os periodos de todos os colaboradores.
 * Por isso a classe e without sharing e os registros ficam fora do alcance do usuario que executa o lote.
 */
// Contexto de sistema documentado na spec 02 (LeaveAccrualService); DML parcial para tolerar corrida entre execucoes.
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class LeaveAccrualService {
    public static final Integer LOST_THRESHOLD = 32;
    public static final Integer MAX_PERIODS_PER_EMPLOYEE = 60;

    @TestVisible
    private static List<HR_Absence_Rule__mdt> testRules;

    public class Summary {
        public Integer created = 0;
        public Integer updated = 0;
        public Integer errors = 0;
        public Integer employees = 0;
    }

    // ------------------------------------------------------------------------------------------ regras puras

    /** Dias de direito pela tabela do art. 130. Acima de 32 faltas: 0 (perde o direito ao periodo). */
    public static Integer entitledDays(Integer absences) {
        Integer count = absences == null ? 0 : absences;
        if (count > LOST_THRESHOLD) {
            return 0;
        }
        List<HR_Absence_Rule__mdt> rules = testRules != null ? testRules : HR_Absence_Rule__mdt.getAll().values();
        for (HR_Absence_Rule__mdt rule : rules) {
            if (count >= rule.Min_Absences__c && count <= rule.Max_Absences__c) {
                return rule.Leave_Days__c.intValue();
            }
        }
        return 0;
    }

    /**
     * Status do periodo (R4). balance e o saldo (direito menos gozados, vendidos e pendentes).
     */
    public static String statusFor(
        Integer absences,
        Date endDate,
        Date concessionDeadline,
        Decimal balance,
        Date today,
        Integer warningDays
    ) {
        if (absences != null && absences > LOST_THRESHOLD) {
            return 'Perdido';
        }
        if (today <= endDate) {
            return 'Em_Aquisicao';
        }
        if (balance == null || balance <= 0) {
            return 'Concluido';
        }
        if (concessionDeadline != null && today.daysBetween(concessionDeadline) <= warningDays) {
            return 'Prazo_Proximo';
        }
        return 'Disponivel';
    }

    /** Fim do periodo que comeca em startDate: inicio mais N meses menos um dia. */
    public static Date periodEndDate(Date hireDate, Integer index, Integer months) {
        return hireDate.addMonths((index + 1) * months).addDays(-1);
    }

    public static String uniqueKey(String employeeNumber, Date startDate) {
        return employeeNumber + '|' + String.valueOf(startDate);
    }

    // ------------------------------------------------------------------------------------------ geracao

    public static Summary generateForEmployeeIds(Set<Id> employeeIds, Date today) {
        List<Employee__c> employees = [
            SELECT Id, Employee_Number__c, Hire_Date__c, Status__c, Employment_Type__c
            FROM Employee__c
            WHERE Id IN :employeeIds
        ];
        return generate(employees, today);
    }

    /** Gera e atualiza os periodos dos colaboradores informados (apenas CLT e nao desligados). */
    public static Summary generate(List<Employee__c> employees, Date today) {
        Summary summary = new Summary();
        List<Employee__c> eligible = new List<Employee__c>();
        Set<Id> ids = new Set<Id>();
        for (Employee__c e : employees) {
            if (isEligible(e, today)) {
                eligible.add(e);
                ids.add(e.Id);
            }
        }
        summary.employees = eligible.size();
        if (eligible.isEmpty()) {
            return summary;
        }
        HR_Setting__mdt settings = HrSettings.get();
        Integer months = settings.Accrual_Period_Months__c == null ? 12 : settings.Accrual_Period_Months__c.intValue();
        Integer warningDays = settings.Concession_Warning_Days__c == null ? 60 : settings.Concession_Warning_Days__c.intValue();

        Map<String, Leave_Accrual_Period__c> existingByKey = new Map<String, Leave_Accrual_Period__c>();
        for (Leave_Accrual_Period__c p : LeaveAccrualPeriodSelector.byEmployeesSystem(ids)) {
            existingByKey.put(p.Unique_Key__c, p);
        }

        List<Leave_Accrual_Period__c> toInsert = new List<Leave_Accrual_Period__c>();
        List<Leave_Accrual_Period__c> toUpdate = new List<Leave_Accrual_Period__c>();
        for (Employee__c e : eligible) {
            Integer index = 0;
            Date periodStart = e.Hire_Date__c;
            while (periodStart <= today && index < MAX_PERIODS_PER_EMPLOYEE) {
                Date periodFinish = periodEndDate(e.Hire_Date__c, index, months);
                String key = uniqueKey(e.Employee_Number__c, periodStart);
                Leave_Accrual_Period__c existing = existingByKey.get(key);
                planPeriod(e, periodStart, periodFinish, key, existing, today, warningDays, toInsert, toUpdate);
                index++;
                periodStart = e.Hire_Date__c.addMonths(index * months);
            }
        }
        save(toInsert, toUpdate, summary);
        return summary;
    }

    private static Boolean isEligible(Employee__c e, Date today) {
        return e.Employment_Type__c == 'CLT' &&
            e.Status__c != 'Desligado' &&
            e.Hire_Date__c != null &&
            e.Employee_Number__c != null &&
            e.Hire_Date__c <= today;
    }

    private static void planPeriod(
        Employee__c e,
        Date periodStart,
        Date periodEnd,
        String key,
        Leave_Accrual_Period__c existing,
        Date today,
        Integer warningDays,
        List<Leave_Accrual_Period__c> toInsert,
        List<Leave_Accrual_Period__c> toUpdate
    ) {
        Integer absences = existing == null || existing.Unjustified_Absences__c == null
            ? 0
            : existing.Unjustified_Absences__c.intValue();
        Integer entitled = entitledDays(absences);
        Date deadline = periodEnd.addMonths(12);
        Decimal consumed = 0;
        if (existing != null) {
            consumed = nz(existing.Days_Taken__c) + nz(existing.Days_Sold__c) + nz(existing.Days_Pending__c);
        }
        String status = statusFor(absences, periodEnd, deadline, entitled - consumed, today, warningDays);
        if (existing == null) {
            toInsert.add(
                new Leave_Accrual_Period__c(
                    Employee__c = e.Id,
                    Start_Date__c = periodStart,
                    End_Date__c = periodEnd,
                    Concession_Deadline__c = deadline,
                    Unjustified_Absences__c = 0,
                    Entitled_Days__c = entitled,
                    Status__c = status,
                    Unique_Key__c = key
                )
            );
        } else if (
            existing.Entitled_Days__c != entitled ||
            existing.Status__c != status ||
            existing.Concession_Deadline__c != deadline ||
            existing.End_Date__c != periodEnd
        ) {
            toUpdate.add(
                new Leave_Accrual_Period__c(
                    Id = existing.Id,
                    End_Date__c = periodEnd,
                    Concession_Deadline__c = deadline,
                    Entitled_Days__c = entitled,
                    Status__c = status
                )
            );
        }
    }

    private static void save(List<Leave_Accrual_Period__c> toInsert, List<Leave_Accrual_Period__c> toUpdate, Summary summary) {
        // Os handlers de trigger recalculam direito e status a partir dos mesmos dados; aqui ja vem calculado.
        TriggerHandler.bypass('LeaveAccrualPeriodTriggerHandler');
        try {
            count(Database.insert(toInsert, false), summary, true);
            count(Database.update(toUpdate, false), summary, false);
        } finally {
            TriggerHandler.clearBypass('LeaveAccrualPeriodTriggerHandler');
        }
    }

    private static void count(List<Database.SaveResult> results, Summary summary, Boolean inserted) {
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                if (inserted) {
                    summary.created++;
                } else {
                    summary.updated++;
                }
            } else {
                summary.errors++;
                System.debug(LoggingLevel.WARN, 'Periodo aquisitivo nao gravado: ' + r.getErrors());
            }
        }
    }

    private static Decimal nz(Decimal value) {
        return value == null ? 0 : value;
    }
}
