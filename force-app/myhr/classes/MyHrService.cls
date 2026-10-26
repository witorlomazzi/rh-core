/**
 * Regra do Meu RH: monta o contexto do usuario atual (colaborador, gestor, RH) e a visao da equipe direta. Nao
 * duplica regra de outros modulos: so le e compoe. Leituras em USER_MODE pelos selectors; sem contexto de sistema.
 */
public inherited sharing class MyHrService {
    private static final Map<String, String> EMPLOYEE_STATUS = new Map<String, String>{
        'Pre_Admissao' => 'Pré-admissão',
        'Ativo' => 'Ativo',
        'Ferias' => 'De férias',
        'Afastado' => 'Afastado',
        'Desligado' => 'Desligado'
    };
    private static final Map<String, String> LEAVE_STATUS = new Map<String, String>{
        'Pendente' => 'Pendente',
        'Aprovado' => 'Aprovado',
        'Em_Gozo' => 'Em gozo'
    };
    private static final Set<String> OPEN_PERIODS = new Set<String>{ 'Disponivel', 'Prazo_Proximo' };

    public static final String NOT_LINKED = 'Seu usuário ainda não está vinculado a um colaborador. Fale com o RH.';

    public class LeaveView {
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public Integer days;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String statusLabel;
    }

    public class Context {
        /** Usuario vinculado a um colaborador. */
        @AuraEnabled
        public Boolean linked = false;
        @AuraEnabled
        public Boolean isManager = false;
        @AuraEnabled
        public Boolean isHr = false;
        @AuraEnabled
        public String emptyMessage;
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public String initials;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public String departmentName;
        @AuraEnabled
        public Id managerId;
        @AuraEnabled
        public String managerName;
        @AuraEnabled
        public Date hireDate;
        @AuraEnabled
        public Integer tenureMonths;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String statusLabel;
        @AuraEnabled
        public Integer directReports = 0;
        @AuraEnabled
        public Boolean hasOnboardingPlan = false;
        @AuraEnabled
        public Id onboardingPlanId;
        @AuraEnabled
        public LeaveView nextLeave;
    }

    public class TeamMember {
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String initials;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String statusLabel;
        @AuraEnabled
        public Integer balanceDays = 0;
        @AuraEnabled
        public Boolean hasOpenPeriod = false;
        @AuraEnabled
        public LeaveView nextLeave;
        /** Prazo concessivo mais proximo entre os periodos com saldo; nulo se nao houver. */
        @AuraEnabled
        public Date concessionDeadline;
        @AuraEnabled
        public Integer daysToDeadline;
        /** Verdadeiro quando ha saldo e o prazo vence dentro da janela de alerta (ou ja venceu). */
        @AuraEnabled
        public Boolean deadlineAlert = false;
        @AuraEnabled
        public Boolean deadlineOverdue = false;
    }

    public class TeamOverview {
        @AuraEnabled
        public Boolean isManager = false;
        @AuraEnabled
        public String emptyMessage;
        @AuraEnabled
        public Integer alertCount = 0;
        @AuraEnabled
        public List<TeamMember> members = new List<TeamMember>();
    }

    public class ReviewRow {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String cycleName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Decimal finalRating;
        @AuraEnabled
        public Datetime releasedDate;
    }

    /** Contexto do usuario atual em uma unica chamada. */
    public static Context buildContext() {
        Context ctx = new Context();
        ctx.isHr = FeatureManagement.checkPermission('HR_Admin_Access');
        Employee__c me = EmployeeSelector.currentUserEmployee();
        if (me == null) {
            ctx.emptyMessage = NOT_LINKED;
            return ctx;
        }
        ctx.linked = true;
        ctx.employeeId = me.Id;
        ctx.employeeName = me.Name;
        ctx.initials = initialsOf(me.Name);
        ctx.positionName = me.Position__r == null ? null : me.Position__r.Name;
        ctx.departmentName = me.Department__r == null ? null : me.Department__r.Name;
        ctx.managerId = me.Manager__c;
        ctx.managerName = me.Manager__r == null ? null : me.Manager__r.Name;
        ctx.hireDate = me.Hire_Date__c;
        ctx.tenureMonths = tenureMonths(me.Hire_Date__c, Date.today());
        ctx.status = me.Status__c;
        ctx.statusLabel = label(EMPLOYEE_STATUS, me.Status__c);
        ctx.directReports = me.Direct_Reports_Count__c == null ? 0 : me.Direct_Reports_Count__c.intValue();
        ctx.isManager = ctx.directReports > 0;

        Onboarding_Plan__c plan = MyHrSelector.onboardingPlan(me.Id);
        ctx.hasOnboardingPlan = plan != null;
        ctx.onboardingPlanId = plan == null ? null : plan.Id;

        List<Leave_Request__c> upcoming = MyHrSelector.upcomingLeave(new Set<Id>{ me.Id }, Date.today());
        ctx.nextLeave = upcoming.isEmpty() ? null : leaveView(upcoming[0]);
        return ctx;
    }

    /** Equipe direta do usuario atual com saldo, proximas ferias e alerta de prazo concessivo. */
    public static TeamOverview teamOverview() {
        TeamOverview view = new TeamOverview();
        Employee__c me = EmployeeSelector.currentUserEmployee();
        if (me == null) {
            view.emptyMessage = NOT_LINKED;
            return view;
        }
        List<Employee__c> team = new List<Employee__c>();
        for (Employee__c e : EmployeeSelector.directReports(me.Id)) {
            if (e.Status__c != 'Desligado') {
                team.add(e);
            }
        }
        view.isManager = !team.isEmpty();
        if (team.isEmpty()) {
            view.emptyMessage = 'Você não tem pessoas na sua equipe direta.';
            return view;
        }
        Set<Id> ids = new Map<Id, Employee__c>(team).keySet();
        Date today = Date.today();
        Integer warningDays = warningDays();

        Map<Id, LeaveView> nextByEmployee = new Map<Id, LeaveView>();
        for (Leave_Request__c r : MyHrSelector.upcomingLeave(ids, today)) {
            if (!nextByEmployee.containsKey(r.Employee__c)) {
                nextByEmployee.put(r.Employee__c, leaveView(r));
            }
        }
        Map<Id, List<Leave_Accrual_Period__c>> periodsByEmployee = new Map<Id, List<Leave_Accrual_Period__c>>();
        for (Leave_Accrual_Period__c p : MyHrSelector.periods(ids)) {
            if (!periodsByEmployee.containsKey(p.Employee__c)) {
                periodsByEmployee.put(p.Employee__c, new List<Leave_Accrual_Period__c>());
            }
            periodsByEmployee.get(p.Employee__c).add(p);
        }
        for (Employee__c e : team) {
            TeamMember m = new TeamMember();
            m.employeeId = e.Id;
            m.name = e.Name;
            m.initials = initialsOf(e.Name);
            m.positionName = e.Position__r == null ? null : e.Position__r.Name;
            m.status = e.Status__c;
            m.statusLabel = label(EMPLOYEE_STATUS, e.Status__c);
            m.nextLeave = nextByEmployee.get(e.Id);
            applyPeriods(m, periodsByEmployee.get(e.Id), today, warningDays);
            if (m.deadlineAlert) {
                view.alertCount++;
            }
            view.members.add(m);
        }
        return view;
    }

    /** Avaliacoes do colaborador que o usuario pode ler (aba Desempenho do registro). */
    public static List<ReviewRow> reviews(Id employeeId) {
        List<ReviewRow> rows = new List<ReviewRow>();
        if (employeeId == null) {
            return rows;
        }
        for (Performance_Review__c r : MyHrSelector.reviews(employeeId)) {
            ReviewRow row = new ReviewRow();
            row.id = r.Id;
            row.cycleName = r.Review_Cycle__r == null ? null : r.Review_Cycle__r.Name;
            row.status = r.Status__c;
            row.finalRating = r.Final_Rating__c;
            row.releasedDate = r.Released_Date__c;
            rows.add(row);
        }
        return rows;
    }

    // ------------------------------------------------------------------------------------------------ apoio

    private static void applyPeriods(TeamMember m, List<Leave_Accrual_Period__c> periods, Date today, Integer warningDays) {
        if (periods == null) {
            return;
        }
        Decimal balance = 0;
        for (Leave_Accrual_Period__c p : periods) {
            if (!OPEN_PERIODS.contains(p.Status__c)) {
                continue;
            }
            Decimal days = p.Balance_Days__c == null ? 0 : p.Balance_Days__c;
            balance += days;
            m.hasOpenPeriod = true;
            // periods vem ordenado por prazo: o primeiro com saldo e o mais urgente
            if (days > 0 && m.concessionDeadline == null && p.Concession_Deadline__c != null) {
                m.concessionDeadline = p.Concession_Deadline__c;
            }
        }
        m.balanceDays = balance.intValue();
        if (m.concessionDeadline != null) {
            m.daysToDeadline = today.daysBetween(m.concessionDeadline);
            m.deadlineOverdue = m.daysToDeadline < 0;
            m.deadlineAlert = m.daysToDeadline <= warningDays;
        }
    }

    private static Integer warningDays() {
        Decimal configured = HrSettings.get().Concession_Warning_Days__c;
        return configured == null ? 60 : configured.intValue();
    }

    private static LeaveView leaveView(Leave_Request__c r) {
        LeaveView v = new LeaveView();
        v.startDate = r.Start_Date__c;
        v.endDate = r.End_Date__c;
        v.days = r.Days__c == null ? null : r.Days__c.intValue();
        v.status = r.Status__c;
        v.statusLabel = label(LEAVE_STATUS, r.Status__c);
        return v;
    }

    private static String label(Map<String, String> labels, String apiValue) {
        return labels.containsKey(apiValue) ? labels.get(apiValue) : apiValue;
    }

    /** Meses completos entre a admissao e a data de referencia (zero se a data for nula ou futura). */
    @TestVisible
    private static Integer tenureMonths(Date hireDate, Date reference) {
        if (hireDate == null || hireDate > reference) {
            return 0;
        }
        Integer months = (reference.year() - hireDate.year()) * 12 + reference.month() - hireDate.month();
        if (reference.day() < hireDate.day()) {
            months--;
        }
        return months < 0 ? 0 : months;
    }

    @TestVisible
    private static String initialsOf(String fullName) {
        if (String.isBlank(fullName)) {
            return '';
        }
        List<String> parts = fullName.trim().split('\\s+');
        String first = parts[0].left(1);
        String last = parts.size() > 1 ? parts[parts.size() - 1].left(1) : '';
        return (first + last).toUpperCase();
    }
}
