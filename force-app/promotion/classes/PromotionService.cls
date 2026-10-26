/**
 * Regras de negocio de promocoes (spec 12).
 *
 * Fluxo: o gestor solicita (createAndSubmit), o motor de aprovacao do core roteia (gestor de segundo nivel e RH),
 * o RH informa o salario na ultima etapa (hrDecide, regra P6) e, aprovado, a promocao e efetivada na hora ou pelo
 * PromotionEffectivationBatch (regras P7 e P8).
 *
 * Contexto de sistema (spec 02, linha "PromotionService"): a classe interna Privileged e a unica que ignora
 * sharing e FLS. Ela serve a tres necessidades documentadas:
 *   1. Validar e gravar o snapshot de cargo e salario na criacao (P5): o gestor nao le salario, mas o snapshot
 *      precisa existir. Tambem le o colaborador, os cargos e os pedidos pendentes de qualquer pessoa para validar
 *      P1, P2 e P4 sem expor dado ao usuario.
 *   2. Efetivar: atualizar cargo e salario do colaborador, que o RH aprovador ou o batch nao necessariamente
 *      pode editar, e registrar o historico.
 *   3. Notificar quem nao tem acesso ao pedido.
 * Toda decisao de quem pode fazer o que (P1, hrDecide so para o RH) e validada ANTES, com sharing.
 */
// Contexto de sistema da spec 02 concentrado na classe interna Privileged (ver comentario da classe).
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class PromotionService {
    public static final String STATUS_EFFECTIVE = 'Efetivado';
    public static final String BAND_WITHIN = 'Dentro';
    public static final String BAND_BELOW = 'Abaixo';
    public static final String BAND_ABOVE = 'Acima';
    public static final String BAND_NONE = 'SemFaixa';

    public static final String MSG_NOT_IN_CHAIN = 'Você só pode solicitar promoção para alguém da sua equipe.';
    public static final String MSG_OFF_TRACK = 'Promoção fora da trilha prevista.';
    public static final String MSG_SAME_POSITION = 'O novo cargo deve ser diferente do cargo atual.';
    public static final String MSG_INACTIVE_POSITION = 'O novo cargo precisa estar ativo.';
    public static final String MSG_PAST_DATE = 'A data de efetivação não pode estar no passado.';
    public static final String MSG_PENDING = 'Este colaborador já tem uma solicitação de promoção pendente.';
    public static final String MSG_JUSTIFICATION = 'Informe a justificativa da promoção.';
    public static final String MSG_REQUIRED = 'Informe o colaborador, o novo cargo, a data de efetivação e a justificativa.';
    public static final String MSG_ONLY_HR = 'Somente o RH pode decidir esta etapa.';
    public static final String MSG_NOT_AWAITING_HR = 'Esta solicitação não está aguardando a decisão do RH.';
    public static final String MSG_NOT_AWAITING_MANAGER = 'Esta solicitação não está aguardando a sua decisão.';
    public static final String MSG_SALARY_REQUIRED = 'Informe o salário proposto antes de aprovar.';
    public static final String MSG_OUT_OF_BAND = 'O salário proposto está fora da faixa do cargo: informe uma justificativa na decisão.';
    public static final String MSG_NOT_FOUND = 'Solicitação não encontrada ou sem acesso.';

    /** Limite de notificacoes por transacao: protege o lote do batch (cada envio e uma chamada de plataforma). */
    public static final Integer MAX_NOTIFICATIONS = 90;

    @TestVisible
    private static Integer notificationsSent = 0;

    public class PromotionException extends Exception {
    }

    // ------------------------------------------------------------------------------------------------ DTOs

    public class SubmitResult {
        @AuraEnabled
        public Id requestId;
        @AuraEnabled
        public String requestName;
        @AuraEnabled
        public String warning;
    }

    public class TeamMember {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Id positionId;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public String departmentName;
    }

    public class PositionOption {
        @AuraEnabled
        public Id value;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Boolean isNext;
    }

    public class FormContext {
        @AuraEnabled
        public Id currentPositionId;
        @AuraEnabled
        public String currentPositionName;
        @AuraEnabled
        public Id nextPositionId;
        @AuraEnabled
        public String nextPositionName;
        @AuraEnabled
        public List<PositionOption> options = new List<PositionOption>();
    }

    public class HrReview {
        @AuraEnabled
        public Id requestId;
        @AuraEnabled
        public String requestName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public String requestedByName;
        @AuraEnabled
        public String currentPositionName;
        @AuraEnabled
        public String proposedPositionName;
        @AuraEnabled
        public Date effectiveDate;
        @AuraEnabled
        public String justification;
        @AuraEnabled
        public Decimal currentSalary;
        @AuraEnabled
        public Decimal proposedSalary;
        @AuraEnabled
        public String bandName;
        @AuraEnabled
        public Decimal bandMin;
        @AuraEnabled
        public Decimal bandMax;
        @AuraEnabled
        public Boolean canDecide;
    }

    // ------------------------------------------------------------------------------------- solicitacao (gestor)

    /**
     * Cria a solicitacao como o usuario atual (as user), deixa a trigger validar P1 a P4 e gravar o snapshot (P5) e
     * envia para aprovacao. Tudo ou nada: se o envio falhar, a solicitacao nao fica gravada.
     */
    public static SubmitResult createAndSubmit(Id employeeId, Id proposedPositionId, Date effectiveDate, String justification) {
        if (employeeId == null || proposedPositionId == null || effectiveDate == null || String.isBlank(justification)) {
            throw new PromotionException(MSG_REQUIRED);
        }
        String warning = trailWarning(employeeId, proposedPositionId);
        Promotion_Request__c request = new Promotion_Request__c(
            Employee__c = employeeId,
            Proposed_Position__c = proposedPositionId,
            Effective_Date__c = effectiveDate,
            Justification__c = justification.trim()
        );
        Savepoint sp = Database.setSavepoint();
        try {
            insert as user request;
            ApprovalService.submit(request.Id, 'Promotion');
        } catch (Exception e) {
            Database.rollback(sp);
            throw new PromotionException(cleanMessage(e));
        }
        SubmitResult result = new SubmitResult();
        result.requestId = request.Id;
        result.warning = warning;
        List<Promotion_Request__c> saved = PromotionRequestSelector.byIds(new Set<Id>{ request.Id });
        result.requestName = saved.isEmpty() ? null : saved[0].Name;
        return result;
    }

    /** Aviso nao bloqueante da regra P2: o cargo proposto nao e o proximo da trilha do cargo atual. */
    public static String trailWarning(Id employeeId, Id proposedPositionId) {
        List<Employee__c> employees = EmployeeSelector.byIds(new Set<Id>{ employeeId });
        if (employees.isEmpty()) {
            throw new PromotionException(MSG_NOT_IN_CHAIN);
        }
        Id nextId = nextPositionOf(employees[0].Position__c);
        return nextId != null && nextId == proposedPositionId ? null : MSG_OFF_TRACK;
    }

    /** Equipe (direta e indireta) do usuario atual que pode receber uma solicitacao. */
    public static List<TeamMember> teamMembers() {
        Employee__c me = EmployeeSelector.currentUserEmployee();
        List<TeamMember> result = new List<TeamMember>();
        if (me == null) {
            return result;
        }
        for (Employee__c e : EmployeeSelector.subtree(me.Id)) {
            if (e.Status__c == 'Desligado' || e.Status__c == 'Pre_Admissao') {
                continue;
            }
            TeamMember m = new TeamMember();
            m.id = e.Id;
            m.name = e.Name;
            m.positionId = e.Position__c;
            m.positionName = e.Position__r == null ? null : e.Position__r.Name;
            m.departmentName = e.Department__r == null ? null : e.Department__r.Name;
            result.add(m);
        }
        return result;
    }

    /** Dados do formulario: cargo atual, proximo da trilha e cargos ativos (o proximo vem primeiro). */
    public static FormContext formContext(Id employeeId) {
        List<Employee__c> employees = EmployeeSelector.byIds(new Set<Id>{ employeeId });
        if (employees.isEmpty()) {
            throw new PromotionException(MSG_NOT_IN_CHAIN);
        }
        Employee__c emp = employees[0];
        FormContext ctx = new FormContext();
        ctx.currentPositionId = emp.Position__c;
        ctx.currentPositionName = emp.Position__r == null ? null : emp.Position__r.Name;
        if (emp.Position__c != null) {
            List<Job_Position__c> current = PromotionPositionSelector.byIds(new Set<Id>{ emp.Position__c });
            if (!current.isEmpty() && current[0].Next_Position__c != null) {
                ctx.nextPositionId = current[0].Next_Position__c;
                ctx.nextPositionName = current[0].Next_Position__r == null ? null : current[0].Next_Position__r.Name;
            }
        }
        List<PositionOption> others = new List<PositionOption>();
        for (Job_Position__c p : PromotionPositionSelector.active()) {
            if (p.Id == emp.Position__c) {
                continue;
            }
            PositionOption o = new PositionOption();
            o.value = p.Id;
            o.label = p.Name;
            o.isNext = p.Id == ctx.nextPositionId;
            if (o.isNext) {
                ctx.options.add(o);
            } else {
                others.add(o);
            }
        }
        ctx.options.addAll(others);
        return ctx;
    }

    public static void cancel(Id requestId) {
        try {
            ApprovalService.cancel(requestId, 'Promotion');
        } catch (Exception e) {
            throw new PromotionException(cleanMessage(e));
        }
    }

    // ----------------------------------------------------------------------------------------- decisoes

    /** Decisao da etapa do gestor de segundo nivel (ou de qualquer etapa que nao seja a do RH) pelo usuario atual. */
    public static void managerDecide(Id requestId, Boolean approve, String comments) {
        Approval_Step__c step = pendingStep(requestId, false);
        if (step == null || step.Approver__c != UserInfo.getUserId()) {
            throw new PromotionException(MSG_NOT_AWAITING_MANAGER);
        }
        ApprovalService.decide(step.Id, approve, comments);
    }

    /**
     * Etapa do RH (regra P6). Para aprovar, o RH informa o salario proposto; fora da faixa do cargo novo, a decisao
     * exige comentario de justificativa. A rejeicao nao exige salario (o comentario e exigido pelo motor).
     */
    public static void hrDecide(Id requestId, Decimal proposedSalary, Boolean approve, String comments) {
        if (!ApprovalService.isHrMember()) {
            throw new PromotionException(MSG_ONLY_HR);
        }
        Approval_Step__c step = pendingStep(requestId, true);
        if (step == null) {
            throw new PromotionException(MSG_NOT_AWAITING_HR);
        }
        List<Promotion_Request__c> rows = PromotionRequestSelector.byIdsWithSalary(new Set<Id>{ requestId });
        if (rows.isEmpty()) {
            throw new PromotionException(MSG_NOT_FOUND);
        }
        if (approve == true) {
            if (proposedSalary == null || proposedSalary <= 0) {
                throw new PromotionException(MSG_SALARY_REQUIRED);
            }
            Salary_Band__c band = rows[0].Proposed_Position__r == null ? null : rows[0].Proposed_Position__r.Salary_Band__r;
            String status = evaluateBand(proposedSalary, band == null ? null : band.Min_Salary__c, band == null ? null : band.Max_Salary__c);
            if ((status == BAND_BELOW || status == BAND_ABOVE) && String.isBlank(comments)) {
                throw new PromotionException(MSG_OUT_OF_BAND);
            }
            Promotion_Request__c salaryUpdate = new Promotion_Request__c(Id = requestId, Proposed_Salary__c = proposedSalary);
            update as user salaryUpdate;
        }
        ApprovalService.decide(step.Id, approve, comments);
    }

    /** Situacao do salario em relacao a faixa: Dentro, Abaixo, Acima ou SemFaixa (cargo sem faixa cadastrada). */
    public static String evaluateBand(Decimal salary, Decimal minSalary, Decimal maxSalary) {
        if (minSalary == null && maxSalary == null) {
            return BAND_NONE;
        }
        if (salary == null) {
            return null;
        }
        if (minSalary != null && salary < minSalary) {
            return BAND_BELOW;
        }
        if (maxSalary != null && salary > maxSalary) {
            return BAND_ABOVE;
        }
        return BAND_WITHIN;
    }

    /** Solicitacoes de promocao que aguardam a decisao do RH (somente para quem pertence ao grupo de RH). */
    public static List<ApprovalService.ApprovalItem> pendingForHr() {
        List<ApprovalService.ApprovalItem> result = new List<ApprovalService.ApprovalItem>();
        if (!ApprovalService.isHrMember()) {
            return result;
        }
        for (ApprovalService.ApprovalItem item : ApprovalService.pendingForCurrentUser()) {
            if (item.requestType == 'Promotion' && item.approverType == 'HR_Team') {
                result.add(item);
            }
        }
        return result;
    }

    /** Dados da tela de revisao do RH: inclui salario e faixa; falha para quem nao tem acesso a esses campos. */
    public static HrReview hrReview(Id requestId) {
        List<Promotion_Request__c> rows = PromotionRequestSelector.byIdsWithSalary(new Set<Id>{ requestId });
        if (rows.isEmpty()) {
            throw new PromotionException(MSG_NOT_FOUND);
        }
        Promotion_Request__c r = rows[0];
        Salary_Band__c band = r.Proposed_Position__r == null ? null : r.Proposed_Position__r.Salary_Band__r;
        HrReview review = new HrReview();
        review.requestId = r.Id;
        review.requestName = r.Name;
        review.status = r.Status__c;
        review.employeeName = r.Employee__r == null ? null : r.Employee__r.Name;
        review.requestedByName = r.Requested_By__r == null ? null : r.Requested_By__r.Name;
        review.currentPositionName = r.Current_Position__r == null ? null : r.Current_Position__r.Name;
        review.proposedPositionName = r.Proposed_Position__r == null ? null : r.Proposed_Position__r.Name;
        review.effectiveDate = r.Effective_Date__c;
        review.justification = r.Justification__c;
        review.currentSalary = r.Current_Salary__c;
        review.proposedSalary = r.Proposed_Salary__c;
        if (band != null) {
            review.bandName = band.Name;
            review.bandMin = band.Min_Salary__c;
            review.bandMax = band.Max_Salary__c;
        }
        review.canDecide = r.Status__c == ApprovalService.STATUS_PENDING && ApprovalService.isHrMember() && pendingStep(requestId, true) != null;
        return review;
    }

    // ------------------------------------------------------------------------ trigger (regras P1 a P5)

    /** Antes de inserir: valida P1 a P4, exige justificativa e grava o snapshot (P5) e o solicitante. */
    public static void prepareNew(List<Promotion_Request__c> records) {
        new Privileged().prepareNew(records);
    }

    /** Antes de atualizar: P3 quando a data muda e P4 quando o pedido passa a Pendente. */
    public static void validateUpdate(List<Promotion_Request__c> records, Map<Id, Promotion_Request__c> oldMap) {
        new Privileged().validateUpdate(records, oldMap);
    }

    // ----------------------------------------------------------------------- efetivacao e desfecho (P7, P8)

    /**
     * Efetiva as promocoes Aprovadas informadas: atualiza cargo e salario do colaborador, fecha o historico aberto,
     * abre o novo, marca Efetivado e notifica. Idempotente (ignora o que nao esta Aprovado) e tolerante: um
     * colaborador que nao pode ser atualizado nao impede os demais. Um colaborador por chamada; se houver dois
     * pedidos aprovados do mesmo colaborador, o segundo fica para a proxima execucao. Devolve quantas efetivou.
     */
    public static Integer effectivate(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) {
            return 0;
        }
        return new Privileged().effectivate(requestIds);
    }

    /** Chamado pelo PromotionApprovalHandler quando a ultima etapa aprova. */
    public static void onApproved(Id requestId) {
        new Privileged().onApproved(requestId);
    }

    public static void onRejected(Id requestId) {
        new Privileged().onRejected(requestId);
    }

    public static void onStepAdvanced(Id requestId, Integer newStep) {
        new Privileged().onStepAdvanced(requestId, newStep);
    }

    // ----------------------------------------------------------------------------------------- internos

    public static Date today() {
        return Date.today();
    }

    private static Id nextPositionOf(Id positionId) {
        if (positionId == null) {
            return null;
        }
        List<Job_Position__c> rows = PromotionPositionSelector.byIds(new Set<Id>{ positionId });
        return rows.isEmpty() ? null : rows[0].Next_Position__c;
    }

    private static String cleanMessage(Exception e) {
        if (e instanceof DmlException) {
            DmlException d = (DmlException) e;
            if (d.getNumDml() > 0) {
                return d.getDmlMessage(0);
            }
        }
        return e.getMessage();
    }

    /** Etapa pendente da solicitacao: a do RH (hrStep true) ou qualquer outra. Leitura com sharing e FLS. */
    private static Approval_Step__c pendingStep(Id requestId, Boolean hrStep) {
        for (Approval_Step__c s : ApprovalStepSelector.byRequest(requestId)) {
            if (s.Status__c == ApprovalService.STATUS_PENDING && (s.Approver_Type__c == 'HR_Team') == hrStep) {
                return s;
            }
        }
        return null;
    }

    private static String formatDate(Date d) {
        return d == null ? '' : Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('dd/MM/yyyy');
    }

    private without sharing class Privileged {
        // ------------------------------------------------------------------------------ validacao e snapshot

        void prepareNew(List<Promotion_Request__c> records) {
            Set<Id> employeeIds = new Set<Id>();
            Set<Id> positionIds = new Set<Id>();
            for (Promotion_Request__c r : records) {
                if (r.Employee__c != null) {
                    employeeIds.add(r.Employee__c);
                }
                if (r.Proposed_Position__c != null) {
                    positionIds.add(r.Proposed_Position__c);
                }
            }
            Map<Id, Employee__c> employees = new Map<Id, Employee__c>(
                [
                    SELECT Id, Position__c, Salary__c, Hierarchy_Path__c
                    FROM Employee__c
                    WHERE Id IN :employeeIds
                    WITH SYSTEM_MODE
                ]
            );
            Map<Id, Job_Position__c> positions = new Map<Id, Job_Position__c>(
                [
                    SELECT Id, Active__c
                    FROM Job_Position__c
                    WHERE Id IN :positionIds
                    WITH SYSTEM_MODE
                ]
            );
            Set<Id> pending = PromotionRequestSelector.employeesWithPending(employeeIds, new Set<Id>());
            Id requesterEmployeeId = currentEmployeeId();
            Id me = UserInfo.getUserId();
            Date asOf = today();
            for (Promotion_Request__c r : records) {
                Employee__c emp = employees.get(r.Employee__c);
                if (emp == null) {
                    // Campo obrigatorio vazio: a plataforma reporta; nada a validar aqui.
                    continue;
                }
                if (!isInChain(emp, requesterEmployeeId)) {
                    r.Employee__c.addError(MSG_NOT_IN_CHAIN);
                    continue;
                }
                Job_Position__c proposed = positions.get(r.Proposed_Position__c);
                if (proposed != null && proposed.Id == emp.Position__c) {
                    r.Proposed_Position__c.addError(MSG_SAME_POSITION);
                } else if (proposed != null && proposed.Active__c != true) {
                    r.Proposed_Position__c.addError(MSG_INACTIVE_POSITION);
                }
                if (r.Effective_Date__c != null && r.Effective_Date__c < asOf) {
                    r.Effective_Date__c.addError(MSG_PAST_DATE);
                }
                if (String.isBlank(r.Justification__c)) {
                    r.Justification__c.addError(MSG_JUSTIFICATION);
                }
                if (pending.contains(emp.Id)) {
                    r.Employee__c.addError(MSG_PENDING);
                }
                // P5: snapshot em contexto de sistema; o valor enviado pelo cliente e sempre descartado.
                r.Current_Position__c = emp.Position__c;
                r.Current_Salary__c = emp.Salary__c;
                r.Requested_By__c = me;
            }
        }

        void validateUpdate(List<Promotion_Request__c> records, Map<Id, Promotion_Request__c> oldMap) {
            Date asOf = today();
            List<Promotion_Request__c> becomingPending = new List<Promotion_Request__c>();
            Set<Id> employeeIds = new Set<Id>();
            Set<Id> requestIds = new Set<Id>();
            for (Promotion_Request__c r : records) {
                Promotion_Request__c old = oldMap.get(r.Id);
                if (r.Effective_Date__c != old.Effective_Date__c && r.Effective_Date__c != null && r.Effective_Date__c < asOf) {
                    r.Effective_Date__c.addError(MSG_PAST_DATE);
                }
                if (r.Status__c == ApprovalService.STATUS_PENDING && old.Status__c != ApprovalService.STATUS_PENDING) {
                    becomingPending.add(r);
                    employeeIds.add(r.Employee__c);
                    requestIds.add(r.Id);
                }
            }
            if (becomingPending.isEmpty()) {
                return;
            }
            Set<Id> pending = PromotionRequestSelector.employeesWithPending(employeeIds, requestIds);
            Set<Id> seen = new Set<Id>();
            for (Promotion_Request__c r : becomingPending) {
                if (pending.contains(r.Employee__c) || !seen.add(r.Employee__c)) {
                    r.Employee__c.addError(MSG_PENDING);
                }
            }
        }

        Id currentEmployeeId() {
            Id userId = UserInfo.getUserId();
            List<Employee__c> rows = [SELECT Id FROM Employee__c WHERE User__c = :userId WITH SYSTEM_MODE LIMIT 1];
            return rows.isEmpty() ? null : rows[0].Id;
        }

        /**
         * P1 em lote: o solicitante precisa estar na cadeia de gestores do colaborador. Mesma regra de
         * EmployeeHierarchyService.isInChainOf, mas a partir do Hierarchy_Path__c ja carregado, para nao gastar uma
         * consulta por registro (a trigger precisa suportar 200 pedidos).
         */
        Boolean isInChain(Employee__c employee, Id requesterEmployeeId) {
            if (requesterEmployeeId == null || requesterEmployeeId == employee.Id) {
                return false;
            }
            return new Set<Id>(EmployeeSharingService.pathIds(employee.Hierarchy_Path__c)).contains(requesterEmployeeId);
        }

        // ------------------------------------------------------------------------------------- efetivacao

        Integer effectivate(Set<Id> requestIds) {
            List<Promotion_Request__c> requests = new List<Promotion_Request__c>();
            Set<Id> employeeIds = new Set<Id>();
            for (Promotion_Request__c r : PromotionRequestSelector.systemByIds(requestIds)) {
                if (r.Status__c == ApprovalService.STATUS_APPROVED && r.Proposed_Position__c != null && employeeIds.add(r.Employee__c)) {
                    requests.add(r);
                }
            }
            if (requests.isEmpty()) {
                return 0;
            }
            Map<Id, Employee__c> employees = new Map<Id, Employee__c>(
                [
                    SELECT Id, Name, Department__c, Salary__c, User__c, Manager_User_Id__c
                    FROM Employee__c
                    WHERE Id IN :employeeIds
                    WITH SYSTEM_MODE
                ]
            );
            List<Employee__c> employeeUpdates = new List<Employee__c>();
            List<Promotion_Request__c> candidates = new List<Promotion_Request__c>();
            for (Promotion_Request__c r : requests) {
                if (!employees.containsKey(r.Employee__c)) {
                    continue;
                }
                Employee__c empUpdate = new Employee__c(Id = r.Employee__c, Position__c = r.Proposed_Position__c);
                if (r.Proposed_Salary__c != null) {
                    empUpdate.Salary__c = r.Proposed_Salary__c;
                }
                employeeUpdates.add(empUpdate);
                candidates.add(r);
            }
            List<Database.SaveResult> results = Database.update(employeeUpdates, false);
            List<Promotion_Request__c> done = new List<Promotion_Request__c>();
            List<PositionHistoryService.Change> changes = new List<PositionHistoryService.Change>();
            for (Integer i = 0; i < results.size(); i++) {
                Promotion_Request__c r = candidates[i];
                if (!results[i].isSuccess()) {
                    System.debug(LoggingLevel.WARN, 'Promocao nao efetivada (' + r.Name + '): ' + results[i].getErrors());
                    continue;
                }
                Employee__c emp = employees.get(r.Employee__c);
                done.add(r);
                changes.add(
                    new PositionHistoryService.Change(
                        r.Employee__c,
                        r.Proposed_Position__c,
                        emp.Department__c,
                        r.Proposed_Salary__c != null ? r.Proposed_Salary__c : emp.Salary__c,
                        r.Effective_Date__c,
                        PositionHistoryService.REASON_PROMOTION,
                        r.Id
                    )
                );
            }
            PositionHistoryService.registerChanges(changes);
            List<Promotion_Request__c> statusUpdates = new List<Promotion_Request__c>();
            for (Promotion_Request__c r : done) {
                statusUpdates.add(new Promotion_Request__c(Id = r.Id, Status__c = STATUS_EFFECTIVE));
            }
            update statusUpdates;
            for (Promotion_Request__c r : done) {
                notifyEffectivated(r, employees.get(r.Employee__c));
            }
            return done.size();
        }

        private void notifyEffectivated(Promotion_Request__c r, Employee__c emp) {
            Set<String> recipients = new Set<String>();
            addRecipient(recipients, emp.User__c);
            addRecipient(recipients, emp.Manager_User_Id__c);
            addRecipient(recipients, r.Requested_By__c);
            // O alvo e o colaborador: o gestor e o proprio colaborador leem esse registro, mas nao a solicitacao.
            notifyUsers(
                recipients,
                emp.Id,
                'Promoção efetivada',
                'A promoção de ' + emp.Name + ' foi efetivada em ' + formatDate(r.Effective_Date__c) + '.'
            );
        }

        // ------------------------------------------------------------------------------------- desfecho

        void onApproved(Id requestId) {
            List<Promotion_Request__c> rows = PromotionRequestSelector.systemByIds(new Set<Id>{ requestId });
            if (rows.isEmpty()) {
                return;
            }
            Promotion_Request__c r = rows[0];
            if (r.Effective_Date__c != null && r.Effective_Date__c <= today()) {
                effectivate(new Set<Id>{ requestId });
                return;
            }
            Set<String> recipients = new Set<String>();
            addRecipient(recipients, r.Requested_By__c);
            notifyUsers(
                recipients,
                requestId,
                'Promoção aprovada',
                'A solicitação ' + r.Name + ' foi aprovada e será efetivada em ' + formatDate(r.Effective_Date__c) + '.'
            );
        }

        void onRejected(Id requestId) {
            List<Promotion_Request__c> rows = PromotionRequestSelector.systemByIds(new Set<Id>{ requestId });
            if (rows.isEmpty()) {
                return;
            }
            Set<String> recipients = new Set<String>();
            addRecipient(recipients, rows[0].Requested_By__c);
            notifyUsers(recipients, requestId, 'Promoção rejeitada', 'A solicitação ' + rows[0].Name + ' foi rejeitada.');
        }

        void onStepAdvanced(Id requestId, Integer newStep) {
            List<Promotion_Request__c> rows = PromotionRequestSelector.systemByIds(new Set<Id>{ requestId });
            if (rows.isEmpty()) {
                return;
            }
            Set<String> recipients = new Set<String>();
            addRecipient(recipients, rows[0].Requested_By__c);
            notifyUsers(recipients, requestId, 'Promoção em andamento', 'A solicitação ' + rows[0].Name + ' avançou para a etapa ' + newStep + '.');
        }

        private void addRecipient(Set<String> recipients, Object userId) {
            if (userId != null && String.isNotBlank(String.valueOf(userId))) {
                recipients.add(String.valueOf(userId));
            }
        }

        private void notifyUsers(Set<String> recipients, Id targetId, String title, String body) {
            if (recipients.isEmpty() || notificationsSent >= MAX_NOTIFICATIONS) {
                return;
            }
            notificationsSent++;
            HrNotificationService.notify(recipients, targetId, title, body, 'HR_Request_Decided');
        }
    }
}
