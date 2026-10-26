/**
 * Autoavaliacao: gravacao pelo colaborador e as travas da regra A3 e A4. As regras ficam no trigger (via
 * validateChanges) para valerem tambem fora das telas; save e submitAssessment so gravam como o usuario e deixam a
 * validacao responder.
 */
public with sharing class SelfAssessmentService {
    private static Boolean trusted = false;

    public static void beginTrusted() {
        trusted = true;
    }

    public static void endTrusted() {
        trusted = false;
    }

    public static Boolean isTrusted() {
        return trusted;
    }

    /** Grava o rascunho da autoavaliacao do proprio colaborador. */
    public static Self_Assessment__c save(Id assessmentId, Decimal rating, String strengths, String improvements) {
        return write(assessmentId, rating, strengths, improvements, false);
    }

    /** Envia a autoavaliacao: exige nota e metas somando 100%; depois do envio nada mais muda. */
    public static Self_Assessment__c submitAssessment(Id assessmentId, Decimal rating, String strengths, String improvements) {
        return write(assessmentId, rating, strengths, improvements, true);
    }

    private static Self_Assessment__c write(Id assessmentId, Decimal rating, String strengths, String improvements, Boolean submitting) {
        Self_Assessment__c changes = new Self_Assessment__c(
            Id = assessmentId,
            Self_Rating__c = rating,
            Strengths__c = strengths,
            Improvements__c = improvements
        );
        if (submitting) {
            changes.Submitted__c = true;
        }
        update as user changes;
        return SelfAssessmentSelector.byId(assessmentId);
    }

    /** Before insert: chave unica quando faltar. */
    public static void prepareInsert(List<Self_Assessment__c> newList) {
        for (Self_Assessment__c sa : newList) {
            if (sa.Employee__c != null && sa.Review_Cycle__c != null && String.isBlank(sa.Unique_Key__c)) {
                sa.Unique_Key__c = GoalSelector.key(sa.Employee__c, sa.Review_Cycle__c);
            }
        }
    }

    /**
     * Before insert e before update. A3: so o proprio colaborador edita, com o ciclo em Autoavaliacao, e depois do
     * envio nada muda; nota entre 1 e Rating_Scale_Max__c. A4: o envio exige metas ativas somando 100%.
     * As consultas rodam em modo sistema por estarem em trigger (ver ReviewCycleSelector).
     */
    public static void validateChanges(List<Self_Assessment__c> newList, Map<Id, Self_Assessment__c> oldMap) {
        if (trusted) {
            return;
        }
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> cycleIds = new Set<Id>();
        for (Self_Assessment__c sa : newList) {
            employeeIds.add(sa.Employee__c);
            cycleIds.add(sa.Review_Cycle__c);
        }
        employeeIds.remove(null);
        Map<Id, Review_Cycle__c> cycles = ReviewCycleSelector.byIdsForValidation(cycleIds);
        Map<Id, Employee__c> employees = employeesForValidation(employeeIds);
        Map<String, Decimal> weights = GoalSelector.activeWeightSumsForValidation(employeeIds, cycleIds);
        Id me = UserInfo.getUserId();

        for (Self_Assessment__c sa : newList) {
            Self_Assessment__c old = oldMap == null ? null : oldMap.get(sa.Id);
            if (old != null && old.Submitted__c) {
                sa.addError('Autoavaliação já enviada não pode ser alterada.');
                continue;
            }
            if (old != null && (sa.Employee__c != old.Employee__c || sa.Review_Cycle__c != old.Review_Cycle__c || sa.Unique_Key__c != old.Unique_Key__c)) {
                sa.addError('O colaborador e o ciclo da autoavaliação não podem ser alterados.');
                continue;
            }
            Employee__c employee = employees.get(sa.Employee__c);
            if (employee == null || employee.User__c != me) {
                sa.addError('Somente o próprio colaborador pode preencher a autoavaliação.');
                continue;
            }
            Review_Cycle__c cycle = cycles.get(sa.Review_Cycle__c);
            if (cycle == null || cycle.Status__c != ReviewCycleService.SELF_REVIEW) {
                sa.addError('A autoavaliação só pode ser preenchida enquanto o ciclo está em Autoavaliação.');
                continue;
            }
            if (sa.Self_Rating__c != null && (sa.Self_Rating__c < 1 || sa.Self_Rating__c > cycle.Rating_Scale_Max__c)) {
                sa.Self_Rating__c.addError('A nota deve estar entre 1 e ' + cycle.Rating_Scale_Max__c.intValue() + '.');
                continue;
            }
            if (sa.Submitted__c) {
                if (sa.Self_Rating__c == null) {
                    sa.Self_Rating__c.addError('Informe a nota da autoavaliação para enviar.');
                    continue;
                }
                Decimal total = weights.get(GoalSelector.key(sa.Employee__c, sa.Review_Cycle__c));
                if (total == null || total != 100) {
                    sa.addError(
                        'Os pesos das metas ativas somam ' + (total == null ? 0 : total) + '%. É preciso fechar 100% para enviar a autoavaliação.'
                    );
                    continue;
                }
                sa.Submitted_Date__c = System.now();
            } else {
                sa.Submitted_Date__c = null;
            }
        }
    }

    // Modo sistema por estar em trigger: o colaborador e o gestor nao leem o cadastro um do outro por USER_MODE.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Map<Id, Employee__c> employeesForValidation(Set<Id> employeeIds) {
        return new Map<Id, Employee__c>([SELECT Id, User__c FROM Employee__c WHERE Id IN :employeeIds]);
    }
}
