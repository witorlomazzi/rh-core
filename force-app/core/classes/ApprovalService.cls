/**
 * Motor de aprovacao proprio, configurado por HR_Approval_Step__mdt. Usado por ferias (Leave) e promocoes
 * (Promotion). As etapas viram registros Approval_Step__c com share de leitura para o aprovador ou para o
 * grupo HR_Team. Ao final, o handler da configuracao (Outcome_Handler__c) e chamado.
 *
 * Leituras de validacao (o pedido existe e o usuario pode ve-lo) sao em USER_MODE. As escritas de status e de
 * etapas sao feitas pela classe interna Privileged, em contexto de sistema, porque o aprovador nao tem Edit no
 * Status__c do pedido (spec 02); antes de cada escrita o servico valida quem pode decidir.
 */
// Escritas de status e etapas em contexto de sistema (spec 02, ApprovalService.decide); leitura de Group e de pedidos ja validados.
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class ApprovalService {
    public static final String STATUS_DRAFT = 'Rascunho';
    public static final String STATUS_PENDING = 'Pendente';
    public static final String STATUS_APPROVED = 'Aprovado';
    public static final String STATUS_REJECTED = 'Rejeitado';
    public static final String STATUS_CANCELLED = 'Cancelado';
    public static final String SKIPPED_COMMENT = 'Etapa pulada: aprovador indisponível';

    @TestVisible
    private static List<HR_Approval_Step__mdt> testSteps;

    public class ApprovalException extends Exception {
    }

    private class RequestConfig {
        SObjectType objectType;
        String lookupField;
        RequestConfig(SObjectType objectType, String lookupField) {
            this.objectType = objectType;
            this.lookupField = lookupField;
        }
    }

    private static final Map<String, RequestConfig> CONFIGS = new Map<String, RequestConfig>{
        'Leave' => new RequestConfig(Leave_Request__c.SObjectType, 'Leave_Request__c'),
        'Promotion' => new RequestConfig(Promotion_Request__c.SObjectType, 'Promotion_Request__c')
    };

    // ------------------------------------------------------------------------------------------------- API

    /** Envia o pedido para aprovacao: cria a primeira etapa com aprovador disponivel. Somente o solicitante. */
    public static void submit(Id requestId, String requestType) {
        RequestConfig cfg = config(requestType);
        SObject request = loadRequestAsUser(cfg, requestId);
        if (requesterOf(request) != UserInfo.getUserId()) {
            throw new ApprovalException('Somente quem fez a solicitação pode enviá-la para aprovação.');
        }
        if ((String) request.get('Status__c') != STATUS_DRAFT) {
            throw new ApprovalException('Somente solicitações em rascunho podem ser enviadas para aprovação.');
        }
        List<HR_Approval_Step__mdt> steps = stepsFor(requestType);
        if (steps.isEmpty()) {
            throw new ApprovalException('Nenhuma etapa de aprovação ativa configurada para ' + requestType + '.');
        }
        Savepoint sp = Database.setSavepoint();
        try {
            new Privileged().advanceFrom(cfg, requestType, request, steps, 0);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    /**
     * Registra a decisao do usuario atual na etapa. Rejeicao exige comentario. Ninguem decide a propria solicitacao,
     * nem como solicitante nem como o colaborador do pedido: na etapa do RH, outro membro do grupo decide.
     */
    public static void decide(Id approvalStepId, Boolean approve, String comments) {
        Privileged p = new Privileged();
        Approval_Step__c step = p.loadStep(approvalStepId);
        if (step == null) {
            throw new ApprovalException('Etapa de aprovação não encontrada.');
        }
        if (step.Status__c != STATUS_PENDING) {
            throw new ApprovalException('Esta etapa já foi decidida.');
        }
        if (!canDecide(step)) {
            throw new ApprovalException('Você não é o aprovador desta etapa.');
        }
        String requestType = step.Request_Type__c;
        RequestConfig cfg = config(requestType);
        SObject request = p.loadRequest(cfg, (Id) step.get(cfg.lookupField));
        if (isOwnRequest(request)) {
            throw new ApprovalException('Você não pode decidir a própria solicitação.');
        }
        if (approve != true && String.isBlank(comments)) {
            throw new ApprovalException('Informe um comentário para rejeitar a solicitação.');
        }
        Savepoint sp = Database.setSavepoint();
        try {
            applyDecision(p, cfg, requestType, step, request, approve == true, comments);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    private static void applyDecision(
        Privileged p,
        RequestConfig cfg,
        String requestType,
        Approval_Step__c step,
        SObject request,
        Boolean approve,
        String comments
    ) {
        p.recordDecision(step, approve, comments);
        List<HR_Approval_Step__mdt> steps = stepsFor(requestType);
        if (approve) {
            Integer nextIndex = steps.size();
            for (Integer i = 0; i < steps.size(); i++) {
                if (steps[i].Step_Order__c > step.Step_Order__c) {
                    nextIndex = i;
                    break;
                }
            }
            p.advanceFrom(cfg, requestType, request, steps, nextIndex);
        } else {
            p.reject(cfg, requestType, request, steps);
        }
    }

    /** Cancela um pedido pendente. Somente o solicitante. */
    public static void cancel(Id requestId, String requestType) {
        RequestConfig cfg = config(requestType);
        SObject request = loadRequestAsUser(cfg, requestId);
        if (requesterOf(request) != UserInfo.getUserId()) {
            throw new ApprovalException('Somente quem fez a solicitação pode cancelá-la.');
        }
        if ((String) request.get('Status__c') != STATUS_PENDING) {
            throw new ApprovalException('Somente solicitações pendentes podem ser canceladas.');
        }
        new Privileged().cancel(cfg, request);
    }

    /** Etapas pendentes que o usuario atual pode decidir. */
    public static List<ApprovalItem> pendingForCurrentUser() {
        List<Approval_Step__c> steps = ApprovalStepSelector.pendingForUser(UserInfo.getUserId(), isHrMember());
        Set<Id> leaveIds = new Set<Id>();
        Set<Id> promotionIds = new Set<Id>();
        for (Approval_Step__c s : steps) {
            Id leaveId = (Id) ApprovalStepSelector.valueOf(s, 'Leave_Request__c');
            Id promotionId = (Id) ApprovalStepSelector.valueOf(s, 'Promotion_Request__c');
            if (leaveId != null) {
                leaveIds.add(leaveId);
            }
            if (promotionId != null) {
                promotionIds.add(promotionId);
            }
        }
        Map<Id, SObject> requests = new Map<Id, SObject>();
        requests.putAll(requestSummaries('Leave_Request__c', leaveIds));
        requests.putAll(requestSummaries('Promotion_Request__c', promotionIds));
        // A etapa do RH aparece para todo o grupo; a propria solicitacao fica fora da caixa de quem a fez.
        Privileged p = new Privileged();
        Set<Id> ownIds = p.ownRequestIds('Leave_Request__c', leaveIds);
        ownIds.addAll(p.ownRequestIds('Promotion_Request__c', promotionIds));
        List<ApprovalItem> items = new List<ApprovalItem>();
        for (Approval_Step__c s : steps) {
            ApprovalItem item = new ApprovalItem(s, null);
            if (ownIds.contains(item.requestId)) {
                continue;
            }
            item.setRequest(requests.get(item.requestId));
            items.add(item);
        }
        return items;
    }

    /** Verdadeiro se o usuario atual pertence ao grupo de RH configurado. */
    public static Boolean isHrMember() {
        Id groupId = hrGroupId();
        if (groupId == null) {
            return false;
        }
        return [SELECT COUNT() FROM GroupMember WHERE GroupId = :groupId AND UserOrGroupId = :UserInfo.getUserId()] > 0;
    }

    // ------------------------------------------------------------------------------------------- DTO

    public class ApprovalItem {
        @AuraEnabled
        public Id stepId;
        @AuraEnabled
        public String stepName;
        @AuraEnabled
        public Integer stepOrder;
        @AuraEnabled
        public String approverType;
        @AuraEnabled
        public String requestType;
        @AuraEnabled
        public Id requestId;
        @AuraEnabled
        public String requestName;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public Datetime createdDate;

        public ApprovalItem(Approval_Step__c step, SObject request) {
            this.stepId = step.Id;
            this.stepName = step.Name;
            this.stepOrder = step.Step_Order__c == null ? null : step.Step_Order__c.intValue();
            this.approverType = step.Approver_Type__c;
            this.requestType = step.Request_Type__c;
            Id leaveId = (Id) ApprovalStepSelector.valueOf(step, 'Leave_Request__c');
            this.requestId = leaveId != null ? leaveId : (Id) ApprovalStepSelector.valueOf(step, 'Promotion_Request__c');
            this.createdDate = step.CreatedDate;
            setRequest(request);
        }

        public void setRequest(SObject request) {
            if (request != null) {
                this.requestName = (String) request.get('Name');
                SObject emp = request.getSObject('Employee__r');
                this.employeeName = emp == null ? null : (String) emp.get('Name');
            }
        }
    }

    // ------------------------------------------------------------------------------------------- internos

    private static RequestConfig config(String requestType) {
        RequestConfig cfg = CONFIGS.get(requestType);
        if (cfg == null) {
            throw new ApprovalException('Tipo de solicitação desconhecido: ' + requestType);
        }
        return cfg;
    }

    @TestVisible
    private static List<HR_Approval_Step__mdt> stepsFor(String requestType) {
        List<HR_Approval_Step__mdt> source = testSteps != null ? testSteps : HR_Approval_Step__mdt.getAll().values();
        List<HR_Approval_Step__mdt> result = new List<HR_Approval_Step__mdt>();
        for (HR_Approval_Step__mdt s : source) {
            if (s.Active__c && s.Request_Type__c == requestType) {
                result.add(s);
            }
        }
        // ordenacao simples por Step_Order__c (poucos registros)
        for (Integer i = 0; i < result.size(); i++) {
            for (Integer j = i + 1; j < result.size(); j++) {
                if (result[j].Step_Order__c < result[i].Step_Order__c) {
                    HR_Approval_Step__mdt tmp = result[i];
                    result[i] = result[j];
                    result[j] = tmp;
                }
            }
        }
        return result;
    }

    private static SObject loadRequestAsUser(RequestConfig cfg, Id requestId) {
        String soql =
            'SELECT Id, Name, Employee__c, Status__c, Current_Step__c, Requested_By__c, CreatedById FROM ' +
            cfg.objectType.getDescribe().getName() +
            ' WHERE Id = :requestId';
        List<SObject> rows = Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'requestId' => requestId },
            AccessLevel.USER_MODE
        );
        if (rows.isEmpty()) {
            throw new ApprovalException('Solicitação não encontrada ou sem acesso.');
        }
        return rows[0];
    }

    private static Map<Id, SObject> requestSummaries(String objectName, Set<Id> ids) {
        if (ids.isEmpty()) {
            return new Map<Id, SObject>();
        }
        try {
            return new Map<Id, SObject>(
                Database.queryWithBinds(
                    'SELECT Id, Name, Employee__r.Name FROM ' + objectName + ' WHERE Id IN :ids',
                    new Map<String, Object>{ 'ids' => ids },
                    AccessLevel.USER_MODE
                )
            );
        } catch (QueryException e) {
            // Sem acesso ao objeto do pedido: a caixa mostra a etapa sem o resumo.
            return new Map<Id, SObject>();
        }
    }

    private static Id requesterOf(SObject request) {
        Id requester = (Id) request.get('Requested_By__c');
        return requester != null ? requester : (Id) request.get('CreatedById');
    }

    /** O usuario atual fez a solicitacao ou e o colaborador dela (pedido aberto por outra pessoa em seu nome). */
    private static Boolean isOwnRequest(SObject request) {
        Id me = UserInfo.getUserId();
        if (requesterOf(request) == me) {
            return true;
        }
        SObject employee = request.getSObject('Employee__r');
        return employee != null && (Id) employee.get('User__c') == me;
    }

    private static Boolean canDecide(Approval_Step__c step) {
        if (step.Approver_Type__c == 'HR_Team') {
            return isHrMember();
        }
        return step.Approver__c == UserInfo.getUserId();
    }

    private static Id cachedHrGroupId;
    private static Id hrGroupId() {
        if (cachedHrGroupId == null) {
            String devName = HrSettings.get().HR_Group_Developer_Name__c;
            List<Group> groups = [SELECT Id FROM Group WHERE DeveloperName = :devName AND Type = 'Regular' LIMIT 1];
            cachedHrGroupId = groups.isEmpty() ? null : groups[0].Id;
        }
        return cachedHrGroupId;
    }

    private static ApprovalOutcomeHandler handlerFor(List<HR_Approval_Step__mdt> steps) {
        String className = steps.isEmpty() ? null : steps[0].Outcome_Handler__c;
        if (String.isBlank(className)) {
            return new NoopApprovalHandler();
        }
        Type t = Type.forName(className);
        if (t == null) {
            throw new ApprovalException('Classe de desfecho de aprovação não encontrada: ' + className);
        }
        Object instance = t.newInstance();
        if (!(instance instanceof ApprovalOutcomeHandler)) {
            throw new ApprovalException('A classe ' + className + ' não implementa ApprovalOutcomeHandler.');
        }
        return (ApprovalOutcomeHandler) instance;
    }

    /**
     * Escritas privilegiadas do motor. Contexto de sistema documentado na spec 02: o aprovador nao edita Status__c
     * do pedido e o solicitante nao cria shares; as permissoes ja foram validadas pelos metodos publicos.
     */
    private without sharing class Privileged {
        Approval_Step__c loadStep(Id stepId) {
            List<Approval_Step__c> rows = [
                SELECT Id, Name, Request_Type__c, Leave_Request__c, Promotion_Request__c, Step_Order__c, Approver_Type__c,
                    Approver__c, Status__c
                FROM Approval_Step__c
                WHERE Id = :stepId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        SObject loadRequest(RequestConfig cfg, Id requestId) {
            return Database.queryWithBinds(
                'SELECT Id, Name, Employee__c, Employee__r.User__c, Status__c, Current_Step__c, Requested_By__c, CreatedById FROM ' +
                    cfg.objectType.getDescribe().getName() +
                    ' WHERE Id = :requestId',
                new Map<String, Object>{ 'requestId' => requestId },
                AccessLevel.SYSTEM_MODE
            )[0];
        }

        /** Dos pedidos informados, os que o usuario atual fez ou dos quais e o colaborador. */
        Set<Id> ownRequestIds(String objectName, Set<Id> ids) {
            Set<Id> own = new Set<Id>();
            if (ids.isEmpty()) {
                return own;
            }
            for (SObject r : Database.queryWithBinds(
                'SELECT Id, Requested_By__c, CreatedById, Employee__r.User__c FROM ' + objectName + ' WHERE Id IN :ids',
                new Map<String, Object>{ 'ids' => ids },
                AccessLevel.SYSTEM_MODE
            )) {
                if (isOwnRequest(r)) {
                    own.add(r.Id);
                }
            }
            return own;
        }

        void recordDecision(Approval_Step__c step, Boolean approve, String comments) {
            update new Approval_Step__c(
                Id = step.Id,
                Status__c = approve ? STATUS_APPROVED : STATUS_REJECTED,
                Decided_By__c = UserInfo.getUserId(),
                Decision_Date__c = System.now(),
                Comments__c = comments
            );
        }

        /** Cria a proxima etapa com aprovador disponivel a partir de fromIndex; sem etapas restantes, aprova. */
        void advanceFrom(RequestConfig cfg, String requestType, SObject request, List<HR_Approval_Step__mdt> steps, Integer fromIndex) {
            Id requestId = (Id) request.get('Id');
            Id requester = requesterOf(request);
            Employee__c employee = new Employee__c(Id = (Id) request.get('Employee__c'));
            Boolean wasDraft = (String) request.get('Status__c') == STATUS_DRAFT;
            ApprovalOutcomeHandler handler = handlerFor(steps);
            List<Approval_Step__c> skipped = new List<Approval_Step__c>();
            Approval_Step__c pending;
            for (Integer i = fromIndex; i < steps.size() && pending == null; i++) {
                HR_Approval_Step__mdt cfgStep = steps[i];
                Approval_Step__c step = new Approval_Step__c(
                    Request_Type__c = requestType,
                    Step_Order__c = cfgStep.Step_Order__c,
                    Approver_Type__c = cfgStep.Approver_Type__c
                );
                step.put(cfg.lookupField, requestId);
                if (cfgStep.Approver_Type__c == 'HR_Team') {
                    step.Status__c = STATUS_PENDING;
                    pending = step;
                    continue;
                }
                Id approver = cfgStep.Approver_Type__c == 'Second_Level_Manager'
                    ? EmployeeHierarchyService.secondLevelManagerUserId(employee)
                    : EmployeeHierarchyService.directManagerUserId(employee);
                step.Approver__c = approver;
                if (approver == null || approver == requester) {
                    step.Status__c = STATUS_APPROVED;
                    step.Comments__c = SKIPPED_COMMENT;
                    step.Decision_Date__c = System.now();
                    skipped.add(step);
                } else {
                    step.Status__c = STATUS_PENDING;
                    pending = step;
                }
            }
            List<Approval_Step__c> toInsert = new List<Approval_Step__c>(skipped);
            if (pending != null) {
                toInsert.add(pending);
            }
            insert toInsert;

            SObject requestUpdate = cfg.objectType.newSObject(requestId);
            if (pending != null) {
                shareStep(pending);
                requestUpdate.put('Status__c', STATUS_PENDING);
                requestUpdate.put('Current_Step__c', pending.Step_Order__c);
                if (wasDraft && request.get('Requested_By__c') == null) {
                    requestUpdate.put('Requested_By__c', requester);
                }
                update requestUpdate;
                notifyApprover(pending, request);
                if (!wasDraft) {
                    handler.onStepAdvanced(requestId, pending.Step_Order__c.intValue());
                }
            } else {
                requestUpdate.put('Status__c', STATUS_APPROVED);
                update requestUpdate;
                handler.onApproved(requestId);
            }
        }

        void reject(RequestConfig cfg, String requestType, SObject request, List<HR_Approval_Step__mdt> steps) {
            Id requestId = (Id) request.get('Id');
            ApprovalOutcomeHandler handler = handlerFor(steps);
            closePendingSteps(cfg, requestId);
            SObject requestUpdate = cfg.objectType.newSObject(requestId);
            requestUpdate.put('Status__c', STATUS_REJECTED);
            update requestUpdate;
            handler.onRejected(requestId);
        }

        void cancel(RequestConfig cfg, SObject request) {
            Id requestId = (Id) request.get('Id');
            closePendingSteps(cfg, requestId);
            SObject requestUpdate = cfg.objectType.newSObject(requestId);
            requestUpdate.put('Status__c', STATUS_CANCELLED);
            update requestUpdate;
        }

        private void closePendingSteps(RequestConfig cfg, Id requestId) {
            List<Approval_Step__c> open = Database.queryWithBinds(
                'SELECT Id FROM Approval_Step__c WHERE Status__c = \'Pendente\' AND ' + cfg.lookupField + ' = :requestId',
                new Map<String, Object>{ 'requestId' => requestId },
                AccessLevel.SYSTEM_MODE
            );
            for (Approval_Step__c s : open) {
                s.Status__c = STATUS_CANCELLED;
            }
            update open;
        }

        private void shareStep(Approval_Step__c step) {
            Id target = step.Approver_Type__c == 'HR_Team' ? hrGroupId() : step.Approver__c;
            if (target == null || target == UserInfo.getUserId()) {
                return;
            }
            Database.SaveResult r = Database.insert(
                new Approval_Step__Share(
                    ParentId = step.Id,
                    UserOrGroupId = target,
                    AccessLevel = 'Read',
                    RowCause = Schema.Approval_Step__Share.RowCause.Approver__c
                ),
                false
            );
            if (!r.isSuccess()) {
                System.debug(LoggingLevel.WARN, 'Share da etapa nao criado: ' + r.getErrors());
            }
        }

        private void notifyApprover(Approval_Step__c step, SObject request) {
            Id target = step.Approver_Type__c == 'HR_Team' ? hrGroupId() : step.Approver__c;
            if (target == null) {
                return;
            }
            HrNotificationService.notify(
                new Set<String>{ String.valueOf(target) },
                (Id) request.get('Id'),
                'Aprovação pendente',
                'A solicitação ' + (String) request.get('Name') + ' aguarda a sua decisão.',
                'HR_Approval_Pending'
            );
        }
    }
}
