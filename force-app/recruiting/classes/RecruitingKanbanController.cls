/**
 * Controller fino do kanban do funil (recruitingKanban). Toda regra fica em JobApplicationService e
 * RecruitingStageConfig; aqui so ha montagem de DTO e traducao de erro para o LWC.
 *
 * `with sharing` e leitura em USER_MODE: o recrutador ve todas as candidaturas; o gestor contratante, so as das
 * proprias vagas.
 */
public with sharing class RecruitingKanbanController {
    private static final Integer MAX_OPENINGS = 200;
    private static final Integer MAX_CARDS = 1000;
    private static final Decimal MILLIS_PER_DAY = 86400000;

    public class OptionDto {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;

        public OptionDto(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class OpeningOptionDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Integer applicationsCount;
    }

    public class StageDto {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String color;
        @AuraEnabled
        public Boolean isTerminal;
        @AuraEnabled
        public Boolean requiresScore;
        @AuraEnabled
        public Boolean requiresRejectionReason;
        @AuraEnabled
        public List<String> allowedNext;
    }

    public class CardDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String applicationNumber;
        @AuraEnabled
        public Id candidateId;
        @AuraEnabled
        public String candidateName;
        @AuraEnabled
        public String stage;
        @AuraEnabled
        public Decimal score;
        @AuraEnabled
        public Integer daysInStage;
        @AuraEnabled
        public String rejectionReason;
        @AuraEnabled
        public String source;
    }

    public class BoardDto {
        @AuraEnabled
        public Id openingId;
        @AuraEnabled
        public String openingName;
        @AuraEnabled
        public String openingStatus;
        @AuraEnabled
        public List<StageDto> stages;
        @AuraEnabled
        public List<CardDto> cards;
        @AuraEnabled
        public List<OptionDto> rejectionReasons;
    }

    @AuraEnabled(cacheable=true)
    public static List<OpeningOptionDto> getOpenings() {
        try {
            List<OpeningOptionDto> result = new List<OpeningOptionDto>();
            for (Job_Opening__c o : JobOpeningSelector.forBoard(MAX_OPENINGS)) {
                OpeningOptionDto dto = new OpeningOptionDto();
                dto.id = o.Id;
                dto.name = o.Name;
                dto.status = o.Status__c;
                dto.applicationsCount = o.Applications_Count__c == null ? 0 : o.Applications_Count__c.intValue();
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    @AuraEnabled
    public static BoardDto getBoard(Id openingId) {
        try {
            Job_Opening__c opening = JobOpeningSelector.byId(openingId);
            if (opening == null) {
                throw new JobApplicationService.RecruitingException('Vaga não encontrada ou sem acesso.');
            }
            BoardDto board = new BoardDto();
            board.openingId = opening.Id;
            board.openingName = opening.Name;
            board.openingStatus = opening.Status__c;
            board.stages = stages();
            board.rejectionReasons = rejectionReasons();
            board.cards = new List<CardDto>();
            Datetime now = Datetime.now();
            for (Job_Application__c a : JobApplicationSelector.byOpening(openingId, MAX_CARDS)) {
                board.cards.add(card(a, now));
            }
            return board;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /** Move a candidatura de etapa (C1 e C2 validados no servidor) e devolve o cartao atualizado. */
    @AuraEnabled
    public static CardDto moveCard(Id applicationId, String toStage, String rejectionReason, Decimal score) {
        try {
            Job_Application__c updated = JobApplicationService.changeStage(applicationId, toStage, rejectionReason, score);
            if (updated == null) {
                throw new JobApplicationService.RecruitingException('Candidatura não encontrada ou sem acesso.');
            }
            return card(updated, Datetime.now());
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /** Grava a nota sem mudar de etapa e devolve o cartao atualizado. */
    @AuraEnabled
    public static CardDto rateCard(Id applicationId, Decimal score) {
        try {
            JobApplicationService.rate(applicationId, score);
            List<Job_Application__c> rows = JobApplicationSelector.byIds(new Set<Id>{ applicationId });
            if (rows.isEmpty()) {
                throw new JobApplicationService.RecruitingException('Candidatura não encontrada ou sem acesso.');
            }
            return card(rows[0], Datetime.now());
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    // -----------------------------------------------------------------------------------------------------

    private static List<StageDto> stages() {
        List<StageDto> result = new List<StageDto>();
        for (RecruitingStageConfig.StageInfo s : RecruitingStageConfig.ordered()) {
            StageDto dto = new StageDto();
            dto.value = s.value;
            dto.label = RecruitingStageConfig.label(s.value);
            dto.color = s.color;
            dto.isTerminal = s.isTerminal;
            dto.requiresScore = s.requiresScore;
            dto.requiresRejectionReason = s.requiresRejectionReason;
            dto.allowedNext = s.allowedNext;
            result.add(dto);
        }
        return result;
    }

    private static List<OptionDto> rejectionReasons() {
        List<OptionDto> result = new List<OptionDto>();
        for (Schema.PicklistEntry e : Job_Application__c.Rejection_Reason__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                result.add(new OptionDto(e.getValue(), e.getLabel()));
            }
        }
        return result;
    }

    private static CardDto card(Job_Application__c a, Datetime now) {
        CardDto dto = new CardDto();
        dto.id = a.Id;
        dto.applicationNumber = a.Name;
        dto.candidateId = a.Candidate__c;
        dto.candidateName = a.Candidate__r == null ? null : a.Candidate__r.Name;
        dto.stage = a.Stage__c;
        dto.score = a.Score__c;
        dto.rejectionReason = a.Rejection_Reason__c;
        dto.source = a.Source__c;
        if (a.Stage_Entered_Date__c != null) {
            Decimal days = (now.getTime() - a.Stage_Entered_Date__c.getTime()) / MILLIS_PER_DAY;
            dto.daysInStage = Math.max(0, days.intValue());
        } else {
            dto.daysInStage = 0;
        }
        return dto;
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
