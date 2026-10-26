/**
 * Regras de Leave_Request__c em trigger: dados basicos validos, colaborador preenchido a partir do periodo e datas
 * travadas fora do rascunho. A mudanca de status nao e tratada aqui: ela so acontece pelo servico (FLS somente
 * leitura para colaborador e gestor, spec 02).
 *
 * A leitura do periodo roda em modo sistema: em trigger, WITH USER_MODE com bind dispara erro de plataforma
 * (tmpVar1), e a classe with sharing ja restringe os registros ao alcance de quem grava.
 */
// Leitura do periodo em contexto de trigger (ver comentario da classe).
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class LeaveRequestTriggerHandler extends TriggerHandler {
    public static final String DAYS_MESSAGE = 'Informe pelo menos 1 dia de férias.';
    public static final String SOLD_MESSAGE = 'Os dias vendidos não podem ser negativos.';
    public static final String LOCK_MESSAGE = 'As datas só podem ser alteradas enquanto a solicitação é rascunho.';

    private List<Leave_Request__c> newList;
    private Map<Id, Leave_Request__c> oldMap;

    public LeaveRequestTriggerHandler() {
        this.newList = (List<Leave_Request__c>) Trigger.new;
        this.oldMap = (Map<Id, Leave_Request__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        validateBasics(newList);
        fillEmployee(newList);
    }

    protected override void beforeUpdate() {
        validateBasics(newList);
        for (Leave_Request__c r : newList) {
            Leave_Request__c old = oldMap.get(r.Id);
            if (old.Status__c != 'Rascunho' && datesChanged(r, old)) {
                r.addError(LOCK_MESSAGE);
            }
        }
    }

    private static Boolean datesChanged(Leave_Request__c r, Leave_Request__c old) {
        return r.Start_Date__c != old.Start_Date__c || r.Days__c != old.Days__c || r.Sold_Days__c != old.Sold_Days__c;
    }

    private static void validateBasics(List<Leave_Request__c> records) {
        for (Leave_Request__c r : records) {
            if (r.Days__c != null && r.Days__c < 1) {
                r.Days__c.addError(DAYS_MESSAGE);
            }
            if (r.Sold_Days__c != null && r.Sold_Days__c < 0) {
                r.Sold_Days__c.addError(SOLD_MESSAGE);
            }
        }
    }

    /** O colaborador da solicitacao e sempre o do periodo aquisitivo. */
    private static void fillEmployee(List<Leave_Request__c> records) {
        Set<Id> periodIds = new Set<Id>();
        for (Leave_Request__c r : records) {
            periodIds.add(r.Accrual_Period__c);
        }
        periodIds.remove(null);
        if (periodIds.isEmpty()) {
            return;
        }
        Map<Id, Leave_Accrual_Period__c> periods = new Map<Id, Leave_Accrual_Period__c>(
            [SELECT Id, Employee__c FROM Leave_Accrual_Period__c WHERE Id IN :periodIds]
        );
        for (Leave_Request__c r : records) {
            Leave_Accrual_Period__c p = periods.get(r.Accrual_Period__c);
            if (p != null) {
                r.Employee__c = p.Employee__c;
            }
        }
    }
}
