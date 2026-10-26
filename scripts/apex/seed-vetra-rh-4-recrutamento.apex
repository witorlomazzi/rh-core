// RH Core, dados de demonstracao da Vetra Distribuidora (empresa ficticia). Fase 4: recrutamento.
// Projeto demonstrativo, empresa e dados ficticios. Nenhum dado real.
//
// Cria 4 vagas (2 publicadas no portal), 25 candidatos e 30 candidaturas espalhadas pelo funil, com o historico de
// etapas e os dias em cada etapa (alimenta o relatorio de tempo medio por etapa), 1 contratado em pre-admissao
// (colaborador PRE-000001) e, se o modulo de onboarding estiver instalado, o plano de onboarding dele.
// As candidaturas entram com o trigger de Job_Application__c desligado (bypass): o trigger so aceita a primeira
// etapa e carimba a data de agora, e aqui o funil ja nasce em etapas avancadas com datas passadas. Por isso o
// que o trigger faria depois (dono na fila, chave unica, contagem da vaga, compartilhamento) e feito a mao.
// Dois candidatos terminam parados ha mais de 180 dias para a demonstracao da retencao LGPD.
// Idempotente: vagas por nome, candidatos por e-mail normalizado, candidaturas por chave unica.
// Pre-requisitos: fases 1 a 3.

class Seed4 {
    String slug(String s) {
        String r = s.toLowerCase();
        List<String> from1 = new List<String>{ 'á', 'à', 'â', 'ã', 'é', 'ê', 'í', 'ó', 'ô', 'õ', 'ú', 'ü', 'ç', ' ' };
        List<String> to1 = new List<String>{ 'a', 'a', 'a', 'a', 'e', 'e', 'i', 'o', 'o', 'o', 'u', 'u', 'c', '.' };
        for (Integer i = 0; i < from1.size(); i++) {
            r = r.replace(from1[i], to1[i]);
        }
        return r;
    }
    String pad(Integer n, Integer width) {
        return String.valueOf(n).leftPad(width, '0');
    }
    Datetime at(Date d) {
        return Datetime.newInstance(d, Time.newInstance(10, 0, 0, 0));
    }
}
Seed4 h = new Seed4();

// Habilita o plano de onboarding. Por padrao so quando as classes do modulo existem na org; troque por true para
// forcar (ex.: validar o bloco antes da integracao do modulo).
Boolean createOnboardingPlan = Type.forName('OnboardingHiredHandler') != null;

Map<String, Id> empId = new Map<String, Id>();
Map<String, Id> empUser = new Map<String, Id>();
for (Employee__c e : [SELECT Id, Employee_Number__c, User__c FROM Employee__c WHERE Employee_Number__c LIKE 'VTR-%' OR Employee_Number__c = 'PRE-000001']) {
    empId.put(e.Employee_Number__c, e.Id);
    empUser.put(e.Employee_Number__c, e.User__c);
}
if (!empId.containsKey('VTR-0001')) {
    throw new CalloutException('Rode antes a fase 1 (estrutura).');
}
Map<String, Id> posId = new Map<String, Id>();
for (Job_Position__c p : [SELECT Id, Code__c FROM Job_Position__c]) {
    posId.put(p.Code__c, p.Id);
}
Map<String, Id> deptId = new Map<String, Id>();
for (Department__c d : [SELECT Id, Code__c FROM Department__c]) {
    deptId.put(d.Code__c, d.Id);
}
Id recruiterUser = empUser.get('VTR-0032') != null ? empUser.get('VTR-0032') : UserInfo.getUserId();
Id hrUser = empUser.get('VTR-0031') != null ? empUser.get('VTR-0031') : UserInfo.getUserId();

// ------------------------------------------------------------------------------------------------- vagas
// chave#titulo#cargo#depto#gestor#situacao#portal#modelo#local#vagas#abertura#descricao#requisitos
List<String> jobData = new List<String>{
    'JOB-1#Analista de Vendas Pleno#P04#COM#VTR-0007#Aberta#true#Hibrido#São Paulo, SP#2#2026-09-14#Atender e expandir a carteira de clientes da região Sudeste, conduzindo propostas e negociações.#Experiência com vendas B2B; domínio de CRM; boa comunicação escrita.',
    'JOB-2#Analista de Sistemas Pleno (Salesforce)#P13#TEC#VTR-0013#Aberta#true#Remoto#Brasil (remoto)#1#2026-03-23#Evoluir e sustentar aplicações na plataforma Salesforce que apoiam as áreas comerciais e de pessoas.#Apex, Flow e LWC; testes automatizados; leitura crítica de requisitos.',
    'JOB-3#Analista de Logística Júnior#P03#OPL#VTR-0009#Aberta#false#Presencial#Guarulhos, SP#1#2026-02-16#Apoiar o planejamento de rotas e o acompanhamento diário das entregas do centro de distribuição.#Ensino superior em andamento ou concluído; domínio de planilhas; organização.',
    'JOB-4#Analista Fiscal Sênior#P05#FIN#VTR-0011#Pausada#false#Hibrido#São Paulo, SP#1#2026-08-03#Responder pela apuração de tributos e pela conformidade fiscal das operações da distribuidora.#Experiência com apuração de impostos indiretos; fechamento mensal.'
};
Set<String> jobNames = new Set<String>();
for (String row : jobData) {
    jobNames.add(row.split('#')[1]);
}
Map<String, Job_Opening__c> jobByName = new Map<String, Job_Opening__c>();
for (Job_Opening__c o : [SELECT Id, Name FROM Job_Opening__c WHERE Name IN :jobNames]) {
    jobByName.put(o.Name, o);
}
List<Job_Opening__c> newJobs = new List<Job_Opening__c>();
for (String row : jobData) {
    List<String> p = row.split('#');
    if (jobByName.containsKey(p[1])) {
        continue;
    }
    newJobs.add(new Job_Opening__c(
        Name = p[1], Position__c = posId.get(p[2]), Department__c = deptId.get(p[3]), Hiring_Manager__c = empId.get(p[4]),
        Recruiter__c = recruiterUser, Status__c = p[5], Publish_On_Portal__c = p[6] == 'true', Work_Model__c = p[7], Location__c = p[8],
        Employment_Type__c = 'CLT', Openings_Count__c = Decimal.valueOf(p[9]), Opened_Date__c = Date.valueOf(p[10]),
        Description__c = p[11], Requirements__c = p[12]
    ));
}
insert newJobs;
for (Job_Opening__c o : newJobs) {
    jobByName.put(o.Name, o);
}
Map<String, Id> jobId = new Map<String, Id>();
for (String row : jobData) {
    List<String> p = row.split('#');
    jobId.put(p[0], jobByName.get(p[1]).Id);
}

// -------------------------------------------------------------------------------------------- candidatos
List<String> names = new List<String>{
    'Ricardo Sampaio', 'Letícia Coutinho', 'Gabriel Nakamura', 'Mariana Peixoto', 'Bruno Santana', 'Camille Oliveira',
    'Daniel Albuquerque', 'Eliane Magalhães', 'Fábio Ventura', 'Giovana Pinheiro', 'Heitor Barreto', 'Ingrid Salgado',
    'João Pedro Macedo', 'Karina Ueda', 'Leandro Cordeiro', 'Mônica Rangel', 'Nelson Furtado', 'Olívia Marques',
    'Paulo Henrique Assis', 'Quésia Lacerda', 'Rodolfo Sena', 'Sofia Bittencourt', 'Tales Moreira', 'Úrsula Calado',
    'Valter Esteves'
};
List<String> cities = new List<String>{
    'São Paulo', 'Campinas', 'Santo André', 'Guarulhos', 'Osasco', 'Curitiba', 'Belo Horizonte', 'Rio de Janeiro'
};
List<String> sources = new List<String>{ 'Portal', 'LinkedIn', 'Indicacao', 'Portal', 'Portal', 'Outro' };

// id#candidato#vaga#etapa#entrouNaEtapa#nota#motivo#etapaAnterior#ultimaAtividadeDoCandidato
List<String> appData = new List<String>{
    'A-001#C-03#JOB-1#Contratado#2026-10-19#5###', 'A-002#C-01#JOB-1#Proposta#2026-10-22#4###',
    'A-003#C-02#JOB-1#Entrevista_Tecnica#2026-10-20####', 'A-004#C-04#JOB-1#Entrevista_Tecnica#2026-10-23####',
    'A-005#C-05#JOB-1#Entrevista_RH#2026-10-21####', 'A-006#C-06#JOB-1#Triagem#2026-10-15####',
    'A-007#C-07#JOB-1#Triagem#2026-10-19####', 'A-008#C-08#JOB-1#Nova#2026-10-25####', 'A-009#C-09#JOB-1#Nova#2026-10-26####',
    'A-010#C-10#JOB-1#Reprovado#2026-10-12##Perfil#Triagem#', 'A-011#C-11#JOB-1#Desistiu#2026-10-14###Triagem#',
    'A-012#C-12#JOB-1#Nova#2026-10-24####',
    'A-013#C-13#JOB-2#Proposta#2026-10-21#5###', 'A-014#C-14#JOB-2#Entrevista_Tecnica#2026-10-22####',
    'A-015#C-15#JOB-2#Entrevista_RH#2026-10-23####', 'A-016#C-16#JOB-2#Entrevista_RH#2026-10-18####',
    'A-017#C-17#JOB-2#Triagem#2026-10-22####', 'A-018#C-18#JOB-2#Triagem#2026-10-20####', 'A-019#C-19#JOB-2#Nova#2026-10-26####',
    'A-020#C-20#JOB-2#Reprovado#2026-04-02##Salario#Entrevista_RH#2026-04-02', 'A-021#C-02#JOB-2#Nova#2026-10-25####',
    'A-022#C-21#JOB-3#Entrevista_RH#2026-10-19####', 'A-023#C-22#JOB-3#Triagem#2026-10-17####',
    'A-024#C-23#JOB-3#Nova#2026-10-23####', 'A-025#C-24#JOB-3#Nova#2026-10-22####',
    'A-026#C-25#JOB-3#Reprovado#2026-03-10##Localizacao#Triagem#2026-03-10', 'A-027#C-08#JOB-3#Nova#2026-10-25####',
    'A-028#C-10#JOB-4#Triagem#2026-10-16####', 'A-029#C-04#JOB-4#Nova#2026-10-24####', 'A-030#C-06#JOB-4#Desistiu#2026-10-09###Triagem#'
};
// Ultima atividade do candidato: a informada ou a data mais recente de entrada em etapa das candidaturas dele.
Map<String, Date> lastActivity = new Map<String, Date>();
Set<String> explicitActivity = new Set<String>();
for (String row : appData) {
    List<String> p = row.split('#', -1);
    if (String.isNotBlank(p[8])) {
        lastActivity.put(p[1], Date.valueOf(p[8]));
        explicitActivity.add(p[1]);
    } else if (!explicitActivity.contains(p[1]) && (!lastActivity.containsKey(p[1]) || lastActivity.get(p[1]) < Date.valueOf(p[4]))) {
        lastActivity.put(p[1], Date.valueOf(p[4]));
    }
}
List<Candidate__c> candidates = new List<Candidate__c>();
Map<String, String> emailByKey = new Map<String, String>();
for (Integer i = 0; i < names.size(); i++) {
    String key = 'C-' + h.pad(i + 1, 2);
    List<String> parts = names[i].split(' ');
    String email = h.slug(parts[0] + ' ' + parts[parts.size() - 1]) + '@mail.example';
    emailByKey.put(key, email);
    candidates.add(new Candidate__c(
        Name = names[i], Email__c = email, Email_Normalized__c = email,
        Phone__c = '(11) 9' + h.pad(4000 + i * 137, 4) + '-' + h.pad(1000 + i * 71, 4), City__c = cities[Math.mod(i, cities.size())],
        Source__c = sources[Math.mod(i, sources.size())], Consent_Given__c = true, Consent_Date__c = h.at(Date.valueOf('2026-10-01')),
        Consent_Text_Version__c = '2026-10', Last_Activity_Date__c = lastActivity.containsKey(key) ? lastActivity.get(key) : Date.valueOf('2026-10-01')
    ));
}
// Candidato ja existente nao e reescrito (preserva a anonimizacao feita pela rotina de retencao).
Set<String> existingEmails = new Set<String>();
for (Candidate__c c : [SELECT Email_Normalized__c FROM Candidate__c WHERE Email_Normalized__c IN :emailByKey.values()]) {
    existingEmails.add(c.Email_Normalized__c);
}
List<Candidate__c> newCandidates = new List<Candidate__c>();
for (Candidate__c c : candidates) {
    if (!existingEmails.contains(c.Email_Normalized__c)) {
        newCandidates.add(c);
    }
}
insert newCandidates;
Map<String, Candidate__c> candByKey = new Map<String, Candidate__c>();
Map<String, Candidate__c> candByEmail = new Map<String, Candidate__c>();
for (Candidate__c c : [SELECT Id, Email_Normalized__c, Source__c FROM Candidate__c WHERE Email_Normalized__c IN :emailByKey.values()]) {
    candByEmail.put(c.Email_Normalized__c, c);
}
for (String key : emailByKey.keySet()) {
    candByKey.put(key, candByEmail.get(emailByKey.get(key)));
}

// ----------------------------------------------------------------- contratado em pre-admissao (colaborador)
Id preEmployeeId = empId.get('PRE-000001');
Date hireDate = Date.today().addDays(15);
if (preEmployeeId == null) {
    Employee__c pre = new Employee__c(
        Employee_Number__c = 'PRE-000001', Name = 'Gabriel Nakamura', Email__c = 'gabriel.nakamura@vetra.example',
        Position__c = posId.get('P04'), Department__c = deptId.get('COM'), Manager__c = empId.get('VTR-0007'),
        Hire_Date__c = hireDate, Status__c = 'Pre_Admissao', Employment_Type__c = 'CLT', Work_Location__c = 'SP-SAO_PAULO'
    );
    insert pre;
    preEmployeeId = pre.Id;
} else {
    hireDate = [SELECT Hire_Date__c FROM Employee__c WHERE Id = :preEmployeeId].Hire_Date__c;
}

// -------------------------------------------------------------------------------------------- candidaturas
Id queueId = RecruitingQueue.id();
Set<String> existingKeys = new Set<String>();
for (Job_Application__c a : [SELECT Unique_Key__c FROM Job_Application__c WHERE Job_Opening__c IN :jobId.values()]) {
    existingKeys.add(a.Unique_Key__c);
}
// Duracao (dias) em cada etapa antes de avancar: base por etapa mais uma variacao de 0 a 2 pelo numero da candidatura.
Map<String, Integer> baseDays = new Map<String, Integer>{
    'Nova' => 2, 'Triagem' => 4, 'Entrevista_RH' => 5, 'Entrevista_Tecnica' => 6, 'Proposta' => 3
};
List<String> path = new List<String>{ 'Nova', 'Triagem', 'Entrevista_RH', 'Entrevista_Tecnica', 'Proposta', 'Contratado' };
List<Job_Application__c> newApps = new List<Job_Application__c>();
List<String> appRows = new List<String>();
for (String row : appData) {
    List<String> p = row.split('#', -1);
    Candidate__c cand = candByKey.get(p[1]);
    String uniqueKey = cand.Id + '|' + jobId.get(p[2]);
    if (existingKeys.contains(uniqueKey)) {
        continue;
    }
    newApps.add(new Job_Application__c(
        Candidate__c = cand.Id, Job_Opening__c = jobId.get(p[2]), Stage__c = p[3], Stage_Entered_Date__c = h.at(Date.valueOf(p[4])),
        Score__c = String.isBlank(p[5]) ? null : Decimal.valueOf(p[5]), Rejection_Reason__c = String.isBlank(p[6]) ? null : p[6],
        Source__c = cand.Source__c, Unique_Key__c = uniqueKey, OwnerId = queueId != null ? queueId : UserInfo.getUserId(),
        Employee__c = p[3] == 'Contratado' ? preEmployeeId : null
    ));
    appRows.add(row);
}
TriggerHandler.bypass('JobApplicationTriggerHandler');
try {
    insert newApps;
} finally {
    TriggerHandler.clearBypass('JobApplicationTriggerHandler');
}

// Historico de etapas: caminho padrao ate a etapa atual (ou ate a anterior e depois a terminal).
List<Application_Stage_History__c> history = new List<Application_Stage_History__c>();
for (Integer i = 0; i < newApps.size(); i++) {
    List<String> p = appRows[i].split('#', -1);
    Integer appNo = Integer.valueOf(p[0].substring(2));
    List<String> steps = new List<String>();
    if (p[3] == 'Reprovado' || p[3] == 'Desistiu') {
        for (Integer k = 0; k <= path.indexOf(p[7]); k++) {
            steps.add(path[k]);
        }
        steps.add(p[3]);
    } else {
        for (Integer k = 0; k <= path.indexOf(p[3]); k++) {
            steps.add(path[k]);
        }
    }
    Integer last = steps.size() - 1;
    Datetime changedAt = h.at(Date.valueOf(p[4]));
    for (Integer k = last; k >= 0; k--) {
        Integer daysInPrevious = null;
        if (k > 0) {
            daysInPrevious = baseDays.get(steps[k - 1]) + Math.mod(appNo, 3);
        }
        history.add(new Application_Stage_History__c(
            Job_Application__c = newApps[i].Id, From_Stage__c = k == 0 ? null : steps[k - 1], To_Stage__c = steps[k],
            Changed_By__c = k == 0 ? null : recruiterUser, Changed_At__c = changedAt, Days_In_Previous_Stage__c = daysInPrevious
        ));
        if (daysInPrevious != null) {
            changedAt = changedAt.addDays(-daysInPrevious);
        }
    }
}
insert history;

// O que o trigger faria depois da insercao: contagem da vaga e compartilhamento com o gestor contratante.
JobOpeningService.refreshApplicationCounts(new Set<Id>(jobId.values()));
RecruitingSharingService.recalculate(newApps);

// ------------------------------------------------------------------------- plano de onboarding (opcional)
Integer tasks = 0;
if (createOnboardingPlan && [SELECT COUNT() FROM Onboarding_Plan__c WHERE Employee__c = :preEmployeeId] == 0) {
    Job_Application__c hired = [SELECT Id FROM Job_Application__c WHERE Employee__c = :preEmployeeId LIMIT 1];
    Onboarding_Plan__c plan = new Onboarding_Plan__c(
        Employee__c = preEmployeeId, Job_Application__c = hired.Id, Start_Date__c = hireDate, Status__c = 'Nao_Iniciado'
    );
    insert plan;
    List<Onboarding_Task_Template__mdt> templates = [
        SELECT Title__c, Description__c, Owner_Role__c, Due_Offset_Days__c, Order__c, Applies_To_Employment_Type__c
        FROM Onboarding_Task_Template__mdt
        ORDER BY Order__c
    ];
    List<Onboarding_Task__c> planTasks = new List<Onboarding_Task__c>();
    for (Onboarding_Task_Template__mdt t : templates) {
        // Modelo restrito a outro tipo de contratacao nao vale para o contratado CLT.
        if (String.isNotBlank(t.Applies_To_Employment_Type__c) && !t.Applies_To_Employment_Type__c.contains('CLT')) {
            continue;
        }
        Boolean first = t.Order__c == 1;
        planTasks.add(new Onboarding_Task__c(
            Plan__c = plan.Id, Name = t.Title__c, Description__c = t.Description__c, Owner_Role__c = t.Owner_Role__c,
            Assigned_To__c = t.Owner_Role__c == 'Gestor' ? empUser.get('VTR-0007') : (t.Owner_Role__c == 'Colaborador' ? null : hrUser),
            Due_Date__c = hireDate.addDays(t.Due_Offset_Days__c.intValue()), Order__c = t.Order__c,
            Status__c = first ? 'Concluida' : 'Pendente', Completed_Date__c = first ? Datetime.now().addDays(-4) : null
        ));
    }
    insert planTasks;
    tasks = planTasks.size();
}

System.debug('Fase 4: vagas novas ' + newJobs.size() + ', candidatos novos ' + newCandidates.size() + ', candidaturas novas ' + newApps.size()
    + ', historico ' + history.size() + ', tarefas de onboarding ' + tasks + ' (plano habilitado: ' + createOnboardingPlan + ')');
