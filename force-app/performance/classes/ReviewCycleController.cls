/**
 * Controller fino do painel do ciclo (performanceCycleAdmin), exclusivo do RH. Cada metodo confere o papel de RH
 * antes de agir; lancar, avancar e liberar passam pelo ReviewCycleService (contexto de sistema documentado).
 */
public with sharing class ReviewCycleController {
    public class StatusCount {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Integer total;
    }

    public class Overview {
        @AuraEnabled
        public PerformanceReviewController.CycleDto cycle;
        @AuraEnabled
        public Integer eligibleEmployees = 0;
        @AuraEnabled
        public Integer selfTotal = 0;
        @AuraEnabled
        public Integer selfSubmitted = 0;
        @AuraEnabled
        public Integer reviewTotal = 0;
        @AuraEnabled
        public Integer withoutReviewer = 0;
        @AuraEnabled
        public List<StatusCount> reviewsByStatus = new List<StatusCount>();
    }

    public class CalibrationRow {
        @AuraEnabled
        public Id reviewId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Decimal managerRating;
        @AuraEnabled
        public Decimal calibratedRating;
        @AuraEnabled
        public Decimal finalRating;
        @AuraEnabled
        public Boolean canCalibrate = false;
    }

    private static final List<String> REVIEW_STATUSES = new List<String>{
        PerformanceReviewService.PENDING,
        PerformanceReviewService.IN_PROGRESS,
        PerformanceReviewService.SENT,
        PerformanceReviewService.CALIBRATED,
        PerformanceReviewService.RELEASED
    };

    @AuraEnabled
    public static Overview getOverview(Id cycleId) {
        try {
            ReviewCycleService.requireHr();
            Review_Cycle__c cycle = ReviewCycleSelector.byId(cycleId);
            if (cycle == null) {
                throw new ReviewErrors.ReviewException('Ciclo de avaliação não encontrado.');
            }
            Overview view = new Overview();
            view.cycle = new PerformanceReviewController.CycleDto(cycle);
            view.eligibleEmployees = ReviewCycleService.eligibleCount();
            List<Integer> self = SelfAssessmentSelector.countsByCycle(cycleId);
            view.selfTotal = self[0];
            view.selfSubmitted = self[1];
            Map<String, Integer> counts = PerformanceReviewSelector.countByStatus(cycleId);
            for (String status : REVIEW_STATUSES) {
                StatusCount sc = new StatusCount();
                sc.status = status;
                sc.total = counts.containsKey(status) ? counts.get(status) : 0;
                view.reviewTotal += sc.total;
                view.reviewsByStatus.add(sc);
            }
            view.withoutReviewer = PerformanceReviewSelector.countWithoutReviewer(cycleId);
            return view;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static Id createCycle(String name, Date startDate, Date endDate, Date selfDue, Date managerDue, Integer scaleMax) {
        try {
            ReviewCycleService.requireHr();
            Review_Cycle__c cycle = new Review_Cycle__c(
                Name = name,
                Start_Date__c = startDate,
                End_Date__c = endDate,
                Self_Review_Due__c = selfDue,
                Manager_Review_Due__c = managerDue,
                Rating_Scale_Max__c = scaleMax
            );
            insert as user cycle;
            return cycle.Id;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static ReviewCycleService.LaunchResult launch(Id cycleId) {
        try {
            return ReviewCycleService.launch(cycleId);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static String advance(Id cycleId) {
        try {
            return ReviewCycleService.advance(cycleId).Status__c;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static ReviewCycleService.ReleaseResult release(Id cycleId) {
        try {
            return ReviewCycleService.release(cycleId);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static List<CalibrationRow> getCalibration(Id cycleId) {
        try {
            ReviewCycleService.requireHr();
            Review_Cycle__c cycle = ReviewCycleSelector.byId(cycleId);
            if (cycle == null) {
                throw new ReviewErrors.ReviewException('Ciclo de avaliação não encontrado.');
            }
            List<CalibrationRow> rows = new List<CalibrationRow>();
            for (Performance_Review__c r : PerformanceReviewSelector.byCycleWithCalibration(cycleId)) {
                CalibrationRow row = new CalibrationRow();
                row.reviewId = r.Id;
                row.employeeName = r.Employee__r.Name;
                row.positionName = r.Employee__r.Position__r.Name;
                row.status = r.Status__c;
                row.managerRating = r.Manager_Rating__c;
                row.calibratedRating = r.Calibrated_Rating__c;
                row.finalRating = r.Final_Rating__c;
                row.canCalibrate =
                    cycle.Status__c == ReviewCycleService.CALIBRATION &&
                    (r.Status__c == PerformanceReviewService.SENT || r.Status__c == PerformanceReviewService.CALIBRATED);
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static void calibrate(Id reviewId, Decimal rating) {
        try {
            PerformanceReviewService.calibrate(reviewId, rating);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }
}
