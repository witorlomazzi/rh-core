/**
 * Regras de Job_Opening__c no trigger: identificador publico (C7), datas de abertura e encerramento, reprovacao
 * das candidaturas ao encerrar (C6) e refazer o compartilhamento quando muda o gestor contratante (C9).
 */
public with sharing class JobOpeningTriggerHandler extends TriggerHandler {
    private List<Job_Opening__c> newList;
    private Map<Id, Job_Opening__c> oldMap;

    public JobOpeningTriggerHandler() {
        this.newList = (List<Job_Opening__c>) Trigger.new;
        this.oldMap = (Map<Id, Job_Opening__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        JobOpeningService.assignSlugs(newList);
        for (Job_Opening__c o : newList) {
            o.Applications_Count__c = 0;
            applyStatusDates(o, null);
        }
    }

    protected override void beforeUpdate() {
        JobOpeningService.assignSlugs(newList);
        for (Job_Opening__c o : newList) {
            applyStatusDates(o, oldMap.get(o.Id));
        }
    }

    protected override void afterUpdate() {
        Set<Id> closed = new Set<Id>();
        Set<Id> managerChanged = new Set<Id>();
        for (Job_Opening__c o : newList) {
            Job_Opening__c old = oldMap.get(o.Id);
            if (JobOpeningService.isClosedStatus(o.Status__c) && !JobOpeningService.isClosedStatus(old.Status__c)) {
                closed.add(o.Id);
            }
            if (o.Hiring_Manager__c != old.Hiring_Manager__c) {
                managerChanged.add(o.Id);
            }
        }
        if (!closed.isEmpty()) {
            JobOpeningService.closeApplications(closed);
        }
        if (!managerChanged.isEmpty()) {
            RecruitingSharingService.recalculateForOpenings(managerChanged);
        }
    }

    /** Abertura grava a data de abertura; encerramento grava a de encerramento; reabrir limpa a de encerramento. */
    private static void applyStatusDates(Job_Opening__c opening, Job_Opening__c old) {
        Boolean statusChanged = old == null || opening.Status__c != old.Status__c;
        if (!statusChanged) {
            return;
        }
        if (opening.Status__c == JobOpeningService.STATUS_OPEN && opening.Opened_Date__c == null) {
            opening.Opened_Date__c = Date.today();
        }
        if (JobOpeningService.isClosedStatus(opening.Status__c)) {
            if (opening.Closed_Date__c == null) {
                opening.Closed_Date__c = Date.today();
            }
        } else if (old != null && JobOpeningService.isClosedStatus(old.Status__c)) {
            opening.Closed_Date__c = null;
        }
    }
}
