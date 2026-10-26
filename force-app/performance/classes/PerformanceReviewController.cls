/**
 * Controller fino das telas do colaborador (performanceMyCycle) e do gestor (performanceTeamReviews e
 * performanceReviewForm). Toda leitura passa pelos selectors em USER_MODE: o compartilhamento decide quem ve o que
 * e a nota calibrada nunca chega ao colaborador nem ao gestor (FLS); eles recebem apenas a nota final, depois da
 * liberacao.
 */
public with sharing class PerformanceReviewController {
    // ----------------------------------------------------------------------------------------------------- DTOs

    public class CycleDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date selfDue;
        @AuraEnabled
        public Date managerDue;
        @AuraEnabled
        public Integer scaleMax;

        public CycleDto(Review_Cycle__c c) {
            this.id = c.Id;
            this.name = c.Name;
            this.status = c.Status__c;
            this.startDate = c.Start_Date__c;
            this.selfDue = c.Self_Review_Due__c;
            this.managerDue = c.Manager_Review_Due__c;
            this.scaleMax = c.Rating_Scale_Max__c == null ? null : c.Rating_Scale_Max__c.intValue();
        }
    }

    public class GoalDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String target;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public Decimal weight;
        @AuraEnabled
        public Decimal selfScore;
        @AuraEnabled
        public String status;

        public GoalDto(Goal__c g) {
            this.id = g.Id;
            this.name = g.Name;
            this.target = g.Target__c;
            this.description = g.Description__c;
            this.weight = g.Weight__c;
            this.selfScore = g.Self_Score__c;
            this.status = g.Status__c;
        }
    }

    public class SelfDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public Decimal rating;
        @AuraEnabled
        public String strengths;
        @AuraEnabled
        public String improvements;
        @AuraEnabled
        public Boolean submitted;
        @AuraEnabled
        public Datetime submittedDate;

        public SelfDto(Self_Assessment__c s) {
            this.id = s.Id;
            this.rating = s.Self_Rating__c;
            this.strengths = s.Strengths__c;
            this.improvements = s.Improvements__c;
            this.submitted = s.Submitted__c;
            this.submittedDate = s.Submitted_Date__c;
        }
    }

    public class ReleasedDto {
        @AuraEnabled
        public Decimal managerRating;
        @AuraEnabled
        public String managerComments;
        @AuraEnabled
        public Decimal finalRating;
        @AuraEnabled
        public Datetime releasedDate;
    }

    public class CycleOption {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
    }

    public class MyCycleView {
        @AuraEnabled
        public Boolean hasEmployee = false;
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public CycleDto cycle;
        @AuraEnabled
        public List<CycleOption> cycles = new List<CycleOption>();
        @AuraEnabled
        public SelfDto selfAssessment;
        @AuraEnabled
        public List<GoalDto> goals = new List<GoalDto>();
        @AuraEnabled
        public Decimal weightSum = 0;
        @AuraEnabled
        public Boolean canEditGoals = false;
        @AuraEnabled
        public Boolean canEditSelf = false;
        @AuraEnabled
        public ReleasedDto released;
    }

    public class TeamRow {
        @AuraEnabled
        public Id reviewId;
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public Boolean hasSelfAssessment = false;
        @AuraEnabled
        public Boolean selfSubmitted = false;
        @AuraEnabled
        public Decimal selfRating;
        @AuraEnabled
        public String reviewStatus;
        @AuraEnabled
        public Decimal managerRating;
        @AuraEnabled
        public Decimal finalRating;
        @AuraEnabled
        public Boolean isReviewer = false;
        @AuraEnabled
        public Boolean canEdit = false;
    }

    public class TeamView {
        @AuraEnabled
        public CycleDto cycle;
        @AuraEnabled
        public List<TeamRow> rows = new List<TeamRow>();
    }

    public class ReviewFormView {
        @AuraEnabled
        public Id reviewId;
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String employeeName;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public CycleDto cycle;
        @AuraEnabled
        public String reviewStatus;
        @AuraEnabled
        public Decimal managerRating;
        @AuraEnabled
        public String managerComments;
        @AuraEnabled
        public Decimal calibratedRating;
        @AuraEnabled
        public Decimal finalRating;
        @AuraEnabled
        public Datetime releasedDate;
        @AuraEnabled
        public Boolean canEdit = false;
        @AuraEnabled
        public SelfDto selfAssessment;
        @AuraEnabled
        public List<GoalDto> goals = new List<GoalDto>();
        @AuraEnabled
        public Decimal weightSum = 0;
    }

    // ------------------------------------------------------------------------------------------------ colaborador

    /** Metas, autoavaliacao e resultado liberado do colaborador atual. Sem cycleId, usa o ciclo mais recente. */
    @AuraEnabled
    public static MyCycleView getMyCycle(Id cycleId) {
        try {
            MyCycleView view = new MyCycleView();
            Employee__c me = EmployeeSelector.currentUserEmployee();
            if (me == null) {
                return view;
            }
            view.hasEmployee = true;
            view.employeeId = me.Id;
            view.employeeName = me.Name;
            List<Self_Assessment__c> mine = SelfAssessmentSelector.byEmployee(me.Id);
            Self_Assessment__c chosen = null;
            for (Self_Assessment__c sa : mine) {
                CycleOption option = new CycleOption();
                option.id = sa.Review_Cycle__c;
                option.name = sa.Review_Cycle__r.Name;
                view.cycles.add(option);
                if (chosen == null && (cycleId == null || cycleId == sa.Review_Cycle__c)) {
                    chosen = sa;
                }
            }
            if (chosen == null) {
                return view;
            }
            view.cycle = new CycleDto(chosen.Review_Cycle__r);
            view.cycle.id = chosen.Review_Cycle__c;
            view.selfAssessment = new SelfDto(chosen);
            List<Goal__c> goals = GoalSelector.byEmployeeAndCycle(me.Id, chosen.Review_Cycle__c);
            for (Goal__c g : goals) {
                view.goals.add(new GoalDto(g));
            }
            view.weightSum = GoalService.activeWeightSum(goals);
            Boolean notSubmitted = chosen.Submitted__c != true;
            view.canEditGoals = notSubmitted && GoalService.isEditableCycleStatus(chosen.Review_Cycle__r.Status__c);
            view.canEditSelf = notSubmitted && chosen.Review_Cycle__r.Status__c == ReviewCycleService.SELF_REVIEW;

            Performance_Review__c released = PerformanceReviewSelector.releasedFor(me.Id, chosen.Review_Cycle__c);
            if (released != null) {
                ReleasedDto r = new ReleasedDto();
                r.managerRating = released.Manager_Rating__c;
                r.managerComments = released.Manager_Comments__c;
                r.finalRating = released.Final_Rating__c;
                r.releasedDate = released.Released_Date__c;
                view.released = r;
            }
            return view;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    // ----------------------------------------------------------------------------------------------------- gestor

    @AuraEnabled
    public static List<CycleDto> getCycles() {
        try {
            List<CycleDto> result = new List<CycleDto>();
            for (Review_Cycle__c c : ReviewCycleSelector.recent(20)) {
                result.add(new CycleDto(c));
            }
            return result;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    /** Avaliacoes do ciclo que o usuario enxerga (equipe direta e indireta), sem a propria. */
    @AuraEnabled
    public static TeamView getTeam(Id cycleId) {
        try {
            TeamView view = new TeamView();
            Review_Cycle__c cycle = ReviewCycleSelector.byId(cycleId);
            if (cycle == null) {
                throw new ReviewErrors.ReviewException('Ciclo de avaliação não encontrado.');
            }
            view.cycle = new CycleDto(cycle);
            Employee__c me = EmployeeSelector.currentUserEmployee();
            List<Performance_Review__c> reviews = PerformanceReviewSelector.byCycle(cycleId);
            Set<Id> employeeIds = new Set<Id>();
            for (Performance_Review__c r : reviews) {
                employeeIds.add(r.Employee__c);
            }
            Map<Id, Self_Assessment__c> selfByEmployee = new Map<Id, Self_Assessment__c>();
            for (Self_Assessment__c sa : SelfAssessmentSelector.byCycleAndEmployees(cycleId, employeeIds)) {
                selfByEmployee.put(sa.Employee__c, sa);
            }
            Id userId = UserInfo.getUserId();
            for (Performance_Review__c r : reviews) {
                if (me != null && r.Employee__c == me.Id) {
                    continue;
                }
                TeamRow row = new TeamRow();
                row.reviewId = r.Id;
                row.employeeId = r.Employee__c;
                row.employeeName = r.Employee__r.Name;
                row.positionName = r.Employee__r.Position__r.Name;
                Self_Assessment__c sa = selfByEmployee.get(r.Employee__c);
                if (sa != null) {
                    row.hasSelfAssessment = true;
                    row.selfSubmitted = sa.Submitted__c == true;
                    row.selfRating = sa.Self_Rating__c;
                }
                row.reviewStatus = r.Status__c;
                row.managerRating = r.Manager_Rating__c;
                row.finalRating = r.Final_Rating__c;
                row.isReviewer = r.Reviewer__c == userId;
                row.canEdit =
                    row.isReviewer &&
                    cycle.Status__c == ReviewCycleService.MANAGER_REVIEW &&
                    (r.Status__c == PerformanceReviewService.PENDING || r.Status__c == PerformanceReviewService.IN_PROGRESS);
                view.rows.add(row);
            }
            return view;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    @AuraEnabled
    public static ReviewFormView getReviewForm(Id reviewId) {
        try {
            Performance_Review__c r = PerformanceReviewSelector.byId(reviewId);
            if (r == null) {
                throw new ReviewErrors.ReviewException('Avaliação não encontrada ou sem acesso.');
            }
            ReviewFormView view = new ReviewFormView();
            view.reviewId = r.Id;
            view.employeeId = r.Employee__c;
            view.employeeName = r.Employee__r.Name;
            view.positionName = r.Employee__r.Position__r.Name;
            view.cycle = new CycleDto(r.Review_Cycle__r);
            view.cycle.id = r.Review_Cycle__c;
            view.reviewStatus = r.Status__c;
            view.managerRating = r.Manager_Rating__c;
            view.managerComments = r.Manager_Comments__c;
            view.finalRating = r.Final_Rating__c;
            view.releasedDate = r.Released_Date__c;
            view.canEdit =
                r.Reviewer__c == UserInfo.getUserId() &&
                r.Review_Cycle__r.Status__c == ReviewCycleService.MANAGER_REVIEW &&
                (r.Status__c == PerformanceReviewService.PENDING || r.Status__c == PerformanceReviewService.IN_PROGRESS);
            if (ReviewCycleService.isHr()) {
                view.calibratedRating = PerformanceReviewSelector.calibratedByIds(new Set<Id>{ r.Id }).get(r.Id);
            }
            Self_Assessment__c sa = SelfAssessmentSelector.byEmployeeAndCycle(r.Employee__c, r.Review_Cycle__c);
            if (sa != null) {
                view.selfAssessment = new SelfDto(sa);
            }
            List<Goal__c> goals = GoalSelector.byEmployeeAndCycle(r.Employee__c, r.Review_Cycle__c);
            for (Goal__c g : goals) {
                view.goals.add(new GoalDto(g));
            }
            view.weightSum = GoalService.activeWeightSum(goals);
            return view;
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }

    /** Grava a avaliacao do gestor. Com submitReview = true envia (nao editavel depois). */
    @AuraEnabled
    public static ReviewFormView saveReview(Id reviewId, Decimal rating, String comments, Boolean submitReview) {
        try {
            PerformanceReviewService.saveManagerReview(reviewId, rating, comments, submitReview);
            return getReviewForm(reviewId);
        } catch (Exception e) {
            throw ReviewErrors.toAura(e);
        }
    }
}
