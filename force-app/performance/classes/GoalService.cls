/**
 * Metas do colaborador no ciclo. O colaborador cria e edita as proprias metas enquanto o ciclo esta em
 * Planejado ou Autoavaliacao e a autoavaliacao nao foi enviada (o RH corrige a qualquer momento). Nao ha exclusao
 * pelo colaborador: remover uma meta e cancela-la (Status__c = Cancelada), e so metas Ativas entram na soma de 100%
 * (regra A4, conferida no envio da autoavaliacao).
 */
public with sharing class GoalService {
    public static final String ACTIVE = 'Ativa';
    public static final String CANCELLED = 'Cancelada';
    private static final Set<String> EDITABLE_CYCLE_STATUSES = new Set<String>{
        ReviewCycleService.PLANNED,
        ReviewCycleService.SELF_REVIEW
    };

    public static Boolean isEditableCycleStatus(String cycleStatus) {
        return EDITABLE_CYCLE_STATUSES.contains(cycleStatus);
    }

    /** Cria a meta do colaborador atual no ciclo. */
    public static Goal__c create(Id employeeId, Id cycleId, String name, String target, String description, Decimal weight) {
        Goal__c goal = new Goal__c(
            Employee__c = employeeId,
            Review_Cycle__c = cycleId,
            Name = name,
            Target__c = target,
            Description__c = description,
            Weight__c = weight,
            Status__c = ACTIVE
        );
        insert as user goal;
        return goal;
    }

    /** Atualiza os campos editaveis de uma meta. */
    public static Goal__c modify(Id goalId, String name, String target, String description, Decimal weight, Decimal selfScore) {
        Goal__c goal = new Goal__c(
            Id = goalId,
            Name = name,
            Target__c = target,
            Description__c = description,
            Weight__c = weight,
            Self_Score__c = selfScore
        );
        update as user goal;
        return GoalSelector.byId(goalId);
    }

    /** Nota do colaborador para a meta. */
    public static Goal__c score(Id goalId, Decimal selfScore) {
        Goal__c goal = new Goal__c(Id = goalId, Self_Score__c = selfScore);
        update as user goal;
        return GoalSelector.byId(goalId);
    }

    public static void cancel(Id goalId) {
        Goal__c goal = new Goal__c(Id = goalId, Status__c = CANCELLED);
        update as user goal;
    }

    /** Soma dos pesos das metas ativas, na visao do usuario. */
    public static Decimal activeWeightSum(List<Goal__c> goals) {
        Decimal total = 0;
        for (Goal__c g : goals) {
            if (g.Status__c == ACTIVE && g.Weight__c != null) {
                total += g.Weight__c;
            }
        }
        return total;
    }

    /**
     * Before insert e before update. Peso entre 0 e 100, nota da meta dentro da escala e, para quem nao e RH, o dono
     * da meta com o ciclo editavel e a autoavaliacao ainda nao enviada. Consultas em modo sistema por estarem em trigger.
     */
    public static void validateChanges(List<Goal__c> newList, Map<Id, Goal__c> oldMap) {
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> cycleIds = new Set<Id>();
        Set<String> keys = new Set<String>();
        for (Goal__c g : newList) {
            employeeIds.add(g.Employee__c);
            cycleIds.add(g.Review_Cycle__c);
            if (g.Employee__c != null && g.Review_Cycle__c != null) {
                keys.add(GoalSelector.key(g.Employee__c, g.Review_Cycle__c));
            }
        }
        employeeIds.remove(null);
        Map<Id, Review_Cycle__c> cycles = ReviewCycleSelector.byIdsForValidation(cycleIds);
        Map<Id, Employee__c> employees = SelfAssessmentService.employeesForValidation(employeeIds);
        Map<String, Self_Assessment__c> assessments = SelfAssessmentSelector.byKeysForValidation(keys);
        Boolean hr = ReviewCycleService.isHr();
        Id me = UserInfo.getUserId();

        for (Goal__c g : newList) {
            Goal__c old = oldMap == null ? null : oldMap.get(g.Id);
            Review_Cycle__c cycle = cycles.get(g.Review_Cycle__c);
            if (cycle == null) {
                g.addError('Informe o ciclo de avaliação da meta.');
                continue;
            }
            if (old != null && g.Review_Cycle__c != old.Review_Cycle__c) {
                g.Review_Cycle__c.addError('O ciclo da meta não pode ser alterado.');
                continue;
            }
            if (g.Weight__c == null || g.Weight__c <= 0 || g.Weight__c > 100) {
                g.Weight__c.addError('O peso da meta deve estar entre 1% e 100%.');
                continue;
            }
            if (g.Self_Score__c != null && (g.Self_Score__c < 1 || g.Self_Score__c > cycle.Rating_Scale_Max__c)) {
                g.Self_Score__c.addError('A nota da meta deve estar entre 1 e ' + cycle.Rating_Scale_Max__c.intValue() + '.');
                continue;
            }
            if (hr) {
                continue;
            }
            Employee__c employee = employees.get(g.Employee__c);
            if (employee == null || employee.User__c != me) {
                g.addError('Somente o próprio colaborador registra as metas.');
            } else if (!isEditableCycleStatus(cycle.Status__c)) {
                g.addError('As metas só podem ser alteradas antes da avaliação do gestor.');
            } else {
                Self_Assessment__c sa = assessments.get(GoalSelector.key(g.Employee__c, g.Review_Cycle__c));
                if (sa != null && sa.Submitted__c) {
                    g.addError('As metas ficam bloqueadas depois do envio da autoavaliação.');
                }
            }
        }
    }
}
