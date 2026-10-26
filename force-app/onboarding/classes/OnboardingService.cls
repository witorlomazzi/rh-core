/**
 * Regras de admissao e onboarding (spec 15).
 *
 *  - createFromApplication (O1, O2, O3): candidatura Contratado vira colaborador em Pre-admissao, plano e tarefas
 *    geradas dos modelos de Onboarding_Task_Template__mdt. Idempotente: candidatura que ja tem colaborador e ignorada.
 *  - activate (O4): so o RH. Valida matricula unica, ativa o colaborador, cria o historico de admissao
 *    (PositionHistoryService.createAdmission) e coloca o plano em andamento.
 *  - setTaskDone (O5): so quem e o responsavel da tarefa ou o RH conclui. A mesma regra vale no trigger de tarefa.
 *  - recalculateDates / syncPlans (O6): refaz os prazos das tarefas pendentes a partir da data de admissao atual.
 *  - refreshPlanStatus (O5): plano vira Concluido quando nenhuma tarefa esta Pendente.
 *  - checklist / overview: dados dos LWCs.
 *
 * A classe e `with sharing`: leituras e escritas do usuario seguem compartilhamento e FLS. Contexto de sistema
 * (spec 02), isolado na classe interna Privileged e sempre depois da validacao da regra:
 *   1. createFromApplication: quem move a candidatura para Contratado (recrutador, gestor) nao cria colaborador nem
 *      plano, e nao le a candidatura de outros gestores;
 *   2. refreshPlanStatus: quem conclui a ultima tarefa (colaborador, gestor) nao edita o plano;
 *   3. conferir matricula duplicada em colaboradores fora do alcance do usuario.
 */
public with sharing class OnboardingService {
    public static final String HR_PERMISSION = 'HR_Admin_Access';

    public static final String ROLE_RH = 'RH';
    public static final String ROLE_MANAGER = 'Gestor';
    public static final String ROLE_IT = 'TI';
    public static final String ROLE_EMPLOYEE = 'Colaborador';

    public static final String TASK_PENDING = 'Pendente';
    public static final String TASK_DONE = 'Concluida';
    public static final String TASK_NOT_APPLICABLE = 'Nao_Aplicavel';

    public static final String PLAN_NOT_STARTED = 'Nao_Iniciado';
    public static final String PLAN_IN_PROGRESS = 'Em_Andamento';
    public static final String PLAN_DONE = 'Concluido';

    public static final String EMPLOYEE_PRE_ADMISSION = 'Pre_Admissao';
    public static final String EMPLOYEE_ACTIVE = 'Ativo';

    public static final String PROVISIONAL_PREFIX = 'PRE-';
    public static final Integer DEFAULT_LEAD_DAYS = 15;
    public static final Integer MAX_EMPLOYEE_NUMBER_LENGTH = 20;
    public static final Integer MAX_ROWS = 200;

    public static final String MSG_NOT_HR = 'Somente o RH pode fazer esta operação.';
    public static final String MSG_TASK_NOT_FOUND = 'Tarefa não encontrada ou sem acesso.';
    public static final String MSG_NOT_ASSIGNED = 'Somente o responsável pela tarefa ou o RH pode alterar a situação.';
    public static final String MSG_EMPLOYEE_NOT_FOUND = 'Colaborador não encontrado ou sem acesso.';
    public static final String MSG_NOT_PRE_ADMISSION = 'Este colaborador não está em pré-admissão.';
    public static final String MSG_NUMBER_REQUIRED = 'Informe a matrícula.';
    public static final String MSG_NUMBER_LENGTH = 'A matrícula pode ter no máximo 20 caracteres.';
    public static final String MSG_NUMBER_PROVISIONAL = 'Informe a matrícula definitiva: o prefixo PRE- é só da pré-admissão.';
    public static final String MSG_NUMBER_TAKEN = 'Já existe um colaborador com esta matrícula.';
    public static final String MSG_DATE_REQUIRED = 'Informe a data de admissão.';
    public static final String MSG_POSITION_REQUIRED = 'Informe o cargo: ele é necessário para o histórico de admissão.';
    public static final String MSG_RECORD_TYPE = 'Informe um colaborador ou um plano de onboarding.';

    public class OnboardingException extends Exception {
    }

    // ------------------------------------------------------------------------------------------ DTOs dos LWCs

    public class TaskItem {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public Date dueDate;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String statusLabel;
        @AuraEnabled
        public Boolean done;
        @AuraEnabled
        public Boolean overdue;
        @AuraEnabled
        public Id assignedToId;
        @AuraEnabled
        public String assignedToName;
        @AuraEnabled
        public Boolean canChange;
    }

    public class TaskGroup {
        @AuraEnabled
        public String role;
        @AuraEnabled
        public String roleLabel;
        @AuraEnabled
        public Integer total = 0;
        @AuraEnabled
        public Integer resolved = 0;
        @AuraEnabled
        public List<TaskItem> tasks = new List<TaskItem>();
    }

    public class ChecklistView {
        @AuraEnabled
        public Boolean hasPlan = false;
        @AuraEnabled
        public Id planId;
        @AuraEnabled
        public String planName;
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public String employeeStatus;
        @AuraEnabled
        public String planStatus;
        @AuraEnabled
        public String planStatusLabel;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Integer total = 0;
        @AuraEnabled
        public Integer resolved = 0;
        @AuraEnabled
        public Integer progressPercent = 0;
        @AuraEnabled
        public Integer overdueCount = 0;
        @AuraEnabled
        public Boolean isHr = false;
        @AuraEnabled
        public Boolean datesOutOfSync = false;
        @AuraEnabled
        public List<TaskGroup> groups = new List<TaskGroup>();
    }

    public class PlanSummary implements Comparable {
        @AuraEnabled
        public Id planId;
        @AuraEnabled
        public String planName;
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public String employeeStatus;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String statusLabel;
        @AuraEnabled
        public Integer total = 0;
        @AuraEnabled
        public Integer resolved = 0;
        @AuraEnabled
        public Integer progressPercent = 0;
        @AuraEnabled
        public Integer overdueCount = 0;

        /** Planos com atraso primeiro; depois por data de inicio (sem data por ultimo) e nome. */
        public Integer compareTo(Object other) {
            PlanSummary o = (PlanSummary) other;
            Integer a = overdueCount > 0 ? 0 : 1;
            Integer b = o.overdueCount > 0 ? 0 : 1;
            if (a != b) {
                return a - b;
            }
            if (startDate != o.startDate) {
                if (startDate == null) {
                    return 1;
                }
                if (o.startDate == null) {
                    return -1;
                }
                return startDate < o.startDate ? -1 : 1;
            }
            return (employeeName == null ? '' : employeeName).compareTo(o.employeeName == null ? '' : o.employeeName);
        }
    }

    public class OverviewResult {
        @AuraEnabled
        public Integer planCount = 0;
        @AuraEnabled
        public Integer overduePlanCount = 0;
        @AuraEnabled
        public Integer averageProgress = 0;
        @AuraEnabled
        public List<PlanSummary> plans = new List<PlanSummary>();
    }

    public class Option {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;

        public Option(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class PendingEmployee {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String employeeNumber;
        @AuraEnabled
        public String email;
        @AuraEnabled
        public Date hireDate;
        @AuraEnabled
        public Id positionId;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public String departmentName;
        @AuraEnabled
        public Id managerId;
        @AuraEnabled
        public String managerName;
    }

    public class ActivationContext {
        @AuraEnabled
        public List<PendingEmployee> employees = new List<PendingEmployee>();
        @AuraEnabled
        public List<Option> positions = new List<Option>();
        @AuraEnabled
        public List<Option> managers = new List<Option>();
    }

    private static final Map<String, String> ROLE_LABELS = new Map<String, String>{
        ROLE_RH => 'RH',
        ROLE_MANAGER => 'Gestor',
        ROLE_IT => 'TI',
        ROLE_EMPLOYEE => 'Colaborador'
    };
    private static final List<String> ROLE_ORDER = new List<String>{ ROLE_EMPLOYEE, ROLE_RH, ROLE_IT, ROLE_MANAGER };
    private static final Map<String, String> TASK_STATUS_LABELS = new Map<String, String>{
        TASK_PENDING => 'Pendente',
        TASK_DONE => 'Concluída',
        TASK_NOT_APPLICABLE => 'Não aplicável'
    };
    private static final Map<String, String> PLAN_STATUS_LABELS = new Map<String, String>{
        PLAN_NOT_STARTED => 'Não iniciado',
        PLAN_IN_PROGRESS => 'Em andamento',
        PLAN_DONE => 'Concluído'
    };

    public static Boolean isHr() {
        return FeatureManagement.checkPermission(HR_PERMISSION);
    }

    // ------------------------------------------------------------------------------------------ O1 a O3

    /**
     * Cria colaborador (Pre-admissao), plano e tarefas para cada candidatura que ainda nao tem colaborador. Devolve
     * Id da candidatura -> Id do colaborador criado. A transacao e do chamador: erro propaga e desfaz a contratacao.
     * Responsavel das tarefas de RH e TI: o usuario que esta contratando.
     */
    public static Map<Id, Id> createFromApplication(Set<Id> applicationIds) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            return new Map<Id, Id>();
        }
        return new Privileged().createFromApplications(applicationIds, UserInfo.getUserId());
    }

    // ------------------------------------------------------------------------------------------ O4

    public static void activate(Id employeeId, String employeeNumber, Date hireDate) {
        activate(employeeId, employeeNumber, hireDate, null, null);
    }

    /**
     * Ativa o colaborador em Pre-admissao. managerId e positionId sao opcionais (null mantem o atual); o cargo, atual
     * ou informado, e obrigatorio porque o historico de admissao nasce dele.
     */
    public static void activate(Id employeeId, String employeeNumber, Date hireDate, Id managerId, Id positionId) {
        requireHr();
        String cleanNumber = employeeNumber == null ? null : employeeNumber.trim();
        if (String.isBlank(cleanNumber)) {
            throw new OnboardingException(MSG_NUMBER_REQUIRED);
        }
        if (cleanNumber.length() > MAX_EMPLOYEE_NUMBER_LENGTH) {
            throw new OnboardingException(MSG_NUMBER_LENGTH);
        }
        if (cleanNumber.startsWithIgnoreCase(PROVISIONAL_PREFIX)) {
            throw new OnboardingException(MSG_NUMBER_PROVISIONAL);
        }
        if (hireDate == null) {
            throw new OnboardingException(MSG_DATE_REQUIRED);
        }
        List<Employee__c> found = EmployeeSelector.byIds(new Set<Id>{ employeeId });
        if (found.isEmpty()) {
            throw new OnboardingException(MSG_EMPLOYEE_NOT_FOUND);
        }
        Employee__c employee = found[0];
        if (employee.Status__c != EMPLOYEE_PRE_ADMISSION) {
            throw new OnboardingException(MSG_NOT_PRE_ADMISSION);
        }
        if (employee.Position__c == null && positionId == null) {
            throw new OnboardingException(MSG_POSITION_REQUIRED);
        }
        if (OnboardingPlanSelector.systemEmployeeNumberTaken(cleanNumber, employeeId)) {
            throw new OnboardingException(MSG_NUMBER_TAKEN);
        }
        Savepoint sp = Database.setSavepoint();
        try {
            Employee__c patch = new Employee__c(
                Id = employeeId,
                Employee_Number__c = cleanNumber,
                Hire_Date__c = hireDate,
                Status__c = EMPLOYEE_ACTIVE
            );
            if (managerId != null) {
                patch.Manager__c = managerId;
            }
            if (positionId != null) {
                patch.Position__c = positionId;
            }
            update as user patch;
            PositionHistoryService.createAdmission(new Set<Id>{ employeeId });
            List<Onboarding_Plan__c> plans = OnboardingPlanSelector.byEmployeeIds(new Set<Id>{ employeeId });
            if (!plans.isEmpty()) {
                Onboarding_Plan__c plan = plans[0];
                Onboarding_Plan__c planPatch = new Onboarding_Plan__c(Id = plan.Id, Start_Date__c = hireDate);
                if (plan.Status__c != PLAN_DONE) {
                    planPatch.Status__c = PLAN_IN_PROGRESS;
                }
                update as user planPatch;
                synchronize(new Set<Id>{ employeeId }, true);
            }
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new OnboardingException(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    // ------------------------------------------------------------------------------------------ O5

    /** Conclui (done = true) ou reabre (false) a tarefa. Somente o responsavel ou o RH. */
    public static void setTaskDone(Id taskId, Boolean done) {
        List<Onboarding_Task__c> rows = OnboardingTaskSelector.byIds(new Set<Id>{ taskId });
        if (rows.isEmpty()) {
            throw new OnboardingException(MSG_TASK_NOT_FOUND);
        }
        Onboarding_Task__c task = rows[0];
        if (!canChange(task.Assigned_To__c)) {
            throw new OnboardingException(MSG_NOT_ASSIGNED);
        }
        String target = done == true ? TASK_DONE : TASK_PENDING;
        if (task.Status__c == target) {
            return;
        }
        try {
            update as user new Onboarding_Task__c(Id = taskId, Status__c = target);
        } catch (DmlException e) {
            throw new OnboardingException(e.getDmlMessage(0));
        }
    }

    /** Regra O5: o responsavel da tarefa ou o RH. */
    public static Boolean canChange(Id assignedToId) {
        return isHr() || (assignedToId != null && assignedToId == UserInfo.getUserId());
    }

    /**
     * Ajusta a situacao dos planos pelas tarefas: Concluido quando nenhuma tarefa esta Pendente; se uma tarefa for
     * reaberta, volta para Em andamento (ou Nao iniciado se o colaborador ainda esta em pre-admissao).
     * Contexto de sistema: quem muda a tarefa nao edita o plano.
     */
    public static void refreshPlanStatus(Set<Id> planIds) {
        if (planIds == null || planIds.isEmpty()) {
            return;
        }
        new Privileged().refreshPlanStatus(planIds);
    }

    // ------------------------------------------------------------------------------------------ O6

    /** Refaz o prazo das tarefas pendentes dos colaboradores a partir da data de admissao atual. So o RH. */
    public static void recalculateDates(Set<Id> employeeIds) {
        requireHr();
        synchronize(employeeIds, false);
    }

    /** Refaz prazos e responsaveis (colaborador e gestor) das tarefas pendentes. So o RH. */
    public static void syncPlans(Set<Id> employeeIds) {
        requireHr();
        synchronize(employeeIds, true);
    }

    private static void synchronize(Set<Id> employeeIds, Boolean refreshAssignees) {
        if (employeeIds == null || employeeIds.isEmpty()) {
            return;
        }
        Map<Id, Employee__c> employees = new Map<Id, Employee__c>(EmployeeSelector.byIds(employeeIds));
        List<Onboarding_Plan__c> plans = new List<Onboarding_Plan__c>();
        Map<Id, Employee__c> employeeByPlan = new Map<Id, Employee__c>();
        Set<Id> seenEmployees = new Set<Id>();
        for (Onboarding_Plan__c plan : OnboardingPlanSelector.byEmployeeIds(employeeIds)) {
            // Um plano por colaborador: o mais recente (a consulta vem em ordem decrescente de criacao).
            if (plan.Status__c == PLAN_DONE || !seenEmployees.add(plan.Employee__c)) {
                continue;
            }
            Employee__c employee = employees.get(plan.Employee__c);
            if (employee == null) {
                continue;
            }
            plans.add(plan);
            employeeByPlan.put(plan.Id, employee);
        }
        if (plans.isEmpty()) {
            return;
        }
        List<Onboarding_Plan__c> planUpdates = new List<Onboarding_Plan__c>();
        for (Onboarding_Plan__c plan : plans) {
            Date hireDate = employeeByPlan.get(plan.Id).Hire_Date__c;
            if (plan.Start_Date__c != hireDate) {
                planUpdates.add(new Onboarding_Plan__c(Id = plan.Id, Start_Date__c = hireDate));
            }
        }
        List<Onboarding_Task__c> taskUpdates = new List<Onboarding_Task__c>();
        for (Onboarding_Task__c task : OnboardingTaskSelector.pendingByPlanIds(employeeByPlan.keySet())) {
            Employee__c employee = employeeByPlan.get(task.Plan__c);
            Onboarding_Task__c patch = new Onboarding_Task__c(Id = task.Id);
            Boolean changed = false;
            if (task.Due_Offset_Days__c != null && employee.Hire_Date__c != null) {
                Date newDue = employee.Hire_Date__c.addDays(task.Due_Offset_Days__c.intValue());
                if (task.Due_Date__c != newDue) {
                    patch.Due_Date__c = newDue;
                    changed = true;
                }
            }
            if (refreshAssignees) {
                Id assignee = assigneeFor(task.Owner_Role__c, employee);
                if (assignee != null && assignee != task.Assigned_To__c) {
                    patch.Assigned_To__c = assignee;
                    changed = true;
                }
            }
            if (changed) {
                taskUpdates.add(patch);
            }
        }
        try {
            update as user planUpdates;
            update as user taskUpdates;
        } catch (DmlException e) {
            throw new OnboardingException(e.getDmlMessage(0));
        }
    }

    /** Colaborador e gestor sao deduzidos do colaborador; RH e TI ficam com quem foi definido na criacao. */
    private static Id assigneeFor(String role, Employee__c employee) {
        if (role == ROLE_EMPLOYEE) {
            return employee.User__c;
        }
        if (role == ROLE_MANAGER && String.isNotBlank(employee.Manager_User_Id__c)) {
            return (Id) employee.Manager_User_Id__c;
        }
        return null;
    }

    // ------------------------------------------------------------------------------------------ leitura dos LWCs

    /**
     * Checklist do colaborador. recordId pode ser um Employee__c, um Onboarding_Plan__c ou null (colaborador do usuario
     * atual, para o Meu RH).
     */
    public static ChecklistView checklist(Id recordId) {
        ChecklistView view = new ChecklistView();
        view.isHr = isHr();
        Onboarding_Plan__c plan = resolvePlan(recordId);
        if (plan == null) {
            return view;
        }
        Date today = Date.today();
        view.hasPlan = true;
        view.planId = plan.Id;
        view.planName = plan.Name;
        view.employeeId = plan.Employee__c;
        view.employeeName = plan.Employee__r.Name;
        view.employeeStatus = plan.Employee__r.Status__c;
        view.planStatus = plan.Status__c;
        view.planStatusLabel = PLAN_STATUS_LABELS.get(plan.Status__c);
        view.startDate = plan.Start_Date__c;
        view.datesOutOfSync = plan.Status__c != PLAN_DONE && plan.Start_Date__c != plan.Employee__r.Hire_Date__c;
        Map<String, TaskGroup> groups = new Map<String, TaskGroup>();
        for (Onboarding_Task__c t : OnboardingTaskSelector.byPlanIds(new Set<Id>{ plan.Id })) {
            String role = String.isBlank(t.Owner_Role__c) ? ROLE_RH : t.Owner_Role__c;
            TaskGroup taskGroup = groups.get(role);
            if (taskGroup == null) {
                taskGroup = new TaskGroup();
                taskGroup.role = role;
                taskGroup.roleLabel = ROLE_LABELS.containsKey(role) ? ROLE_LABELS.get(role) : role;
                groups.put(role, taskGroup);
            }
            TaskItem item = new TaskItem();
            item.id = t.Id;
            item.title = t.Name;
            item.description = t.Description__c;
            item.dueDate = t.Due_Date__c;
            item.status = t.Status__c;
            item.statusLabel = TASK_STATUS_LABELS.get(t.Status__c);
            item.done = t.Status__c == TASK_DONE;
            item.overdue = t.Status__c == TASK_PENDING && t.Due_Date__c != null && t.Due_Date__c < today;
            item.assignedToId = t.Assigned_To__c;
            item.assignedToName = t.Assigned_To__r == null ? null : t.Assigned_To__r.Name;
            item.canChange = canChange(t.Assigned_To__c);
            taskGroup.tasks.add(item);
            taskGroup.total++;
            view.total++;
            if (t.Status__c != TASK_PENDING) {
                taskGroup.resolved++;
                view.resolved++;
            }
            if (item.overdue) {
                view.overdueCount++;
            }
        }
        view.progressPercent = percent(view.resolved, view.total);
        for (String role : ROLE_ORDER) {
            if (groups.containsKey(role)) {
                view.groups.add(groups.remove(role));
            }
        }
        view.groups.addAll(groups.values());
        return view;
    }

    /** Planos visiveis ao usuario com progresso e atrasos (visao geral do RH). */
    public static OverviewResult overview(Boolean includeCompleted) {
        OverviewResult result = new OverviewResult();
        List<Onboarding_Plan__c> plans = OnboardingPlanSelector.overview(includeCompleted, MAX_ROWS);
        if (plans.isEmpty()) {
            return result;
        }
        Set<Id> planIds = new Map<Id, Onboarding_Plan__c>(plans).keySet();
        Map<Id, Map<String, Integer>> counts = OnboardingTaskSelector.countsByPlan(planIds);
        Map<Id, Integer> overdue = OnboardingTaskSelector.overdueByPlan(planIds, Date.today());
        Integer progressSum = 0;
        for (Onboarding_Plan__c plan : plans) {
            PlanSummary s = new PlanSummary();
            s.planId = plan.Id;
            s.planName = plan.Name;
            s.employeeId = plan.Employee__c;
            s.employeeName = plan.Employee__r.Name;
            s.employeeStatus = plan.Employee__r.Status__c;
            s.startDate = plan.Start_Date__c;
            s.status = plan.Status__c;
            s.statusLabel = PLAN_STATUS_LABELS.get(plan.Status__c);
            Map<String, Integer> byStatus = counts.get(plan.Id);
            if (byStatus != null) {
                for (String status : byStatus.keySet()) {
                    s.total += byStatus.get(status);
                    if (status != TASK_PENDING) {
                        s.resolved += byStatus.get(status);
                    }
                }
            }
            s.progressPercent = percent(s.resolved, s.total);
            s.overdueCount = overdue.containsKey(plan.Id) ? overdue.get(plan.Id) : 0;
            progressSum += s.progressPercent;
            if (s.overdueCount > 0) {
                result.overduePlanCount++;
            }
            result.plans.add(s);
        }
        result.plans.sort();
        result.planCount = result.plans.size();
        result.averageProgress = percent(progressSum, result.planCount * 100);
        return result;
    }

    /** Colaboradores em pre-admissao, cargos e gestores possiveis para a tela de ativacao. So o RH. */
    public static ActivationContext activationContext() {
        requireHr();
        ActivationContext ctx = new ActivationContext();
        for (Employee__c e : OnboardingPlanSelector.preAdmissionEmployees(MAX_ROWS)) {
            PendingEmployee p = new PendingEmployee();
            p.id = e.Id;
            p.name = e.Name;
            p.employeeNumber = e.Employee_Number__c;
            p.email = e.Email__c;
            p.hireDate = e.Hire_Date__c;
            p.positionId = e.Position__c;
            p.positionName = e.Position__r == null ? null : e.Position__r.Name;
            p.departmentName = e.Department__r == null ? null : e.Department__r.Name;
            p.managerId = e.Manager__c;
            p.managerName = e.Manager__r == null ? null : e.Manager__r.Name;
            ctx.employees.add(p);
        }
        for (Job_Position__c pos : OnboardingPlanSelector.activePositions(MAX_ROWS)) {
            ctx.positions.add(new Option(pos.Id, pos.Name));
        }
        for (Employee__c m : OnboardingPlanSelector.managerCandidates(MAX_ROWS)) {
            ctx.managers.add(new Option(m.Id, m.Name));
        }
        return ctx;
    }

    // ------------------------------------------------------------------------------------------ apoio

    private static void requireHr() {
        if (!isHr()) {
            throw new OnboardingException(MSG_NOT_HR);
        }
    }

    private static Integer percent(Integer part, Integer whole) {
        if (whole == null || whole == 0) {
            return 0;
        }
        return Integer.valueOf(Math.round(part * 100.0 / whole));
    }

    private static Onboarding_Plan__c resolvePlan(Id recordId) {
        if (recordId == null) {
            Employee__c me = EmployeeSelector.currentUserEmployee();
            if (me == null) {
                return null;
            }
            return firstPlanOf(me.Id);
        }
        String type = String.valueOf(recordId.getSobjectType());
        if (type == 'Onboarding_Plan__c') {
            List<Onboarding_Plan__c> rows = OnboardingPlanSelector.byIds(new Set<Id>{ recordId });
            return rows.isEmpty() ? null : rows[0];
        }
        if (type == 'Employee__c') {
            return firstPlanOf(recordId);
        }
        throw new OnboardingException(MSG_RECORD_TYPE);
    }

    private static Onboarding_Plan__c firstPlanOf(Id employeeId) {
        List<Onboarding_Plan__c> rows = OnboardingPlanSelector.byEmployeeIds(new Set<Id>{ employeeId });
        return rows.isEmpty() ? null : rows[0];
    }

    // ------------------------------------------------------------------------------------------ contexto de sistema

    // Contexto de sistema da spec 02, ver comentario da classe: cada metodo so roda depois da regra validada.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private without sharing class Privileged {
        Map<Id, Id> createFromApplications(Set<Id> applicationIds, Id hiringUserId) {
            Map<Id, Id> created = new Map<Id, Id>();
            List<Job_Application__c> applications = new List<Job_Application__c>();
            Set<Id> managerEmployeeIds = new Set<Id>();
            for (Job_Application__c a : OnboardingPlanSelector.systemApplications(applicationIds)) {
                // Idempotencia (O1): candidatura que ja tem colaborador nao cria de novo.
                if (a.Employee__c == null) {
                    applications.add(a);
                    managerEmployeeIds.add(a.Job_Opening__r.Hiring_Manager__c);
                }
            }
            if (applications.isEmpty()) {
                return created;
            }
            managerEmployeeIds.remove(null);
            Map<Id, Id> managerUsers = OnboardingPlanSelector.systemUserByEmployee(managerEmployeeIds);
            Date hireDate = Date.today().addDays(DEFAULT_LEAD_DAYS);

            List<Employee__c> employees = new List<Employee__c>();
            for (Job_Application__c a : applications) {
                Employee__c e = new Employee__c(
                    Name = a.Candidate__r.Name.left(80),
                    Email__c = a.Candidate__r.Email__c,
                    Status__c = EMPLOYEE_PRE_ADMISSION,
                    Position__c = a.Job_Opening__r.Position__c,
                    Department__c = a.Job_Opening__r.Department__c,
                    Manager__c = a.Job_Opening__r.Hiring_Manager__c,
                    Hire_Date__c = hireDate,
                    Employee_Number__c = provisionalNumber(a)
                );
                if (a.Job_Opening__r.Employment_Type__c != null) {
                    e.Employment_Type__c = a.Job_Opening__r.Employment_Type__c;
                }
                employees.add(e);
            }
            insert employees;

            List<Job_Application__c> links = new List<Job_Application__c>();
            List<Onboarding_Plan__c> plans = new List<Onboarding_Plan__c>();
            for (Integer i = 0; i < applications.size(); i++) {
                Job_Application__c a = applications[i];
                created.put(a.Id, employees[i].Id);
                links.add(new Job_Application__c(Id = a.Id, Employee__c = employees[i].Id));
                plans.add(
                    new Onboarding_Plan__c(
                        Employee__c = employees[i].Id,
                        Job_Application__c = a.Id,
                        Start_Date__c = hireDate,
                        Status__c = PLAN_NOT_STARTED
                    )
                );
            }
            update links;
            insert plans;

            List<Onboarding_Task__c> tasks = new List<Onboarding_Task__c>();
            for (Integer i = 0; i < applications.size(); i++) {
                Job_Application__c a = applications[i];
                String employmentType = employees[i].Employment_Type__c == null ? 'CLT' : employees[i].Employment_Type__c;
                Id managerUser = managerUsers.get(a.Job_Opening__r.Hiring_Manager__c);
                for (OnboardingTemplateConfig.Template t : OnboardingTemplateConfig.forEmploymentType(employmentType)) {
                    tasks.add(
                        new Onboarding_Task__c(
                            Name = t.title.left(80),
                            Plan__c = plans[i].Id,
                            Description__c = t.description,
                            Owner_Role__c = t.ownerRole,
                            Order__c = t.sortOrder,
                            Due_Offset_Days__c = t.offsetDays,
                            Due_Date__c = hireDate.addDays(t.offsetDays),
                            Status__c = TASK_PENDING,
                            Assigned_To__c = initialAssignee(t.ownerRole, hiringUserId, managerUser)
                        )
                    );
                }
            }
            insert tasks;
            return created;
        }

        /** PRE-<numero da candidatura> (CA-000123 vira PRE-000123): unico porque a candidatura e unica. */
        String provisionalNumber(Job_Application__c application) {
            String digits = application.Name == null ? '' : application.Name.replaceAll('[^0-9]', '');
            if (String.isBlank(digits)) {
                digits = String.valueOf(application.Id).right(8);
            }
            return (PROVISIONAL_PREFIX + digits).left(MAX_EMPLOYEE_NUMBER_LENGTH);
        }

        /** O2: RH e TI com quem contratou; gestor com o usuario do gestor; colaborador so quando existir usuario. */
        Id initialAssignee(String role, Id hiringUserId, Id managerUserId) {
            if (role == ROLE_MANAGER) {
                return managerUserId;
            }
            if (role == ROLE_RH || role == ROLE_IT) {
                return hiringUserId;
            }
            return null;
        }

        void refreshPlanStatus(Set<Id> planIds) {
            Map<Id, Map<String, Integer>> counts = OnboardingTaskSelector.systemCountsByPlan(planIds);
            List<Onboarding_Plan__c> updates = new List<Onboarding_Plan__c>();
            for (Onboarding_Plan__c plan : OnboardingPlanSelector.systemByIds(planIds)) {
                Map<String, Integer> byStatus = counts.containsKey(plan.Id) ? counts.get(plan.Id) : new Map<String, Integer>();
                Integer total = 0;
                for (Integer n : byStatus.values()) {
                    total += n;
                }
                Integer pending = byStatus.containsKey(TASK_PENDING) ? byStatus.get(TASK_PENDING) : 0;
                String target = plan.Status__c;
                if (total > 0 && pending == 0) {
                    target = PLAN_DONE;
                } else if (plan.Status__c == PLAN_DONE) {
                    target = plan.Employee__r.Status__c == EMPLOYEE_PRE_ADMISSION ? PLAN_NOT_STARTED : PLAN_IN_PROGRESS;
                }
                if (target != plan.Status__c) {
                    updates.add(new Onboarding_Plan__c(Id = plan.Id, Status__c = target));
                }
            }
            update updates;
        }
    }
}
