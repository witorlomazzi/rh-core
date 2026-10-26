/**
 * Ciclo de avaliacao: validacao, lancamento, avanco de fase e liberacao dos resultados.
 *
 * Contexto de sistema (spec 02, linha "ReviewCycleService.launch"): o lancamento cria avaliacoes e autoavaliacoes
 * para todos os colaboradores ativos, inclusive os que o usuario de RH nao enxerga pelo compartilhamento, e a
 * liberacao grava situacao e nota final em avaliacoes que o RH nao e dono. Por isso a classe e "without sharing".
 * Todo ponto de entrada publico chama requireHr() antes de qualquer leitura ou escrita; createRecords() so e
 * chamado pelo proprio lancamento e pelo ReviewLaunchBatch, que ja passou por essa checagem.
 */
// Contexto de sistema da spec 02: lancamento e liberacao do ciclo (papel de RH checado antes).
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ReviewCycleService {
    public static final String PLANNED = 'Planejado';
    public static final String SELF_REVIEW = 'Autoavaliacao';
    public static final String MANAGER_REVIEW = 'Avaliacao_Gestor';
    public static final String CALIBRATION = 'Calibracao';
    public static final String DONE = 'Concluido';
    public static final String NOTIFICATION_TYPE = 'HR_Performance_Update';
    public static final Integer MIN_SCALE = 2;
    public static final Integer MAX_SCALE = 9;

    private static final Set<String> ACTIVE_EMPLOYEE_STATUSES = new Set<String>{ 'Ativo', 'Ferias' };

    /** Acima disso o lancamento roda em ReviewLaunchBatch. */
    @TestVisible
    private static Integer syncLimit = 200;

    private static Boolean transitionOpen = false;

    public class LaunchResult {
        @AuraEnabled
        public Integer reviewsCreated = 0;
        @AuraEnabled
        public Integer selfAssessmentsCreated = 0;
        @AuraEnabled
        public Integer skipped = 0;
        @AuraEnabled
        public Integer errors = 0;
        @AuraEnabled
        public Boolean async = false;
    }

    public class ReleaseResult {
        @AuraEnabled
        public Integer released = 0;
        @AuraEnabled
        public Integer notReleased = 0;
    }

    // ------------------------------------------------------------------------------------------------- papel

    public static Boolean isHr() {
        return FeatureManagement.checkPermission('HR_Admin_Access');
    }

    public static void requireHr() {
        if (!isHr()) {
            throw new ReviewErrors.ReviewException('Apenas o RH pode executar esta ação.');
        }
    }

    // ------------------------------------------------------------------------------------------- validacao

    /** Chamado pelo ReviewCycleTriggerHandler (before insert e before update). */
    public static void validateChanges(List<Review_Cycle__c> newList, Map<Id, Review_Cycle__c> oldMap) {
        for (Review_Cycle__c c : newList) {
            Review_Cycle__c old = oldMap == null ? null : oldMap.get(c.Id);
            if (old == null) {
                if (c.Status__c != PLANNED) {
                    c.Status__c.addError('Todo ciclo nasce em Planejado.');
                }
            } else {
                if (c.Status__c != old.Status__c && !transitionOpen) {
                    c.Status__c.addError('A situação do ciclo muda apenas pelo painel de ciclos (lançar, avançar fase ou liberar).');
                }
                if (old.Status__c != PLANNED && c.Rating_Scale_Max__c != old.Rating_Scale_Max__c) {
                    c.Rating_Scale_Max__c.addError('A escala de notas não pode mudar depois do lançamento.');
                }
            }
            if (c.Rating_Scale_Max__c == null || c.Rating_Scale_Max__c < MIN_SCALE || c.Rating_Scale_Max__c > MAX_SCALE) {
                c.Rating_Scale_Max__c.addError('A nota máxima deve estar entre ' + MIN_SCALE + ' e ' + MAX_SCALE + '.');
            }
            if (c.Start_Date__c != null && c.End_Date__c != null && c.End_Date__c < c.Start_Date__c) {
                c.End_Date__c.addError('A data final não pode ser anterior à data inicial.');
            }
            if (c.Self_Review_Due__c != null && c.Manager_Review_Due__c != null && c.Manager_Review_Due__c < c.Self_Review_Due__c) {
                c.Manager_Review_Due__c.addError('O prazo do gestor não pode ser anterior ao prazo da autoavaliação.');
            }
        }
    }

    // --------------------------------------------------------------------------------------------- lancamento

    /**
     * Cria uma avaliacao (Pendente, avaliador = usuario do gestor direto) e uma autoavaliacao por colaborador ativo
     * com usuario e muda o ciclo para Autoavaliacao. Idempotente por Unique_Key__c. Acima do limite sincrono o
     * trabalho vai para ReviewLaunchBatch e o ciclo muda de fase no fim do lote.
     */
    public static LaunchResult launch(Id cycleId) {
        requireHr();
        Review_Cycle__c cycle = loadCycle(cycleId);
        if (cycle.Status__c != PLANNED) {
            throw new ReviewErrors.ReviewException('Só é possível lançar um ciclo na situação Planejado.');
        }
        LaunchResult result = new LaunchResult();
        if (eligibleCount() > syncLimit) {
            Database.executeBatch(new ReviewLaunchBatch(cycleId), 200);
            result.async = true;
            return result;
        }
        createRecords(cycle, eligibleEmployees(), result);
        if (result.errors == 0) {
            completeLaunch(cycleId);
        }
        return result;
    }

    /** Muda o ciclo de Planejado para Autoavaliacao. Usado no fim do lancamento sincrono e do lote. */
    public static void completeLaunch(Id cycleId) {
        Review_Cycle__c cycle = loadCycle(cycleId);
        if (cycle.Status__c == PLANNED) {
            setStatus(cycleId, SELF_REVIEW);
        }
    }

    public static Integer eligibleCount() {
        return [SELECT COUNT() FROM Employee__c WHERE Status__c IN :ACTIVE_EMPLOYEE_STATUSES AND User__c != NULL];
    }

    public static List<Employee__c> eligibleEmployees() {
        return [
            SELECT Id, Name, Manager__c, User__c
            FROM Employee__c
            WHERE Status__c IN :ACTIVE_EMPLOYEE_STATUSES AND User__c != NULL
            ORDER BY Employee_Number__c
        ];
    }

    public static Database.QueryLocator eligibleLocator() {
        return Database.getQueryLocator(
            [
                SELECT Id, Name, Manager__c, User__c
                FROM Employee__c
                WHERE Status__c IN :ACTIVE_EMPLOYEE_STATUSES AND User__c != NULL
                ORDER BY Employee_Number__c
            ]
        );
    }

    /**
     * Cria o que ainda nao existe para os colaboradores informados e acumula os numeros em result. Sem SOQL nem
     * DML em loop. Registros duplicados por corrida caem na restricao de unicidade e contam como "skipped".
     */
    public static void createRecords(Review_Cycle__c cycle, List<Employee__c> employees, LaunchResult result) {
        if (employees == null || employees.isEmpty()) {
            return;
        }
        Set<String> keys = new Set<String>();
        Set<Id> managerIds = new Set<Id>();
        for (Employee__c e : employees) {
            keys.add(GoalSelector.key(e.Id, cycle.Id));
            managerIds.add(e.Manager__c);
        }
        managerIds.remove(null);
        Set<String> existingReviews = PerformanceReviewSelector.existingKeys(keys);
        Set<String> existingSelf = SelfAssessmentSelector.byKeysForValidation(keys).keySet();
        Map<Id, Id> managerUsers = new Map<Id, Id>();
        for (Employee__c m : [SELECT Id, User__c FROM Employee__c WHERE Id IN :managerIds]) {
            managerUsers.put(m.Id, m.User__c);
        }

        List<Self_Assessment__c> selfToInsert = new List<Self_Assessment__c>();
        List<Performance_Review__c> reviewsToInsert = new List<Performance_Review__c>();
        for (Employee__c e : employees) {
            String key = GoalSelector.key(e.Id, cycle.Id);
            if (existingSelf.contains(key) && existingReviews.contains(key)) {
                result.skipped++;
                continue;
            }
            if (!existingSelf.contains(key)) {
                selfToInsert.add(new Self_Assessment__c(Employee__c = e.Id, Review_Cycle__c = cycle.Id, Unique_Key__c = key));
            }
            if (!existingReviews.contains(key)) {
                reviewsToInsert.add(
                    new Performance_Review__c(
                        Employee__c = e.Id,
                        Review_Cycle__c = cycle.Id,
                        Reviewer__c = managerUsers.get(e.Manager__c),
                        Status__c = 'Pendente',
                        Unique_Key__c = key
                    )
                );
            }
        }

        Set<String> notifyUserIds = new Set<String>();
        Map<Id, Employee__c> byId = new Map<Id, Employee__c>(employees);
        SelfAssessmentService.beginTrusted();
        PerformanceReviewService.beginTrusted();
        try {
            for (Database.SaveResult r : Database.insert(selfToInsert, false)) {
                if (r.isSuccess()) {
                    result.selfAssessmentsCreated++;
                } else {
                    result.errors++;
                }
            }
            for (Database.SaveResult r : Database.insert(reviewsToInsert, false)) {
                if (r.isSuccess()) {
                    result.reviewsCreated++;
                } else {
                    result.errors++;
                }
            }
        } finally {
            SelfAssessmentService.endTrusted();
            PerformanceReviewService.endTrusted();
        }
        for (Self_Assessment__c sa : selfToInsert) {
            Employee__c e = byId.get(sa.Employee__c);
            if (sa.Id != null && e != null && e.User__c != null) {
                notifyUserIds.add(String.valueOf(e.User__c));
            }
        }
        HrNotificationService.notify(
            notifyUserIds,
            cycle.Id,
            'Avaliação de desempenho aberta',
            'O ciclo "' + cycle.Name + '" começou. Registre suas metas e faça a autoavaliação.',
            NOTIFICATION_TYPE
        );
    }

    // ---------------------------------------------------------------------------------------------- fases

    /** Autoavaliacao para Avaliacao_Gestor e Avaliacao_Gestor para Calibracao. Calibracao termina em release(). */
    public static Review_Cycle__c advance(Id cycleId) {
        requireHr();
        Review_Cycle__c cycle = loadCycle(cycleId);
        String next;
        if (cycle.Status__c == SELF_REVIEW) {
            next = MANAGER_REVIEW;
        } else if (cycle.Status__c == MANAGER_REVIEW) {
            next = CALIBRATION;
        } else if (cycle.Status__c == PLANNED) {
            throw new ReviewErrors.ReviewException('Lance o ciclo antes de avançar a fase.');
        } else if (cycle.Status__c == CALIBRATION) {
            throw new ReviewErrors.ReviewException('Use a liberação dos resultados para concluir o ciclo.');
        } else {
            throw new ReviewErrors.ReviewException('O ciclo já foi concluído.');
        }
        setStatus(cycleId, next);
        return loadCycle(cycleId);
    }

    /**
     * Libera os resultados: avaliacoes Enviada ou Calibrada viram Liberada com a nota final (calibrada, se houver)
     * e o colaborador passa a ler a propria avaliacao (share Employee_Release__c, criado pelo trigger). O ciclo
     * vira Concluido e os colaboradores sao notificados.
     */
    public static ReleaseResult release(Id cycleId) {
        requireHr();
        Review_Cycle__c cycle = loadCycle(cycleId);
        if (cycle.Status__c != CALIBRATION) {
            throw new ReviewErrors.ReviewException('A liberação só é possível com o ciclo em Calibração.');
        }
        List<Performance_Review__c> toRelease = PerformanceReviewSelector.forServiceByCycleAndStatuses(
            cycleId,
            new Set<String>{ 'Enviada', 'Calibrada' }
        );
        if (toRelease.isEmpty()) {
            throw new ReviewErrors.ReviewException('Nenhuma avaliação enviada ou calibrada para liberar.');
        }
        Datetime now = System.now();
        Set<String> notifyUserIds = new Set<String>();
        List<Performance_Review__c> updates = new List<Performance_Review__c>();
        for (Performance_Review__c r : toRelease) {
            updates.add(
                new Performance_Review__c(
                    Id = r.Id,
                    Status__c = 'Liberada',
                    Released_Date__c = now,
                    Final_Rating__c = r.Calibrated_Rating__c != null ? r.Calibrated_Rating__c : r.Manager_Rating__c
                )
            );
            if (r.Employee__r.User__c != null) {
                notifyUserIds.add(String.valueOf(r.Employee__r.User__c));
            }
        }
        PerformanceReviewService.beginTrusted();
        try {
            update updates;
        } finally {
            PerformanceReviewService.endTrusted();
        }
        setStatus(cycleId, DONE);

        ReleaseResult result = new ReleaseResult();
        result.released = updates.size();
        result.notReleased = [
            SELECT COUNT()
            FROM Performance_Review__c
            WHERE Review_Cycle__c = :cycleId AND Status__c != 'Liberada'
        ];
        HrNotificationService.notify(
            notifyUserIds,
            cycleId,
            'Resultado da avaliação liberado',
            'O resultado do ciclo "' + cycle.Name + '" já está disponível.',
            NOTIFICATION_TYPE
        );
        return result;
    }

    // ---------------------------------------------------------------------------------------------- apoio

    public static Review_Cycle__c loadCycle(Id cycleId) {
        Review_Cycle__c cycle = ReviewCycleSelector.byIdsForValidation(new Set<Id>{ cycleId }).get(cycleId);
        if (cycle == null) {
            throw new ReviewErrors.ReviewException('Ciclo de avaliação não encontrado.');
        }
        return cycle;
    }

    private static void setStatus(Id cycleId, String status) {
        transitionOpen = true;
        try {
            update new Review_Cycle__c(Id = cycleId, Status__c = status);
        } finally {
            transitionOpen = false;
        }
    }
}
