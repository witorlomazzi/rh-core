/**
 * Controller fino da autoavaliacao (performanceMyCycle). As regras A3 e A4 ficam no trigger via SelfAssessmentService.
 */
public with sharing class SelfAssessmentController {
    @AuraEnabled
    public static void saveDraft(Id assessmentId, Decimal rating, String strengths, String improvements) {
        try {
            SelfAssessmentService.save(assessmentId, rating, strengths, improvements);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static void submitAssessment(Id assessmentId, Decimal rating, String strengths, String improvements) {
        try {
            SelfAssessmentService.submitAssessment(assessmentId, rating, strengths, improvements);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }
}
