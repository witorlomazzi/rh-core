// RH Core, dados de demonstracao da Vetra Distribuidora (empresa ficticia). Fase 2: ferias CLT.
// Projeto demonstrativo, empresa e dados ficticios. Nenhum dado real.
//
// Gera os periodos aquisitivos (LeaveAccrualService), aplica as faltas de 3 colaboradores (8, 16 e 35, que cai em
// "Perdido"), cria 12 pedidos de ferias em estados variados com as etapas de aprovacao e quita com gozo historico
// os periodos cujo prazo concessivo ja venceu (sem isso todo periodo antigo apareceria como prazo estourado).
// Calibrado para a data de referencia 26/10/2026: Priscila Vieira (prazo 03/11/2026) e Rafael Brandao
// (01/12/2026) ficam em "Prazo_Proximo". Idempotente: periodos por chave unica; pedidos por periodo e data de inicio.
// Pre-requisito: fase 1.

Date today = Date.today();
Map<String, Id> empId = new Map<String, Id>();
Map<String, Id> empUser = new Map<String, Id>();
Set<Id> employeeIds = new Set<Id>();
for (Employee__c e : [SELECT Id, Employee_Number__c, User__c FROM Employee__c WHERE Employee_Number__c LIKE 'VTR-%']) {
    empId.put(e.Employee_Number__c, e.Id);
    empUser.put(e.Employee_Number__c, e.User__c);
    employeeIds.add(e.Id);
}
if (employeeIds.isEmpty()) {
    throw new CalloutException('Rode antes a fase 1 (estrutura).');
}

// 1. Periodos aquisitivos de todos os colaboradores CLT ativos.
LeaveAccrualService.Summary s1 = LeaveAccrualService.generateForEmployeeIds(employeeIds, today);

// 2. Faltas injustificadas: chave do periodo => quantidade.
Map<String, Integer> absences = new Map<String, Integer>{
    'VTR-0029|2025-09-13' => 8, 'VTR-0023|2025-02-14' => 16, 'VTR-0024|2025-05-09' => 35
};
List<Leave_Accrual_Period__c> withAbsences = new List<Leave_Accrual_Period__c>();
for (Leave_Accrual_Period__c p : [
    SELECT Id, Unique_Key__c, Unjustified_Absences__c FROM Leave_Accrual_Period__c WHERE Unique_Key__c IN :absences.keySet()
]) {
    Integer wanted = absences.get(p.Unique_Key__c);
    if (p.Unjustified_Absences__c == null || p.Unjustified_Absences__c.intValue() != wanted) {
        p.Unjustified_Absences__c = wanted;
        withAbsences.add(p);
    }
}
update withAbsences;

// 3. Pedidos de demonstracao. Formato: colaborador#inicioDoPeriodo#inicioDasFerias#dias#abono#status#decisoes#observacao
// decisoes: A = aprovada, R = rejeitada (com comentario), C = cancelada; separadas por ";" na ordem das etapas.
List<String> requests = new List<String>{
    'VTR-0015#2024-03-01#2025-12-01#20#10#Concluido#A:2025-10-10;A:2025-10-13#Férias de fim de ano com abono',
    'VTR-0016#2025-06-15#2026-12-14#14#0#Aprovado#A:2026-10-05;A:2026-10-06#',
    'VTR-0017#2025-02-01#2026-12-07#10#0#Pendente##',
    'VTR-0018#2025-08-12#2026-10-19#15#0#Em_Gozo#A:2026-08-20;A:2026-08-21#',
    'VTR-0019#2025-01-10#2026-11-30#20#0#Pendente#A:2026-10-22#',
    'VTR-0020#2025-09-02#2026-11-23#10#0#Rejeitado#R:2026-10-14:Fechamento do trimestre e pico de vendas. Podemos reagendar para janeiro.#',
    'VTR-0009#2025-02-03#2027-01-11#20#0#Aprovado#A:2026-10-02;A:2026-10-05#',
    'VTR-0014#2024-07-19#2026-04-13#14#0#Concluido#A:2026-02-20;A:2026-02-23#',
    'VTR-0014#2024-07-19#2026-06-22#16#0#Concluido#A:2026-04-20;A:2026-04-22#',
    'VTR-0036#2025-01-08#2026-12-21#10#0#Rascunho##Rascunho: falta enviar para aprovação',
    'VTR-0028#2024-11-04#2026-08-10#15#0#Cancelado#C:2026-06-15#Cancelado pelo colaborador (projeto de fechamento)',
    'VTR-0037#2025-06-12#2026-11-23#20#0#Aprovado#A:2026-09-30;A:2026-10-01#'
};
Map<String, Id> periodId = new Map<String, Id>();
Set<String> periodKeys = new Set<String>();
for (String row : requests) {
    List<String> p = row.split('#', -1);
    periodKeys.add(p[0] + '|' + p[1]);
}
for (Leave_Accrual_Period__c p : [SELECT Id, Unique_Key__c FROM Leave_Accrual_Period__c WHERE Unique_Key__c IN :periodKeys]) {
    periodId.put(p.Unique_Key__c, p.Id);
}
Set<String> existing = new Set<String>();
for (Leave_Request__c r : [
    SELECT Accrual_Period__c, Start_Date__c FROM Leave_Request__c WHERE Accrual_Period__c IN :periodId.values()
]) {
    existing.add(r.Accrual_Period__c + '|' + r.Start_Date__c);
}
List<Leave_Request__c> toInsert = new List<Leave_Request__c>();
List<String> rowOfRequest = new List<String>();
for (String row : requests) {
    List<String> p = row.split('#', -1);
    Id period = periodId.get(p[0] + '|' + p[1]);
    Date start = Date.valueOf(p[2]);
    if (period == null || existing.contains(period + '|' + start)) {
        continue;
    }
    String status = p[5];
    // Etapa corrente: a que ainda espera decisao (1 se nada foi decidido, 2 se so o gestor decidiu).
    Integer decided = String.isBlank(p[6]) ? 0 : p[6].split(';').size();
    toInsert.add(new Leave_Request__c(
        Accrual_Period__c = period, Employee__c = empId.get(p[0]), Start_Date__c = start, Days__c = Decimal.valueOf(p[3]),
        Sold_Days__c = Decimal.valueOf(p[4]), Status__c = status, Requested_By__c = empUser.get(p[0]), Notes__c = String.isBlank(p[7]) ? null : p[7],
        Current_Step__c = status == 'Pendente' ? decided + 1 : null
    ));
    rowOfRequest.add(row);
}
insert toInsert;

// Etapas de aprovacao no mesmo formato do motor: so a etapa corrente fica Pendente; as decididas ficam registradas.
// O gestor direto de cada colaborador (Employee__r.Manager__r.User__c) e o aprovador da etapa 1; o RH, da etapa 2.
Map<Id, Employee__c> mgr = new Map<Id, Employee__c>(
    [SELECT Id, Manager__c, Manager__r.User__c, Manager__r.Name FROM Employee__c WHERE Id IN :empId.values()]
);
Id hrUser = empUser.get('VTR-0031');
List<Approval_Step__c> steps = new List<Approval_Step__c>();
for (Integer i = 0; i < toInsert.size(); i++) {
    Leave_Request__c r = toInsert[i];
    List<String> p = rowOfRequest[i].split('#', -1);
    if (r.Status__c == 'Rascunho') {
        continue;
    }
    List<String> decisions = String.isBlank(p[6]) ? new List<String>() : p[6].split(';');
    Employee__c e = mgr.get(r.Employee__c);
    Id managerUser = e == null || e.Manager__r == null ? null : e.Manager__r.User__c;
    Integer total = r.Status__c == 'Pendente' ? decisions.size() + 1 : decisions.size();
    for (Integer k = 0; k < total; k++) {
        Approval_Step__c st = new Approval_Step__c(
            Request_Type__c = 'Leave', Leave_Request__c = r.Id, Step_Order__c = k + 1,
            Approver_Type__c = k == 0 ? 'Direct_Manager' : 'HR_Team', Approver__c = k == 0 ? managerUser : null
        );
        if (k < decisions.size()) {
            List<String> d = decisions[k].split(':', 3);
            st.Status__c = d[0] == 'A' ? 'Aprovado' : (d[0] == 'R' ? 'Rejeitado' : 'Cancelado');
            st.Decision_Date__c = Datetime.newInstance(Date.valueOf(d[1]), Time.newInstance(10, 0, 0, 0));
            st.Decided_By__c = k == 0 ? managerUser : hrUser;
            st.Comments__c = d.size() > 2 ? d[2] : null;
        } else {
            st.Status__c = 'Pendente';
        }
        steps.add(st);
    }
}
insert steps;

// 4. Atualiza status dos periodos depois dos pedidos e quita os periodos vencidos com gozo historico.
LeaveAccrualService.generateForEmployeeIds(employeeIds, today);
List<Leave_Request__c> history = new List<Leave_Request__c>();
for (Leave_Accrual_Period__c p : [
    SELECT Id, Employee__c, End_Date__c, Balance_Days__c, Status__c
    FROM Leave_Accrual_Period__c
    WHERE Employee__r.Employee_Number__c LIKE 'VTR-%' AND Concession_Deadline__c < :today AND Status__c != 'Perdido'
]) {
    if (p.Balance_Days__c != null && p.Balance_Days__c > 0) {
        history.add(new Leave_Request__c(
            Accrual_Period__c = p.Id, Employee__c = p.Employee__c, Start_Date__c = p.End_Date__c.addDays(45),
            Days__c = p.Balance_Days__c, Sold_Days__c = 0, Status__c = 'Concluido', Notes__c = 'Gozo histórico (carga de demonstração)'
        ));
    }
}
insert history;
LeaveAccrualService.Summary s2 = LeaveAccrualService.generateForEmployeeIds(employeeIds, today);

System.debug('Fase 2: periodos criados ' + s1.created + ', pedidos novos ' + toInsert.size() + ', etapas ' + steps.size()
    + ', gozo historico ' + history.size() + ', periodos atualizados ' + s2.updated);
