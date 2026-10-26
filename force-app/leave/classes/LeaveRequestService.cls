/**
 * Solicitacao de ferias: verificar regras, criar o rascunho, enviar para aprovacao e cancelar.
 *
 * Quem pode agir: o proprio colaborador do periodo ou o RH (custom permission HR_Admin_Access). Leituras em
 * USER_MODE; a criacao do rascunho e feita como o usuario (as user). As gravacoes de Rule_Check_Result__c,
 * Team_Conflict_Warning__c e do status de cancelamento de rascunho sao feitas pela classe Privileged, em contexto
 * de sistema, porque colaborador e gestor nao tem Edit nesses campos (spec 02, item 5); antes disso o servico
 * valida quem esta agindo.
 */
public with sharing class LeaveRequestService {
    public static final String HR_PERMISSION = 'HR_Admin_Access';

    public class LeaveException extends Exception {
    }

    /** Resultado do envio: as regras avaliadas e se o pedido foi para a aprovacao. */
    public class SubmitResult {
        public Id requestId;
        public Boolean submitted = false;
        public List<LeaveRuleResult> results = new List<LeaveRuleResult>();
    }

    // ------------------------------------------------------------------------------------------------ API

    /** Verdadeiro se o usuario atual e do RH (permissao personalizada dos permission sets *_Admin). */
    public static Boolean isHrAdmin() {
        return FeatureManagement.checkPermission(HR_PERMISSION);
    }

    /**
     * Roda o motor de regras para um pedido ainda nao gravado (ou um rascunho existente, se requestId vier
     * preenchido). Nao grava nada. A excecao de antecedencia so vale para o RH.
     */
    public static List<LeaveRuleResult> check(
        Id periodId,
        Date startDate,
        Integer days,
        Integer soldDays,
        Id requestId,
        Boolean allowNoticeException
    ) {
        Leave_Accrual_Period__c period = loadPeriod(periodId);
        Employee__c employee = loadEmployee(period.Employee__c);
        assertCanAct(employee);
        LeaveRuleEngine.Context c = buildContext(period, employee, requestId, startDate, days, soldDays);
        c.allowNoticeException = allowNoticeException == true && isHrAdmin();
        return LeaveRuleEngine.evaluate(c);
    }

    /** Cria o rascunho como o usuario atual. */
    public static Leave_Request__c createDraft(Id periodId, Date startDate, Integer days, Integer soldDays, String notes) {
        Leave_Accrual_Period__c period = loadPeriod(periodId);
        Employee__c employee = loadEmployee(period.Employee__c);
        assertCanAct(employee);
        Leave_Request__c draft = new Leave_Request__c(
            Accrual_Period__c = periodId,
            Employee__c = period.Employee__c,
            Start_Date__c = startDate,
            Days__c = days,
            Sold_Days__c = soldDays == null ? 0 : soldDays,
            Notes__c = notes == null ? null : notes.left(255),
            Requested_By__c = UserInfo.getUserId()
        );
        insert as user draft;
        return draft;
    }

    /**
     * Revalida o rascunho, grava o resultado do motor e, sem bloqueios, envia para o ApprovalService.
     * Com bloqueio, o rascunho continua como esta e o resultado explica o motivo.
     */
    public static SubmitResult submit(Id requestId, Boolean allowNoticeException) {
        Leave_Request__c request = loadRequest(requestId);
        if (request.Status__c != 'Rascunho') {
            throw new LeaveException('Somente solicitações em rascunho podem ser enviadas para aprovação.');
        }
        Leave_Accrual_Period__c period = loadPeriod(request.Accrual_Period__c);
        Employee__c employee = loadEmployee(period.Employee__c);
        assertCanAct(employee);

        LeaveRuleEngine.Context c = buildContext(
            period,
            employee,
            requestId,
            request.Start_Date__c,
            request.Days__c == null ? null : request.Days__c.intValue(),
            request.Sold_Days__c == null ? 0 : request.Sold_Days__c.intValue()
        );
        c.allowNoticeException = allowNoticeException == true && isHrAdmin();
        List<LeaveRuleResult> results = LeaveRuleEngine.evaluate(c);

        SubmitResult out = new SubmitResult();
        out.requestId = requestId;
        out.results = results;
        new Privileged().saveCheck(requestId, serialize(results), teamWarning(results));
        if (LeaveRuleEngine.hasBlocking(results)) {
            return out;
        }
        ApprovalService.submit(requestId, 'Leave');
        out.submitted = true;
        return out;
    }

    /** Cancela um rascunho ou um pedido pendente. Somente quem fez a solicitacao (ou o RH). */
    public static void cancel(Id requestId) {
        Leave_Request__c request = loadRequest(requestId);
        if (request.Status__c == 'Pendente') {
            ApprovalService.cancel(requestId, 'Leave');
            return;
        }
        if (request.Status__c != 'Rascunho') {
            throw new LeaveException('Somente rascunhos e solicitações pendentes podem ser cancelados.');
        }
        Id requester = request.Requested_By__c != null ? request.Requested_By__c : request.CreatedById;
        if (requester != UserInfo.getUserId() && !isHrAdmin()) {
            throw new LeaveException('Somente quem fez a solicitação pode cancelá-la.');
        }
        new Privileged().setStatus(requestId, 'Cancelado');
    }

    /** Texto da etapa em que a solicitacao esta, a partir da configuracao de aprovacao. */
    public static String awaitingLabel(String status, Decimal currentStep) {
        if (status != 'Pendente') {
            return null;
        }
        String approverType;
        for (HR_Approval_Step__mdt s : HR_Approval_Step__mdt.getAll().values()) {
            if (s.Request_Type__c == 'Leave' && s.Active__c && currentStep != null && s.Step_Order__c == currentStep) {
                approverType = s.Approver_Type__c;
            }
        }
        if (approverType == 'Direct_Manager') {
            return 'Aguardando o gestor';
        }
        if (approverType == 'Second_Level_Manager') {
            return 'Aguardando o gestor de segundo nível';
        }
        if (approverType == 'HR_Team') {
            return 'Aguardando o RH';
        }
        return 'Aguardando aprovação';
    }

    // ------------------------------------------------------------------------------------------------ internos

    private static LeaveRuleEngine.Context buildContext(
        Leave_Accrual_Period__c period,
        Employee__c employee,
        Id requestId,
        Date startDate,
        Integer days,
        Integer soldDays
    ) {
        HR_Setting__mdt settings = HrSettings.get();
        LeaveRuleEngine.Context c = new LeaveRuleEngine.Context();
        c.period = period;
        c.settings = settings;
        c.today = Date.today();
        c.requestId = requestId;
        c.startDate = startDate;
        c.days = days;
        c.soldDays = soldDays;
        c.restDays = HrSettings.restDaysOfWeek();
        for (Leave_Request__c r : LeaveRequestSelector.openByEmployee(employee.Id)) {
            if (r.Accrual_Period__c == period.Id) {
                c.periodRequests.add(r);
            } else {
                c.otherPeriodRequests.add(r);
            }
        }
        if (startDate != null && days != null && days >= 1) {
            Integer blockDays = settings.Leave_Block_Days_Before_Rest__c == null ? 2 : settings.Leave_Block_Days_Before_Rest__c.intValue();
            c.holidays = HrDateUtils.holidaysBetween(startDate, startDate.addDays(blockDays), employee.Work_Location__c);
            c.teamRequests = LeaveRequestSelector.teamOverlaps(
                employee.Manager__c,
                employee.Id,
                startDate,
                startDate.addDays(days - 1)
            );
        }
        return c;
    }

    private static Leave_Accrual_Period__c loadPeriod(Id periodId) {
        List<Leave_Accrual_Period__c> rows = periodId == null
            ? new List<Leave_Accrual_Period__c>()
            : LeaveAccrualPeriodSelector.byIds(new Set<Id>{ periodId });
        if (rows.isEmpty()) {
            throw new LeaveException('Período aquisitivo não encontrado ou sem acesso.');
        }
        return rows[0];
    }

    private static Employee__c loadEmployee(Id employeeId) {
        List<Employee__c> rows = EmployeeSelector.byIds(new Set<Id>{ employeeId });
        if (rows.isEmpty()) {
            throw new LeaveException('Colaborador não encontrado ou sem acesso.');
        }
        return rows[0];
    }

    private static Leave_Request__c loadRequest(Id requestId) {
        List<Leave_Request__c> rows = requestId == null ? new List<Leave_Request__c>() : LeaveRequestSelector.byId(requestId);
        if (rows.isEmpty()) {
            throw new LeaveException('Solicitação não encontrada ou sem acesso.');
        }
        return rows[0];
    }

    /** Somente o proprio colaborador ou o RH solicitam. O gestor enxerga a equipe, mas nao pede ferias por ela. */
    private static void assertCanAct(Employee__c employee) {
        if (employee.User__c != UserInfo.getUserId() && !isHrAdmin()) {
            throw new LeaveException('Somente o colaborador ou o RH pode solicitar férias para este período.');
        }
    }

    private static String serialize(List<LeaveRuleResult> results) {
        Map<String, Object> payload = new Map<String, Object>{
            'checkedAt' => System.now(),
            'blocking' => LeaveRuleEngine.hasBlocking(results),
            'results' => results
        };
        String payloadJson = JSON.serialize(payload);
        if (payloadJson.length() > 4000) {
            List<String> codes = new List<String>();
            for (LeaveRuleResult r : results) {
                codes.add(r.code);
            }
            payloadJson = JSON.serialize(new Map<String, Object>{ 'checkedAt' => System.now(), 'codes' => codes });
        }
        return payloadJson;
    }

    private static String teamWarning(List<LeaveRuleResult> results) {
        for (LeaveRuleResult r : results) {
            if (r.code == LeaveRuleEngine.R_V12) {
                return r.message.left(255);
            }
        }
        return null;
    }

    /** Gravacoes em contexto de sistema (ver comentario da classe). */
    // Campos somente leitura para o colaborador (spec 02, item 5); o servico valida quem age antes de chamar.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private without sharing class Privileged {
        void saveCheck(Id requestId, String resultJson, String warning) {
            update new Leave_Request__c(Id = requestId, Rule_Check_Result__c = resultJson, Team_Conflict_Warning__c = warning);
        }

        void setStatus(Id requestId, String status) {
            update new Leave_Request__c(Id = requestId, Status__c = status);
        }
    }
}
