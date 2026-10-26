// RH Core, dados de demonstracao da Vetra Distribuidora (empresa ficticia). Fase 3: promocoes e historico de cargo.
// Projeto demonstrativo, empresa e dados ficticios. Nenhum dado real.
//
// Cria 3 promocoes (1 efetivada, 1 aprovada para data futura, 1 pendente na etapa do RH) com suas etapas de
// aprovacao e o historico de cargo de todos os colaboradores: trajetorias detalhadas para 4 pessoas e historico de
// admissao (PositionHistoryService.createAdmission) para os demais. As solicitacoes entram com o trigger de
// Promotion_Request__c desligado (bypass) porque o trigger exige que quem grava seja gestor na cadeia do colaborador
// e recalcula o snapshot; aqui o snapshot e a etapa ja vem definidos e o compartilhamento e refeito a mao.
// Idempotente: promocao por colaborador, cargo proposto e data; historico so para quem ainda nao tem.
// Pre-requisitos: fases 1 e 2.

Map<String, Id> empId = new Map<String, Id>();
Map<String, Id> empUser = new Map<String, Id>();
Map<Id, Employee__c> empById = new Map<Id, Employee__c>();
for (Employee__c e : [
    SELECT Id, Employee_Number__c, User__c, Manager__c, Manager__r.User__c, Manager__r.Manager__c, Manager__r.Manager__r.User__c,
        Status__c, Termination_Date__c
    FROM Employee__c
    WHERE Employee_Number__c LIKE 'VTR-%'
]) {
    empId.put(e.Employee_Number__c, e.Id);
    empUser.put(e.Employee_Number__c, e.User__c);
    empById.put(e.Id, e);
}
Map<String, Id> posId = new Map<String, Id>();
for (Job_Position__c p : [SELECT Id, Code__c FROM Job_Position__c]) {
    posId.put(p.Code__c, p.Id);
}
Map<String, Id> deptId = new Map<String, Id>();
for (Department__c d : [SELECT Id, Code__c FROM Department__c]) {
    deptId.put(d.Code__c, d.Id);
}
if (empId.isEmpty()) {
    throw new CalloutException('Rode antes a fase 1 (estrutura).');
}
Id hrUser = empUser.get('VTR-0031');

// ------------------------------------------------------------------------------------------------- promocoes
// colaborador#cargoAtual#cargoProposto#salarioAtual#salarioProposto#data#status#solicitante#decisoes#justificativa
// decisoes: A:data = aprovada; vazio = ainda nao decidida. Etapa 1 = gestor de segundo nivel, etapa 2 = RH.
List<String> promos = new List<String>{
    'VTR-0022#P04#P05#7400#9200#2025-07-01#Efetivado#VTR-0009#A:2025-06-10;A:2025-06-12#Liderou a reestruturação do roteiro de entregas e reduziu atrasos.',
    'VTR-0017#P03#P04#4700#5900#2026-12-01#Aprovado#VTR-0007#A:2026-10-20;A:2026-10-22#Assumiu contas médias e superou a meta por três trimestres seguidos.',
    'VTR-0029#P04#P05#6400##2026-11-16#Pendente#VTR-0011#A:2026-10-21#Referência técnica em conciliação fiscal e mentora de dois assistentes.'
};
Set<Id> forEmployees = new Set<Id>();
for (String row : promos) {
    forEmployees.add(empId.get(row.split('#', -1)[0]));
}
Set<String> existing = new Set<String>();
for (Promotion_Request__c r : [SELECT Employee__c, Proposed_Position__c, Effective_Date__c FROM Promotion_Request__c WHERE Employee__c IN :forEmployees]) {
    existing.add(r.Employee__c + '|' + r.Proposed_Position__c + '|' + r.Effective_Date__c);
}
List<Promotion_Request__c> newPromos = new List<Promotion_Request__c>();
List<String> newRows = new List<String>();
for (String row : promos) {
    List<String> p = row.split('#', -1);
    Date effective = Date.valueOf(p[5]);
    if (existing.contains(empId.get(p[0]) + '|' + posId.get(p[2]) + '|' + effective)) {
        continue;
    }
    Integer decided = String.isBlank(p[8]) ? 0 : p[8].split(';').size();
    newPromos.add(new Promotion_Request__c(
        Employee__c = empId.get(p[0]), Current_Position__c = posId.get(p[1]), Proposed_Position__c = posId.get(p[2]),
        Current_Salary__c = Decimal.valueOf(p[3]), Proposed_Salary__c = String.isBlank(p[4]) ? null : Decimal.valueOf(p[4]),
        Justification__c = p[9], Effective_Date__c = effective, Status__c = p[6], Requested_By__c = empUser.get(p[7]),
        Current_Step__c = p[6] == 'Pendente' ? decided + 1 : null
    ));
    newRows.add(row);
}
TriggerHandler.bypass('PromotionRequestTriggerHandler');
try {
    insert newPromos;
} finally {
    TriggerHandler.clearBypass('PromotionRequestTriggerHandler');
}
List<Approval_Step__c> steps = new List<Approval_Step__c>();
Map<String, Id> promoByEmployee = new Map<String, Id>();
for (Integer i = 0; i < newPromos.size(); i++) {
    Promotion_Request__c r = newPromos[i];
    List<String> p = newRows[i].split('#', -1);
    promoByEmployee.put(p[0], r.Id);
    List<String> decisions = String.isBlank(p[8]) ? new List<String>() : p[8].split(';');
    Employee__c e = empById.get(r.Employee__c);
    Id secondLevelUser = e.Manager__r == null || e.Manager__r.Manager__r == null ? null : e.Manager__r.Manager__r.User__c;
    Integer total = r.Status__c == 'Pendente' ? decisions.size() + 1 : decisions.size();
    for (Integer k = 0; k < total; k++) {
        Approval_Step__c st = new Approval_Step__c(
            Request_Type__c = 'Promotion', Promotion_Request__c = r.Id, Step_Order__c = k + 1,
            Approver_Type__c = k == 0 ? 'Second_Level_Manager' : 'HR_Team', Approver__c = k == 0 ? secondLevelUser : null
        );
        if (k < decisions.size()) {
            st.Status__c = 'Aprovado';
            st.Decision_Date__c = Datetime.newInstance(Date.valueOf(decisions[k].split(':')[1]), Time.newInstance(10, 0, 0, 0));
            st.Decided_By__c = k == 0 ? secondLevelUser : hrUser;
        } else {
            st.Status__c = 'Pendente';
        }
        steps.add(st);
    }
}
insert steps;
if (!newPromos.isEmpty()) {
    PromotionSharingService.recalculate(new Map<Id, Promotion_Request__c>(newPromos).keySet());
}

// --------------------------------------------------------------------------------------- historico de cargo
// colaborador#cargo#depto#inicio#fim#salario#motivo
List<String> custom = new List<String>{
    'VTR-0022#P03#OPL#2019-12-02#2021-12-31#4300#Admissao', 'VTR-0022#P04#OPL#2022-01-01#2025-06-30#7400#Merito',
    'VTR-0022#P05#OPL#2025-07-01##9200#Promocao',
    'VTR-0015#P04#COM#2021-03-01#2024-03-31#6100#Admissao', 'VTR-0015#P05#COM#2024-04-01##9600#Promocao',
    'VTR-0016#P03#COM#2020-06-15#2022-06-30#4300#Admissao', 'VTR-0016#P04#COM#2022-07-01##6900#Merito',
    'VTR-0007#P05#COM#2020-01-13#2023-04-30#9300#Admissao', 'VTR-0007#P08#COM#2023-05-01##16200#Promocao'
};
Set<Id> withHistory = new Set<Id>();
for (Position_History__c h : [SELECT Employee__c FROM Position_History__c WHERE Employee__r.Employee_Number__c LIKE 'VTR-%']) {
    withHistory.add(h.Employee__c);
}
List<Position_History__c> rows = new List<Position_History__c>();
for (String row : custom) {
    List<String> p = row.split('#', -1);
    Id e = empId.get(p[0]);
    if (withHistory.contains(e)) {
        continue;
    }
    rows.add(new Position_History__c(
        Employee__c = e, Position__c = posId.get(p[1]), Department__c = deptId.get(p[2]), Start_Date__c = Date.valueOf(p[3]),
        End_Date__c = String.isBlank(p[4]) ? null : Date.valueOf(p[4]), Salary__c = Decimal.valueOf(p[5]), Change_Reason__c = p[6],
        Promotion_Request__c = p[0] == 'VTR-0022' && p[6] == 'Promocao' ? promoByEmployee.get('VTR-0022') : null
    ));
}
insert rows;
// Quem ainda nao tem historico recebe o de admissao (cargo, departamento e salario atuais, inicio na admissao).
Integer admissions = PositionHistoryService.createAdmission(new Set<Id>(empId.values()));

// O desligado tem o historico encerrado na data de desligamento.
List<Position_History__c> toClose = new List<Position_History__c>();
for (Position_History__c h : [
    SELECT Id, Employee__r.Termination_Date__c FROM Position_History__c
    WHERE Employee__r.Status__c = 'Desligado' AND Employee__r.Employee_Number__c LIKE 'VTR-%' AND End_Date__c = NULL
]) {
    h.End_Date__c = h.Employee__r.Termination_Date__c;
    toClose.add(h);
}
update toClose;

System.debug('Fase 3: promocoes novas ' + newPromos.size() + ', etapas ' + steps.size() + ', historico detalhado ' + rows.size()
    + ', admissoes ' + admissions + ', encerrados ' + toClose.size());
