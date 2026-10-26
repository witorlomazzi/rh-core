/**
 * Regras de Candidate__c no trigger: e-mail normalizado (C4), dono na fila de recrutamento, ultima atividade e
 * data do consentimento. O candidato anonimizado mantem o e-mail normalizado igual ao e-mail anonimo.
 */
public with sharing class CandidateTriggerHandler extends TriggerHandler {
    private List<Candidate__c> newList;
    private Map<Id, Candidate__c> oldMap;

    public CandidateTriggerHandler() {
        this.newList = (List<Candidate__c>) Trigger.new;
        this.oldMap = (Map<Id, Candidate__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        Id queueId = RecruitingQueue.id();
        String defaultVersion = HrSettings.get().Consent_Text_Version__c;
        for (Candidate__c c : newList) {
            normalize(c);
            if (c.Last_Activity_Date__c == null) {
                c.Last_Activity_Date__c = Date.today();
            }
            if (queueId != null) {
                c.OwnerId = queueId;
            }
            if (c.Consent_Given__c == true) {
                if (c.Consent_Date__c == null) {
                    c.Consent_Date__c = Datetime.now();
                }
                if (String.isBlank(c.Consent_Text_Version__c)) {
                    c.Consent_Text_Version__c = defaultVersion;
                }
            }
        }
    }

    protected override void beforeUpdate() {
        for (Candidate__c c : newList) {
            Candidate__c old = oldMap.get(c.Id);
            Boolean beingAnonymized = c.Anonymized__c == true && old.Anonymized__c != true;
            if (!beingAnonymized && c.Email__c != old.Email__c) {
                normalize(c);
            }
        }
    }

    private static void normalize(Candidate__c c) {
        if (c.Anonymized__c != true) {
            c.Email_Normalized__c = CandidateService.normalizeEmail(c.Email__c);
        }
    }
}
