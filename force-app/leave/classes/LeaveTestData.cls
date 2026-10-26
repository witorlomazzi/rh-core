/**
 * Apoio dos testes do modulo de ferias: datas validas para o motor de regras e criacao de periodos e solicitacoes
 * em contexto de sistema. Dados com prefixo ZZTEST- vem do HrTestDataFactory do core.
 */
@IsTest
public class LeaveTestData {
    /** Primeira data a partir de fromDate que cai no dia da semana informado (0 = domingo ... 6 = sabado). */
    public static Date nextWeekday(Date fromDate, Integer dow) {
        Date d = fromDate;
        while (HrDateUtils.dayOfWeek(d) != dow) {
            d = d.addDays(1);
        }
        return d;
    }

    /** Uma segunda-feira com 45 dias ou mais de antecedencia: passa nas regras de aviso e de descanso. */
    public static Date validMonday() {
        return nextWeekday(Date.today().addDays(45), 1);
    }

    /** Gera os periodos aquisitivos dos colaboradores (contexto de sistema, como o lote diario). */
    public static void generatePeriods(Set<Id> employeeIds) {
        LeaveAccrualService.generateForEmployeeIds(employeeIds, Date.today());
    }

    /** Periodo mais antigo do colaborador (ja adquirido nos dados padrao da fabrica, admissao ha 1 ano). */
    public static Leave_Accrual_Period__c firstPeriod(Id employeeId) {
        return [
            SELECT
                Id, Employee__c, Start_Date__c, End_Date__c, Concession_Deadline__c, Entitled_Days__c, Status__c,
                Days_Taken__c, Days_Pending__c, Days_Sold__c, Balance_Days__c, Unjustified_Absences__c
            FROM Leave_Accrual_Period__c
            WHERE Employee__c = :employeeId
            ORDER BY Start_Date__c
            LIMIT 1
        ];
    }

    public static Leave_Accrual_Period__c reloadPeriod(Id periodId) {
        return [
            SELECT
                Id, Entitled_Days__c, Status__c, Days_Taken__c, Days_Pending__c, Days_Sold__c, Balance_Days__c,
                Unjustified_Absences__c, Concession_Deadline__c
            FROM Leave_Accrual_Period__c
            WHERE Id = :periodId
        ];
    }

    /** Insere uma solicitacao em contexto de sistema com o status informado (nao passa pelo motor de regras). */
    public static Leave_Request__c insertRequest(Id periodId, Date startDate, Integer days, Integer soldDays, String status) {
        Leave_Request__c r = new Leave_Request__c(
            Accrual_Period__c = periodId,
            Start_Date__c = startDate,
            Days__c = days,
            Sold_Days__c = soldDays,
            Status__c = status
        );
        insert r;
        return r;
    }

    public static Leave_Request__c reloadRequest(Id requestId) {
        return [
            SELECT
                Id, Name, Employee__c, Status__c, Current_Step__c, Requested_By__c, Rule_Check_Result__c,
                Team_Conflict_Warning__c, Start_Date__c, End_Date__c, Days__c, Sold_Days__c, Notes__c
            FROM Leave_Request__c
            WHERE Id = :requestId
        ];
    }
}
