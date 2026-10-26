// RH Core, dados de demonstracao da Vetra Distribuidora (empresa ficticia). Fase 1: estrutura da empresa.
// Projeto demonstrativo, empresa e dados ficticios. Nenhum dado real.
//
// Cria 6 departamentos, 14 faixas salariais e 14 cargos em 2 trilhas, 40 colaboradores em arvore de 4 niveis
// (matricula VTR-0001 em diante) e os feriados de 2026 e 2027. Idempotente: tudo e upsert por chave externa
// (ou por nome, onde o objeto nao tem chave externa). Executar como o admin com HR_Admin e HR_Manager.
// O usuario que executa vira o colaborador VTR-0007 (Patricia Lemos, coordenadora comercial, nivel 2 da arvore),
// que e a persona "Gestor" da demonstracao; os demais usuarios vem da fase 0.

class Seed1 {
    String slug(String s) {
        String r = s.toLowerCase();
        List<String> from1 = new List<String>{ 'á', 'à', 'â', 'ã', 'é', 'ê', 'í', 'ó', 'ô', 'õ', 'ú', 'ü', 'ç', ' ' };
        List<String> to1 = new List<String>{ 'a', 'a', 'a', 'a', 'e', 'e', 'i', 'o', 'o', 'o', 'u', 'u', 'c', '.' };
        for (Integer i = 0; i < from1.size(); i++) {
            r = r.replace(from1[i], to1[i]);
        }
        return r;
    }
}
Seed1 helper = new Seed1();

// ---------------------------------------------------------------------------------------------- departamentos
List<String> deptData = new List<String>{
    'DIR#Diretoria#CC-100', 'COM#Comercial#CC-200', 'OPL#Operações e Logística#CC-300',
    'FIN#Financeiro#CC-400', 'PES#Pessoas (RH)#CC-500', 'TEC#Tecnologia#CC-600'
};
List<Department__c> depts = new List<Department__c>();
for (String row : deptData) {
    List<String> p = row.split('#');
    depts.add(new Department__c(Code__c = p[0], Name = p[1], Cost_Center__c = p[2], Active__c = true));
}
upsert depts Department__c.Code__c;
Map<String, Id> deptId = new Map<String, Id>();
for (Department__c d : depts) {
    deptId.put(d.Code__c, d.Id);
}
for (Department__c d : depts) {
    d.Parent_Department__c = d.Code__c == 'DIR' ? null : deptId.get('DIR');
}
update depts;

// ---------------------------------------------------------------------------- cargos e faixas salariais
// codigo#nome#nivel#trilha#min#mid#max#proximo
List<String> posData = new List<String>{
    'P01#Estagiário#Estagio#Tecnica#1800#2000#2400#P02', 'P02#Assistente#Junior#Tecnica#2600#3000#3600#P03',
    'P03#Analista Júnior#Junior#Tecnica#3800#4500#5400#P04', 'P04#Analista Pleno#Pleno#Tecnica#5500#6800#8200#P05',
    'P05#Analista Sênior#Senior#Tecnica#8000#9800#12000#P06', 'P06#Especialista#Especialista#Tecnica#11000#13500#16500#P07',
    'P07#Especialista Principal#Especialista#Tecnica#15000#18000#22000#',
    'P08#Coordenador#Coordenacao#Gestao#12000#15000#19000#P09', 'P09#Gerente#Gerencia#Gestao#18000#23000#28000#P10',
    'P10#Diretor#Diretoria#Gestao#28000#36000#45000#P11', 'P11#Diretor-Presidente#Diretoria#Gestao#50000#65000#80000#',
    'P12#Analista de Sistemas Júnior#Junior#Tecnica#4500#5500#6500#P13',
    'P13#Analista de Sistemas Pleno#Pleno#Tecnica#7000#8500#10000#P14',
    'P14#Analista de Sistemas Sênior#Senior#Tecnica#10500#12500#15000#P06'
};
Set<String> bandNames = new Set<String>();
for (String row : posData) {
    bandNames.add('Faixa ' + row.split('#')[1]);
}
Map<String, Salary_Band__c> bandByName = new Map<String, Salary_Band__c>();
for (Salary_Band__c b : [SELECT Id, Name FROM Salary_Band__c WHERE Name IN :bandNames]) {
    bandByName.put(b.Name, b);
}
List<Salary_Band__c> bands = new List<Salary_Band__c>();
for (String row : posData) {
    List<String> p = row.split('#');
    Salary_Band__c b = bandByName.containsKey('Faixa ' + p[1]) ? bandByName.get('Faixa ' + p[1]) : new Salary_Band__c(Name = 'Faixa ' + p[1]);
    b.Min_Salary__c = Decimal.valueOf(p[4]);
    b.Mid_Salary__c = Decimal.valueOf(p[5]);
    b.Max_Salary__c = Decimal.valueOf(p[6]);
    bands.add(b);
}
upsert bands;
Map<String, Id> bandId = new Map<String, Id>();
for (Salary_Band__c b : bands) {
    bandId.put(b.Name, b.Id);
}
List<Job_Position__c> positions = new List<Job_Position__c>();
for (String row : posData) {
    List<String> p = row.split('#');
    positions.add(new Job_Position__c(
        Code__c = p[0], Name = p[1], Level__c = p[2], Career_Track__c = p[3], Salary_Band__c = bandId.get('Faixa ' + p[1]), Active__c = true
    ));
}
upsert positions Job_Position__c.Code__c;
Map<String, Id> posId = new Map<String, Id>();
for (Job_Position__c jp : positions) {
    posId.put(jp.Code__c, jp.Id);
}
List<Job_Position__c> chain = new List<Job_Position__c>();
for (String row : posData) {
    List<String> p = row.split('#', -1);
    chain.add(new Job_Position__c(Id = posId.get(p[0]), Next_Position__c = String.isBlank(p[7]) ? null : posId.get(p[7])));
}
update chain;

// ------------------------------------------------------------------------------------------- colaboradores
// matricula#nome#cargo#depto#gestor#admissao#salario#status#tipo#localidade
String SP = 'SP-SAO_PAULO';
String GU = 'SP-GUARULHOS';
List<String> empData = new List<String>{
    'VTR-0001#Helena Moraes Vasconcelos#P11#DIR##2019-01-07#68000#Ativo#CLT#' + SP,
    'VTR-0002#Rodrigo Tavares#P10#COM#VTR-0001#2019-02-04#38000#Ativo#CLT#' + SP,
    'VTR-0003#Camila Duarte#P10#OPL#VTR-0001#2019-02-18#36500#Ativo#CLT#' + GU,
    'VTR-0004#Eduardo Pacheco#P10#FIN#VTR-0001#2019-03-11#37000#Ativo#CLT#' + SP,
    'VTR-0005#Marina Albuquerque#P09#PES#VTR-0001#2019-05-06#24500#Ativo#CLT#' + SP,
    'VTR-0006#Felipe Nogueira#P09#TEC#VTR-0001#2019-06-17#25500#Ativo#CLT#' + SP,
    'VTR-0007#Patrícia Lemos#P08#COM#VTR-0002#2020-01-13#16200#Ativo#CLT#' + SP,
    'VTR-0008#André Siqueira#P08#COM#VTR-0002#2020-08-03#15400#Ativo#CLT#' + SP,
    'VTR-0009#Beatriz Cardoso#P08#OPL#VTR-0003#2020-02-03#15800#Ativo#CLT#' + GU,
    'VTR-0010#Gustavo Ramos#P08#OPL#VTR-0003#2021-04-12#14800#Ativo#CLT#' + GU,
    'VTR-0011#Larissa Menezes#P08#FIN#VTR-0004#2020-09-14#16500#Ativo#CLT#' + SP,
    'VTR-0012#Renato Farias#P08#PES#VTR-0005#2021-02-01#14600#Ativo#CLT#' + SP,
    'VTR-0013#Juliana Prado#P08#TEC#VTR-0006#2020-10-19#17200#Ativo#CLT#' + SP,
    'VTR-0014#Thiago Barbosa#P08#TEC#VTR-0006#2021-07-19#15900#Ativo#CLT#' + SP,
    'VTR-0015#Carolina Fontes#P05#COM#VTR-0007#2021-03-01#9600#Ativo#CLT#' + SP,
    'VTR-0016#Lucas Andrade#P04#COM#VTR-0007#2020-06-15#6900#Ativo#CLT#' + SP,
    'VTR-0017#Bruna Teixeira#P03#COM#VTR-0007#2023-02-01#4700#Ativo#CLT#' + SP,
    'VTR-0018#Diego Cavalcanti#P02#COM#VTR-0007#2019-08-12#3150#Ferias#CLT#' + SP,
    'VTR-0019#Fernanda Rocha#P04#COM#VTR-0008#2022-01-10#6500#Ativo#CLT#' + SP,
    'VTR-0020#Vinícius Azevedo#P03#COM#VTR-0008#2024-09-02#4200#Ativo#CLT#' + SP,
    'VTR-0021#Isabela Martins#P01#COM#VTR-0008#2026-02-02#2000#Ativo#Estagio#' + SP,
    'VTR-0022#Rafael Brandão#P05#OPL#VTR-0009#2019-12-02#9200#Ativo#CLT#' + GU,
    'VTR-0023#Aline Cunha#P04#OPL#VTR-0009#2022-02-14#6600#Ativo#CLT#' + GU,
    'VTR-0024#Mateus Pires#P02#OPL#VTR-0009#2022-05-09#2900#Ativo#CLT#' + GU,
    'VTR-0025#Sérgio Falcão#P04#OPL#VTR-0010#2021-10-04#7000#Ativo#CLT#' + GU,
    'VTR-0026#Natália Gomes#P02#OPL#VTR-0010#2023-03-20#3000#Ativo#CLT#' + GU,
    'VTR-0027#Otávio Leal#P02#OPL#VTR-0010#2022-08-15#2800#Desligado#CLT#' + GU,
    'VTR-0028#Priscila Vieira#P05#FIN#VTR-0011#2019-11-04#10100#Ativo#CLT#' + SP,
    'VTR-0029#Henrique Dantas#P04#FIN#VTR-0011#2021-09-13#6400#Ativo#CLT#' + SP,
    'VTR-0030#Tatiane Borges#P02#FIN#VTR-0011#2025-04-07#2700#Ativo#CLT#' + SP,
    'VTR-0031#Cláudia Rezende#P04#PES#VTR-0012#2022-03-07#6800#Ativo#CLT#' + SP,
    'VTR-0032#Marcelo Ibrahim#P04#PES#VTR-0012#2023-08-14#6200#Ativo#CLT#' + SP,
    'VTR-0033#Amanda Torres#P01#PES#VTR-0012#2026-03-02#2000#Ativo#Estagio#' + SP,
    'VTR-0034#Leonardo Xavier#P14#TEC#VTR-0013#2020-04-06#12900#Ativo#CLT#' + SP,
    'VTR-0035#Paula Guimarães#P13#TEC#VTR-0013#2022-07-04#8300#Ativo#CLT#' + SP,
    'VTR-0036#Caio Ferraz#P12#TEC#VTR-0013#2024-01-08#5300#Ativo#CLT#' + SP,
    'VTR-0037#Sabrina Lopes#P13#TEC#VTR-0013#2023-06-12#8100#Ativo#CLT#' + SP,
    'VTR-0038#Murilo Campos#P14#TEC#VTR-0014#2021-02-22#11800#Ativo#CLT#' + SP,
    'VTR-0039#Raquel Domingues#P13#TEC#VTR-0014#2023-10-09#7600#Ativo#CLT#' + SP,
    'VTR-0040#Wesley Nunes#P02#TEC#VTR-0014#2025-01-13#3100#Ativo#CLT#' + SP
};

// Vinculo com usuarios: o admin que executa e a Patricia; os demais vem da fase 0 (sufixo da org no username).
String suffix = UserInfo.getOrganizationId().toLowerCase().right(6);
Map<String, Id> userByEmployee = new Map<String, Id>{ 'VTR-0007' => UserInfo.getUserId() };
Map<String, String> userHandle = new Map<String, String>{
    'VTR-0015' => 'carolina.fontes', 'VTR-0032' => 'marcelo.ibrahim', 'VTR-0031' => 'claudia.rezende'
};
Map<String, String> handleToEmp = new Map<String, String>();
for (String num : userHandle.keySet()) {
    handleToEmp.put(userHandle.get(num) + '.' + suffix + '@vetra-rh.example', num);
}
for (User u : [SELECT Id, Username FROM User WHERE Username IN :handleToEmp.keySet()]) {
    userByEmployee.put(handleToEmp.get(u.Username), u.Id);
}

// Profundidade na arvore (0 = presidente) para inserir gestor antes de subordinado.
Map<String, String> managerOf = new Map<String, String>();
for (String row : empData) {
    List<String> p = row.split('#', -1);
    managerOf.put(p[0], p[4]);
}
Map<String, Id> empId = new Map<String, Id>();
for (Employee__c e : [SELECT Id, Employee_Number__c FROM Employee__c WHERE Employee_Number__c LIKE 'VTR-%']) {
    empId.put(e.Employee_Number__c, e.Id);
}
for (Integer depth = 0; depth < 4; depth++) {
    List<Employee__c> level = new List<Employee__c>();
    for (String row : empData) {
        List<String> p = row.split('#', -1);
        Integer d = 0;
        String cursor = p[4];
        while (String.isNotBlank(cursor)) {
            d++;
            cursor = managerOf.get(cursor);
        }
        if (d != depth) {
            continue;
        }
        List<String> names = p[1].split(' ');
        Employee__c e = new Employee__c(
            Employee_Number__c = p[0], Name = p[1], Position__c = posId.get(p[2]), Department__c = deptId.get(p[3]),
            Manager__c = String.isBlank(p[4]) ? null : empId.get(p[4]), Hire_Date__c = Date.valueOf(p[5]),
            Salary__c = Decimal.valueOf(p[6]), Status__c = p[7], Employment_Type__c = p[8], Work_Location__c = p[9],
            Email__c = helper.slug(names[0] + ' ' + names[names.size() - 1]) + '@vetra.example',
            User__c = userByEmployee.get(p[0]),
            Termination_Date__c = p[7] == 'Desligado' ? Date.newInstance(2026, 8, 14) : null
        );
        level.add(e);
    }
    upsert level Employee__c.Employee_Number__c;
    for (Employee__c e : level) {
        empId.put(e.Employee_Number__c, e.Id);
    }
}

// Responsavel de cada departamento.
Map<String, String> headOf = new Map<String, String>{
    'DIR' => 'VTR-0001', 'COM' => 'VTR-0002', 'OPL' => 'VTR-0003', 'FIN' => 'VTR-0004', 'PES' => 'VTR-0005', 'TEC' => 'VTR-0006'
};
for (Department__c d : depts) {
    d.Head__c = empId.get(headOf.get(d.Code__c));
}
update depts;

// ------------------------------------------------------------------------------------------------ feriados
// data#nome#localidade#tipo
List<String> holData = new List<String>{
    '2026-01-01#Confraternização Universal##Nacional', '2026-01-25#Aniversário de São Paulo#' + SP + '#Municipal',
    '2026-04-03#Sexta-feira Santa##Nacional', '2026-04-21#Tiradentes##Nacional', '2026-05-01#Dia do Trabalho##Nacional',
    '2026-06-04#Corpus Christi#' + SP + '#Municipal', '2026-07-09#Revolução Constitucionalista##Estadual',
    '2026-09-07#Independência do Brasil##Nacional', '2026-10-12#Nossa Senhora Aparecida##Nacional',
    '2026-11-02#Finados##Nacional', '2026-11-15#Proclamação da República##Nacional', '2026-11-20#Consciência Negra##Nacional',
    '2026-12-25#Natal##Nacional',
    '2027-01-01#Confraternização Universal##Nacional', '2027-01-25#Aniversário de São Paulo#' + SP + '#Municipal',
    '2027-03-26#Sexta-feira Santa##Nacional', '2027-04-21#Tiradentes##Nacional', '2027-05-01#Dia do Trabalho##Nacional',
    '2027-05-27#Corpus Christi#' + SP + '#Municipal', '2027-07-09#Revolução Constitucionalista##Estadual',
    '2027-09-07#Independência do Brasil##Nacional', '2027-10-12#Nossa Senhora Aparecida##Nacional',
    '2027-11-02#Finados##Nacional', '2027-11-15#Proclamação da República##Nacional', '2027-11-20#Consciência Negra##Nacional',
    '2027-12-25#Natal##Nacional'
};
List<HR_Holiday__c> holidays = new List<HR_Holiday__c>();
for (String row : holData) {
    List<String> p = row.split('#', -1);
    holidays.add(new HR_Holiday__c(
        Date__c = Date.valueOf(p[0]), Name = p[1], Location__c = String.isBlank(p[2]) ? null : p[2], Type__c = p[3],
        Unique_Key__c = p[0] + '|' + p[2]
    ));
}
upsert holidays HR_Holiday__c.Unique_Key__c;

System.debug('Fase 1: ' + depts.size() + ' departamentos, ' + positions.size() + ' cargos, ' + empId.size() + ' colaboradores, '
    + holidays.size() + ' feriados; usuarios vinculados: ' + userByEmployee.size());
