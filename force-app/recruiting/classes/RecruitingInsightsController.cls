/**
 * Controller fino das visoes de apoio: historico de etapas da candidatura (recruitingApplicationPanel) e resumo
 * do funil da vaga (recruitingOpeningSummary). `with sharing` e leitura em USER_MODE.
 */
public with sharing class RecruitingInsightsController {
    public class HistoryItemDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String fromStage;
        @AuraEnabled
        public String fromLabel;
        @AuraEnabled
        public String toStage;
        @AuraEnabled
        public String toLabel;
        @AuraEnabled
        public Datetime changedAt;
        @AuraEnabled
        public String changedBy;
        @AuraEnabled
        public Decimal daysInPreviousStage;
        @AuraEnabled
        public String note;
    }

    public class StageSummaryDto {
        @AuraEnabled
        public String stage;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String color;
        @AuraEnabled
        public Boolean isTerminal;
        @AuraEnabled
        public Integer count;
        /** Media de dias que as candidaturas ficaram na etapa antes de sair dela; null sem dados. */
        @AuraEnabled
        public Decimal averageDays;
    }

    public class OpeningSummaryDto {
        @AuraEnabled
        public Id openingId;
        @AuraEnabled
        public String openingName;
        @AuraEnabled
        public String openingStatus;
        @AuraEnabled
        public Integer total;
        @AuraEnabled
        public Integer inProgress;
        @AuraEnabled
        public List<StageSummaryDto> stages;
    }

    @AuraEnabled
    public static List<HistoryItemDto> getHistory(Id applicationId) {
        try {
            List<HistoryItemDto> result = new List<HistoryItemDto>();
            for (Application_Stage_History__c h : JobApplicationSelector.historyOf(applicationId)) {
                HistoryItemDto dto = new HistoryItemDto();
                dto.id = h.Id;
                dto.fromStage = h.From_Stage__c;
                dto.fromLabel = RecruitingStageConfig.label(h.From_Stage__c);
                dto.toStage = h.To_Stage__c;
                dto.toLabel = RecruitingStageConfig.label(h.To_Stage__c);
                dto.changedAt = h.Changed_At__c;
                dto.changedBy = h.Changed_By__r == null ? null : h.Changed_By__r.Name;
                dto.daysInPreviousStage = h.Days_In_Previous_Stage__c;
                dto.note = h.Note__c;
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static OpeningSummaryDto getOpeningSummary(Id openingId) {
        try {
            Job_Opening__c opening = JobOpeningSelector.byId(openingId);
            if (opening == null) {
                throw new JobApplicationService.RecruitingException('Vaga não encontrada ou sem acesso.');
            }
            Map<String, Integer> counts = new Map<String, Integer>();
            for (AggregateResult ar : JobApplicationSelector.countByStage(openingId)) {
                counts.put((String) ar.get('stage'), (Integer) ar.get('total'));
            }
            Map<String, Decimal> averages = new Map<String, Decimal>();
            for (AggregateResult ar : JobApplicationSelector.averageDaysByStage(openingId)) {
                Object avg = ar.get('avgDays');
                if (avg != null) {
                    averages.put((String) ar.get('stage'), ((Decimal) avg).setScale(1, RoundingMode.HALF_UP));
                }
            }

            OpeningSummaryDto summary = new OpeningSummaryDto();
            summary.openingId = opening.Id;
            summary.openingName = opening.Name;
            summary.openingStatus = opening.Status__c;
            summary.total = 0;
            summary.inProgress = 0;
            summary.stages = new List<StageSummaryDto>();
            for (RecruitingStageConfig.StageInfo s : RecruitingStageConfig.ordered()) {
                StageSummaryDto dto = new StageSummaryDto();
                dto.stage = s.value;
                dto.label = RecruitingStageConfig.label(s.value);
                dto.color = s.color;
                dto.isTerminal = s.isTerminal;
                dto.count = counts.containsKey(s.value) ? counts.get(s.value) : 0;
                dto.averageDays = averages.get(s.value);
                summary.total += dto.count;
                if (!s.isTerminal) {
                    summary.inProgress += dto.count;
                }
                summary.stages.add(dto);
            }
            return summary;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    private static AuraHandledException toAura(Exception e) {
        String message = e instanceof JobApplicationService.RecruitingException
            ? e.getMessage()
            : 'Não foi possível concluir a operação. ' + e.getMessage();
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
