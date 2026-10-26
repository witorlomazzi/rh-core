/**
 * Controller fino dos LWCs de onboarding (onboardingChecklist, onboardingActivation, onboardingOverview). Toda regra
 * esta em OnboardingService; aqui so se converte excecao em mensagem para a tela.
 */
public with sharing class OnboardingController {
    @AuraEnabled
    public static OnboardingService.ChecklistView getChecklist(Id recordId) {
        try {
            return OnboardingService.checklist(recordId);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static void setTaskDone(Id taskId, Boolean done) {
        try {
            OnboardingService.setTaskDone(taskId, done);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static OnboardingService.OverviewResult getOverview(Boolean includeCompleted) {
        try {
            return OnboardingService.overview(includeCompleted);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static OnboardingService.ActivationContext getActivationContext() {
        try {
            return OnboardingService.activationContext();
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static void activate(Id employeeId, String employeeNumber, Date hireDate, Id managerId, Id positionId) {
        try {
            OnboardingService.activate(employeeId, employeeNumber, hireDate, managerId, positionId);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /** O6: refaz prazos e responsaveis das tarefas pendentes do colaborador a partir dos dados atuais. */
    @AuraEnabled
    public static void syncPlan(Id employeeId) {
        try {
            OnboardingService.syncPlans(new Set<Id>{ employeeId });
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    private static AuraHandledException toAura(Exception e) {
        Boolean expected = e instanceof OnboardingService.OnboardingException;
        String message = expected ? e.getMessage() : 'Não foi possível concluir a operação. ' + e.getMessage();
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
