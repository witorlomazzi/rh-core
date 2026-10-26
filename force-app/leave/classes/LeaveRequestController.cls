/**
 * Controller fino dos componentes de ferias (leaveBalanceCard, leaveRequestForm, leaveRequestList). Toda a regra de
 * negocio esta em LeaveRequestService, LeaveRuleEngine e nos selectors; aqui so converte em DTOs para as telas e
 * transforma erros de negocio em mensagens claras (AuraHandledException).
 */
public with sharing class LeaveRequestController {
    private static final Map<String, String> PERIOD_STATUS = new Map<String, String>{
        'Em_Aquisicao' => 'Em aquisição',
        'Disponivel' => 'Disponível',
        'Prazo_Proximo' => 'Prazo próximo',
        'Concluido' => 'Concluído',
        'Perdido' => 'Perdido'
    };
    private static final Map<String, String> REQUEST_STATUS = new Map<String, String>{
        'Rascunho' => 'Rascunho',
        'Pendente' => 'Pendente',
        'Aprovado' => 'Aprovado',
        'Rejeitado' => 'Rejeitado',
        'Cancelado' => 'Cancelado',
        'Em_Gozo' => 'Em gozo',
        'Concluido' => 'Concluído'
    };

    // ------------------------------------------------------------------------------------------------ DTOs

    public class PeriodView {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public Date concessionDeadline;
        @AuraEnabled
        public Integer daysToDeadline;
        @AuraEnabled
        public Integer absences;
        @AuraEnabled
        public Integer entitledDays;
        @AuraEnabled
        public Integer daysTaken;
        @AuraEnabled
        public Integer daysSold;
        @AuraEnabled
        public Integer daysPending;
        @AuraEnabled
        public Integer balanceDays;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String statusLabel;
        @AuraEnabled
        public Boolean canRequest;

        public PeriodView(Leave_Accrual_Period__c p) {
            this.id = p.Id;
            this.name = p.Name;
            this.startDate = p.Start_Date__c;
            this.endDate = p.End_Date__c;
            this.concessionDeadline = p.Concession_Deadline__c;
            this.daysToDeadline = p.Concession_Deadline__c == null ? null : Date.today().daysBetween(p.Concession_Deadline__c);
            this.absences = whole(p.Unjustified_Absences__c);
            this.entitledDays = whole(p.Entitled_Days__c);
            this.daysTaken = whole(p.Days_Taken__c);
            this.daysSold = whole(p.Days_Sold__c);
            this.daysPending = whole(p.Days_Pending__c);
            this.balanceDays = whole(p.Balance_Days__c);
            this.status = p.Status__c;
            this.statusLabel = PERIOD_STATUS.containsKey(p.Status__c) ? PERIOD_STATUS.get(p.Status__c) : p.Status__c;
            this.canRequest = (p.Status__c == 'Disponivel' || p.Status__c == 'Prazo_Proximo') && this.balanceDays > 0;
        }
    }

    public class BalanceView {
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public List<PeriodView> periods = new List<PeriodView>();
        @AuraEnabled
        public String emptyMessage;
        /** Verdadeiro para o RH: libera a excecao de antecedencia no formulario. */
        @AuraEnabled
        public Boolean isHr = false;
    }

    public class RuleView {
        @AuraEnabled
        public String code;
        @AuraEnabled
        public String title;
        /** ok, warning ou blocked */
        @AuraEnabled
        public String level;
        @AuraEnabled
        public String message;

        public RuleView(String code, String level, String message) {
            this.code = code;
            this.title = LeaveRuleEngine.RULE_TITLES.get(code);
            this.level = level;
            this.message = message;
        }
    }

    public class CheckView {
        @AuraEnabled
        public List<RuleView> rules = new List<RuleView>();
        @AuraEnabled
        public Boolean hasBlocking = false;
        @AuraEnabled
        public Boolean hasWarning = false;
        @AuraEnabled
        public Boolean canSubmit = false;
        @AuraEnabled
        public Boolean submitted = false;
        @AuraEnabled
        public Id requestId;
        @AuraEnabled
        public Boolean isHr = false;
    }

    public class RequestView {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String periodName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String statusLabel;
        @AuraEnabled
        public String awaitingLabel;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public Integer days;
        @AuraEnabled
        public Integer soldDays;
        @AuraEnabled
        public String notes;
        @AuraEnabled
        public String teamConflictWarning;
        @AuraEnabled
        public Boolean canCancel;

        public RequestView(Leave_Request__c r) {
            this.id = r.Id;
            this.name = r.Name;
            this.periodName = r.Accrual_Period__r == null ? null : r.Accrual_Period__r.Name;
            this.status = r.Status__c;
            this.statusLabel = REQUEST_STATUS.containsKey(r.Status__c) ? REQUEST_STATUS.get(r.Status__c) : r.Status__c;
            this.awaitingLabel = LeaveRequestService.awaitingLabel(r.Status__c, r.Current_Step__c);
            this.startDate = r.Start_Date__c;
            this.endDate = r.End_Date__c;
            this.days = whole(r.Days__c);
            this.soldDays = whole(r.Sold_Days__c);
            this.notes = r.Notes__c;
            this.teamConflictWarning = r.Team_Conflict_Warning__c;
            this.canCancel = r.Status__c == 'Pendente' || r.Status__c == 'Rascunho';
        }
    }

    // ------------------------------------------------------------------------------------------------ saldo

    /** Periodos do colaborador informado ou, sem parametro, do usuario atual. */
    @AuraEnabled
    public static BalanceView getBalance(Id employeeId) {
        try {
            BalanceView view = new BalanceView();
            view.isHr = LeaveRequestService.isHrAdmin();
            Employee__c employee = resolveEmployee(employeeId);
            if (employee == null) {
                view.emptyMessage = 'Seu usuário ainda não está vinculado a um colaborador.';
                return view;
            }
            view.employeeId = employee.Id;
            view.employeeName = employee.Name;
            for (Leave_Accrual_Period__c p : LeaveAccrualPeriodSelector.byEmployee(employee.Id)) {
                view.periods.add(new PeriodView(p));
            }
            if (view.periods.isEmpty()) {
                view.emptyMessage = 'Nenhum período aquisitivo encontrado.';
            }
            return view;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    // ------------------------------------------------------------------------------------------------ regras

    /** Mostra cada regra (ok, aviso ou bloqueio) antes do envio. Nao grava nada. */
    @AuraEnabled
    public static CheckView checkRules(Id periodId, Date startDate, Integer days, Integer soldDays, Boolean allowNoticeException) {
        try {
            List<LeaveRuleResult> results = LeaveRequestService.check(periodId, startDate, days, soldDays, null, allowNoticeException);
            return toCheckView(results, false, null);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /**
     * Cria o rascunho e envia para aprovacao. Se o motor bloquear, nada fica gravado e a tela recebe as regras
     * violadas (a verificacao anterior e repetida porque a situacao pode ter mudado).
     */
    @AuraEnabled
    public static CheckView submitRequest(
        Id periodId,
        Date startDate,
        Integer days,
        Integer soldDays,
        String notes,
        Boolean allowNoticeException
    ) {
        Savepoint sp = Database.setSavepoint();
        try {
            Leave_Request__c draft = LeaveRequestService.createDraft(periodId, startDate, days, soldDays, notes);
            LeaveRequestService.SubmitResult result = LeaveRequestService.submit(draft.Id, allowNoticeException);
            if (!result.submitted) {
                Database.rollback(sp);
                return toCheckView(result.results, false, null);
            }
            return toCheckView(result.results, true, draft.Id);
        } catch (Exception e) {
            Database.rollback(sp);
            throw toAura(e);
        }
    }

    // ------------------------------------------------------------------------------------------------ pedidos

    @AuraEnabled
    public static List<RequestView> getRequests(Id employeeId) {
        try {
            List<RequestView> views = new List<RequestView>();
            Employee__c employee = resolveEmployee(employeeId);
            if (employee == null) {
                return views;
            }
            for (Leave_Request__c r : LeaveRequestSelector.byEmployee(employee.Id)) {
                views.add(new RequestView(r));
            }
            return views;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static void cancelRequest(Id requestId) {
        try {
            LeaveRequestService.cancel(requestId);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    // ------------------------------------------------------------------------------------------------ apoio

    private static Employee__c resolveEmployee(Id employeeId) {
        if (employeeId == null) {
            return EmployeeSelector.currentUserEmployee();
        }
        List<Employee__c> rows = EmployeeSelector.byIds(new Set<Id>{ employeeId });
        return rows.isEmpty() ? null : rows[0];
    }

    private static CheckView toCheckView(List<LeaveRuleResult> results, Boolean submitted, Id requestId) {
        CheckView view = new CheckView();
        view.isHr = LeaveRequestService.isHrAdmin();
        view.submitted = submitted;
        view.requestId = requestId;
        Map<String, LeaveRuleResult> byCode = new Map<String, LeaveRuleResult>();
        for (LeaveRuleResult r : results) {
            byCode.put(r.code, r);
        }
        if (byCode.containsKey(LeaveRuleEngine.R_DADOS)) {
            // Entrada incompleta: so a mensagem, sem listar regras como "ok".
            LeaveRuleResult invalid = byCode.get(LeaveRuleEngine.R_DADOS);
            RuleView dataRule = new RuleView(invalid.code, 'blocked', invalid.message);
            dataRule.title = 'Dados do pedido';
            view.rules.add(dataRule);
            view.hasBlocking = true;
            return view;
        }
        for (String code : LeaveRuleEngine.RULE_CODES) {
            LeaveRuleResult r = byCode.get(code);
            if (r == null) {
                view.rules.add(new RuleView(code, 'ok', null));
            } else if (r.blocking) {
                view.rules.add(new RuleView(code, 'blocked', r.message));
                view.hasBlocking = true;
            } else {
                view.rules.add(new RuleView(code, 'warning', r.message));
                view.hasWarning = true;
            }
        }
        view.canSubmit = !view.hasBlocking;
        return view;
    }

    private static Integer whole(Decimal value) {
        return value == null ? 0 : value.intValue();
    }

    private static AuraHandledException toAura(Exception e) {
        String message = e.getMessage();
        if (e instanceof DmlException && ((DmlException) e).getNumDml() > 0) {
            message = ((DmlException) e).getDmlMessage(0);
        }
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
