/* RH Core demo: dados ficticios da Vetra Distribuidora (spec 18). Nomes, e-mails e valores sao inventados.
   RH.seed.build() devolve um estado novo e independente a cada chamada. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./util.js');
    require('./rules-leave.js');
    require('./rules-approval.js');
    require('./rules-recruiting.js');
    require('./rules-visibility.js');
  }
  var RH = (g.RH = g.RH || {});
  var U = RH.util;
  var TODAY = U.TODAY;

  var DEPTS = [
    { code: 'DIR', name: 'Diretoria' },
    { code: 'COM', name: 'Comercial' },
    { code: 'OPL', name: 'Operações e Logística' },
    { code: 'FIN', name: 'Financeiro' },
    { code: 'PES', name: 'Pessoas (RH)' },
    { code: 'TEC', name: 'Tecnologia' }
  ];

  // [code, nome, nivel, trilha, faixa min/mid/max, proximo]
  var POSITIONS = [
    ['P01', 'Estagiário', 'Estagio', 'Tecnica', [1800, 2000, 2400], 'P02'],
    ['P02', 'Assistente', 'Junior', 'Tecnica', [2600, 3000, 3600], 'P03'],
    ['P03', 'Analista Júnior', 'Junior', 'Tecnica', [3800, 4500, 5400], 'P04'],
    ['P04', 'Analista Pleno', 'Pleno', 'Tecnica', [5500, 6800, 8200], 'P05'],
    ['P05', 'Analista Sênior', 'Senior', 'Tecnica', [8000, 9800, 12000], 'P06'],
    ['P06', 'Especialista', 'Especialista', 'Tecnica', [11000, 13500, 16500], 'P07'],
    ['P07', 'Especialista Principal', 'Especialista', 'Tecnica', [15000, 18000, 22000], null],
    ['P08', 'Coordenador', 'Coordenacao', 'Gestao', [12000, 15000, 19000], 'P09'],
    ['P09', 'Gerente', 'Gerencia', 'Gestao', [18000, 23000, 28000], 'P10'],
    ['P10', 'Diretor', 'Diretoria', 'Gestao', [28000, 36000, 45000], 'P11'],
    ['P11', 'Diretor-Presidente', 'Diretoria', 'Gestao', [50000, 65000, 80000], null],
    ['P12', 'Analista de Sistemas Júnior', 'Junior', 'Tecnica', [4500, 5500, 6500], 'P13'],
    ['P13', 'Analista de Sistemas Pleno', 'Pleno', 'Tecnica', [7000, 8500, 10000], 'P14'],
    ['P14', 'Analista de Sistemas Sênior', 'Senior', 'Tecnica', [10500, 12500, 15000], 'P06']
  ];

  // [matricula, nome, cargo, depto, gestor, admissao, salario, status, tipo, localidade]
  var SP = 'SP-SAO_PAULO';
  var GU = 'SP-GUARULHOS';
  var EMPLOYEES = [
    ['VTR-0001', 'Helena Moraes Vasconcelos', 'P11', 'DIR', null, '2019-01-07', 68000, 'Ativo', 'CLT', SP],
    ['VTR-0002', 'Rodrigo Tavares', 'P10', 'COM', 'VTR-0001', '2019-02-04', 38000, 'Ativo', 'CLT', SP],
    ['VTR-0003', 'Camila Duarte', 'P10', 'OPL', 'VTR-0001', '2019-02-18', 36500, 'Ativo', 'CLT', GU],
    ['VTR-0004', 'Eduardo Pacheco', 'P10', 'FIN', 'VTR-0001', '2019-03-11', 37000, 'Ativo', 'CLT', SP],
    ['VTR-0005', 'Marina Albuquerque', 'P09', 'PES', 'VTR-0001', '2019-05-06', 24500, 'Ativo', 'CLT', SP],
    ['VTR-0006', 'Felipe Nogueira', 'P09', 'TEC', 'VTR-0001', '2019-06-17', 25500, 'Ativo', 'CLT', SP],
    ['VTR-0007', 'Patrícia Lemos', 'P08', 'COM', 'VTR-0002', '2020-01-13', 16200, 'Ativo', 'CLT', SP],
    ['VTR-0008', 'André Siqueira', 'P08', 'COM', 'VTR-0002', '2020-08-03', 15400, 'Ativo', 'CLT', SP],
    ['VTR-0009', 'Beatriz Cardoso', 'P08', 'OPL', 'VTR-0003', '2020-02-03', 15800, 'Ativo', 'CLT', GU],
    ['VTR-0010', 'Gustavo Ramos', 'P08', 'OPL', 'VTR-0003', '2021-04-12', 14800, 'Ativo', 'CLT', GU],
    ['VTR-0011', 'Larissa Menezes', 'P08', 'FIN', 'VTR-0004', '2020-09-14', 16500, 'Ativo', 'CLT', SP],
    ['VTR-0012', 'Renato Farias', 'P08', 'PES', 'VTR-0005', '2021-02-01', 14600, 'Ativo', 'CLT', SP],
    ['VTR-0013', 'Juliana Prado', 'P08', 'TEC', 'VTR-0006', '2020-10-19', 17200, 'Ativo', 'CLT', SP],
    ['VTR-0014', 'Thiago Barbosa', 'P08', 'TEC', 'VTR-0006', '2021-07-19', 15900, 'Ativo', 'CLT', SP],
    ['VTR-0015', 'Carolina Fontes', 'P05', 'COM', 'VTR-0007', '2021-03-01', 9600, 'Ativo', 'CLT', SP],
    ['VTR-0016', 'Lucas Andrade', 'P04', 'COM', 'VTR-0007', '2020-06-15', 6900, 'Ativo', 'CLT', SP],
    ['VTR-0017', 'Bruna Teixeira', 'P03', 'COM', 'VTR-0007', '2023-02-01', 4700, 'Ativo', 'CLT', SP],
    ['VTR-0018', 'Diego Cavalcanti', 'P02', 'COM', 'VTR-0007', '2019-08-12', 3150, 'Ferias', 'CLT', SP],
    ['VTR-0019', 'Fernanda Rocha', 'P04', 'COM', 'VTR-0008', '2022-01-10', 6500, 'Ativo', 'CLT', SP],
    ['VTR-0020', 'Vinícius Azevedo', 'P03', 'COM', 'VTR-0008', '2024-09-02', 4200, 'Ativo', 'CLT', SP],
    ['VTR-0021', 'Isabela Martins', 'P01', 'COM', 'VTR-0008', '2026-02-02', 2000, 'Ativo', 'Estagio', SP],
    ['VTR-0022', 'Rafael Brandão', 'P05', 'OPL', 'VTR-0009', '2019-12-02', 9200, 'Ativo', 'CLT', GU],
    ['VTR-0023', 'Aline Cunha', 'P04', 'OPL', 'VTR-0009', '2022-02-14', 6600, 'Ativo', 'CLT', GU],
    ['VTR-0024', 'Mateus Pires', 'P02', 'OPL', 'VTR-0009', '2022-05-09', 2900, 'Ativo', 'CLT', GU],
    ['VTR-0025', 'Sérgio Falcão', 'P04', 'OPL', 'VTR-0010', '2021-10-04', 7000, 'Ativo', 'CLT', GU],
    ['VTR-0026', 'Natália Gomes', 'P02', 'OPL', 'VTR-0010', '2023-03-20', 3000, 'Ativo', 'CLT', GU],
    ['VTR-0027', 'Otávio Leal', 'P02', 'OPL', 'VTR-0010', '2022-08-15', 2800, 'Desligado', 'CLT', GU],
    ['VTR-0028', 'Priscila Vieira', 'P05', 'FIN', 'VTR-0011', '2019-11-04', 10100, 'Ativo', 'CLT', SP],
    ['VTR-0029', 'Henrique Dantas', 'P04', 'FIN', 'VTR-0011', '2021-09-13', 6400, 'Ativo', 'CLT', SP],
    ['VTR-0030', 'Tatiane Borges', 'P02', 'FIN', 'VTR-0011', '2025-04-07', 2700, 'Ativo', 'CLT', SP],
    ['VTR-0031', 'Cláudia Rezende', 'P04', 'PES', 'VTR-0012', '2022-03-07', 6800, 'Ativo', 'CLT', SP],
    ['VTR-0032', 'Marcelo Ibrahim', 'P04', 'PES', 'VTR-0012', '2023-08-14', 6200, 'Ativo', 'CLT', SP],
    ['VTR-0033', 'Amanda Torres', 'P01', 'PES', 'VTR-0012', '2026-03-02', 2000, 'Ativo', 'Estagio', SP],
    ['VTR-0034', 'Leonardo Xavier', 'P14', 'TEC', 'VTR-0013', '2020-04-06', 12900, 'Ativo', 'CLT', SP],
    ['VTR-0035', 'Paula Guimarães', 'P13', 'TEC', 'VTR-0013', '2022-07-04', 8300, 'Ativo', 'CLT', SP],
    ['VTR-0036', 'Caio Ferraz', 'P12', 'TEC', 'VTR-0013', '2024-01-08', 5300, 'Ativo', 'CLT', SP],
    ['VTR-0037', 'Sabrina Lopes', 'P13', 'TEC', 'VTR-0013', '2023-06-12', 8100, 'Ativo', 'CLT', SP],
    ['VTR-0038', 'Murilo Campos', 'P14', 'TEC', 'VTR-0014', '2021-02-22', 11800, 'Ativo', 'CLT', SP],
    ['VTR-0039', 'Raquel Domingues', 'P13', 'TEC', 'VTR-0014', '2023-10-09', 7600, 'Ativo', 'CLT', SP],
    ['VTR-0040', 'Wesley Nunes', 'P02', 'TEC', 'VTR-0014', '2025-01-13', 3100, 'Ativo', 'CLT', SP]
  ];
  // Faltas injustificadas por periodo aquisitivo (chave = inicio do periodo).
  var ABSENCES = {
    'VTR-0029': { '2025-09-13': 8 },
    'VTR-0023': { '2025-02-14': 16 },
    'VTR-0024': { '2025-05-09': 35 }
  };

  // Feriados nacionais 2026 e 2027, mais estadual e municipais de Sao Paulo.
  var HOLIDAYS = [
    ['2026-01-01', 'Confraternização Universal', '', 'Nacional'],
    ['2026-01-25', 'Aniversário de São Paulo', SP, 'Municipal'],
    ['2026-04-03', 'Sexta-feira Santa', '', 'Nacional'],
    ['2026-04-21', 'Tiradentes', '', 'Nacional'],
    ['2026-05-01', 'Dia do Trabalho', '', 'Nacional'],
    ['2026-06-04', 'Corpus Christi', SP, 'Municipal'],
    ['2026-07-09', 'Revolução Constitucionalista', '', 'Estadual'],
    ['2026-09-07', 'Independência do Brasil', '', 'Nacional'],
    ['2026-10-12', 'Nossa Senhora Aparecida', '', 'Nacional'],
    ['2026-11-02', 'Finados', '', 'Nacional'],
    ['2026-11-15', 'Proclamação da República', '', 'Nacional'],
    ['2026-11-20', 'Consciência Negra', '', 'Nacional'],
    ['2026-12-25', 'Natal', '', 'Nacional'],
    ['2027-01-01', 'Confraternização Universal', '', 'Nacional'],
    ['2027-01-25', 'Aniversário de São Paulo', SP, 'Municipal'],
    ['2027-03-26', 'Sexta-feira Santa', '', 'Nacional'],
    ['2027-04-21', 'Tiradentes', '', 'Nacional'],
    ['2027-05-01', 'Dia do Trabalho', '', 'Nacional'],
    ['2027-05-27', 'Corpus Christi', SP, 'Municipal'],
    ['2027-07-09', 'Revolução Constitucionalista', '', 'Estadual'],
    ['2027-09-07', 'Independência do Brasil', '', 'Nacional'],
    ['2027-10-12', 'Nossa Senhora Aparecida', '', 'Nacional'],
    ['2027-11-02', 'Finados', '', 'Nacional'],
    ['2027-11-15', 'Proclamação da República', '', 'Nacional'],
    ['2027-11-20', 'Consciência Negra', '', 'Nacional'],
    ['2027-12-25', 'Natal', '', 'Nacional']
  ];

  // Modelos de onboarding (Onboarding_Task_Template__mdt, spec 15 O3).
  var ONBOARDING_TEMPLATES = [
    { title: 'Enviar documentos admissionais', description: 'Enviar os documentos pessoais exigidos para o registro.', role: 'Colaborador', offset: -10 },
    { title: 'Conferir documentos e exame admissional', description: 'Conferir a documentação e agendar o exame admissional.', role: 'RH', offset: -5 },
    { title: 'Preparar equipamento e acessos', description: 'Separar notebook e criar contas e acessos.', role: 'TI', offset: -3 },
    { title: 'Definir padrinho ou madrinha', description: 'Escolher alguém da equipe para acompanhar as primeiras semanas.', role: 'Gestor', offset: -3 },
    { title: 'Reunião de boas-vindas', description: 'Apresentar a equipe e a rotina de trabalho.', role: 'Gestor', offset: 0 },
    { title: 'Apresentar políticas internas', description: 'Apresentar código de conduta, segurança da informação e benefícios.', role: 'RH', offset: 1 },
    { title: 'Plano de 30 dias definido', description: 'Registrar as entregas esperadas do primeiro mês.', role: 'Gestor', offset: 5 },
    { title: 'Conversa de 30 dias', description: 'Reunião de acompanhamento do primeiro mês.', role: 'Gestor', offset: 30 }
  ];

  var GOAL_TEMPLATES = {
    COM: ['Atingir a meta trimestral de receita', 'Ampliar a carteira de clientes ativos', 'Manter o CRM atualizado'],
    OPL: ['Reduzir o tempo médio de separação de pedidos', 'Manter a acuracidade de estoque acima de 98%', 'Cumprir o plano de entregas no prazo'],
    FIN: ['Fechar o mês contábil até o 5º dia útil', 'Reduzir pendências de conciliação', 'Automatizar um relatório recorrente'],
    PES: ['Reduzir o tempo médio de contratação', 'Concluir o plano de treinamento do trimestre', 'Acompanhar os indicadores de clima'],
    TEC: ['Entregar as histórias priorizadas do trimestre', 'Manter a cobertura de testes acima de 85%', 'Reduzir chamados recorrentes'],
    DIR: ['Cumprir o plano estratégico do ano', 'Desenvolver sucessores', 'Acompanhar o orçamento da área']
  };

  var CANDIDATE_NAMES = [
    'Ricardo Sampaio', 'Letícia Coutinho', 'Gabriel Nakamura', 'Mariana Peixoto', 'Bruno Santana', 'Camille Oliveira', 'Daniel Albuquerque',
    'Eliane Magalhães', 'Fábio Ventura', 'Giovana Pinheiro', 'Heitor Barreto', 'Ingrid Salgado', 'João Pedro Macedo', 'Karina Ueda',
    'Leandro Cordeiro', 'Mônica Rangel', 'Nelson Furtado', 'Olívia Marques', 'Paulo Henrique Assis', 'Quésia Lacerda', 'Rodolfo Sena',
    'Sofia Bittencourt', 'Tales Moreira', 'Úrsula Calado', 'Valter Esteves'
  ];
  var CITIES = ['São Paulo', 'Campinas', 'Santo André', 'Guarulhos', 'Osasco', 'Curitiba', 'Belo Horizonte', 'Rio de Janeiro'];
  var SOURCES = ['Portal', 'LinkedIn', 'Indicacao', 'Portal', 'Portal', 'Outro'];

  // [id, candidato, vaga, etapa, entrou na etapa, nota, motivo, etapa anterior (para terminais), ultima atividade]
  var APPLICATIONS = [
    ['A-001', 'C-03', 'JOB-1', 'Contratado', '2026-10-19', 5, null, null, null],
    ['A-002', 'C-01', 'JOB-1', 'Proposta', '2026-10-22', 4, null, null, null],
    ['A-003', 'C-02', 'JOB-1', 'Entrevista_Tecnica', '2026-10-20', null, null, null, null],
    ['A-004', 'C-04', 'JOB-1', 'Entrevista_Tecnica', '2026-10-23', null, null, null, null],
    ['A-005', 'C-05', 'JOB-1', 'Entrevista_RH', '2026-10-21', null, null, null, null],
    ['A-006', 'C-06', 'JOB-1', 'Triagem', '2026-10-15', null, null, null, null],
    ['A-007', 'C-07', 'JOB-1', 'Triagem', '2026-10-19', null, null, null, null],
    ['A-008', 'C-08', 'JOB-1', 'Nova', '2026-10-25', null, null, null, null],
    ['A-009', 'C-09', 'JOB-1', 'Nova', '2026-10-26', null, null, null, null],
    ['A-010', 'C-10', 'JOB-1', 'Reprovado', '2026-10-12', null, 'Perfil', 'Triagem', null],
    ['A-011', 'C-11', 'JOB-1', 'Desistiu', '2026-10-14', null, null, 'Triagem', null],
    ['A-012', 'C-12', 'JOB-1', 'Nova', '2026-10-24', null, null, null, null],
    ['A-013', 'C-13', 'JOB-2', 'Proposta', '2026-10-21', 5, null, null, null],
    ['A-014', 'C-14', 'JOB-2', 'Entrevista_Tecnica', '2026-10-22', null, null, null, null],
    ['A-015', 'C-15', 'JOB-2', 'Entrevista_RH', '2026-10-23', null, null, null, null],
    ['A-016', 'C-16', 'JOB-2', 'Entrevista_RH', '2026-10-18', null, null, null, null],
    ['A-017', 'C-17', 'JOB-2', 'Triagem', '2026-10-22', null, null, null, null],
    ['A-018', 'C-18', 'JOB-2', 'Triagem', '2026-10-20', null, null, null, null],
    ['A-019', 'C-19', 'JOB-2', 'Nova', '2026-10-26', null, null, null, null],
    ['A-020', 'C-20', 'JOB-2', 'Reprovado', '2026-04-02', null, 'Salario', 'Entrevista_RH', '2026-04-02'],
    ['A-021', 'C-02', 'JOB-2', 'Nova', '2026-10-25', null, null, null, null],
    ['A-022', 'C-21', 'JOB-3', 'Entrevista_RH', '2026-10-19', null, null, null, null],
    ['A-023', 'C-22', 'JOB-3', 'Triagem', '2026-10-17', null, null, null, null],
    ['A-024', 'C-23', 'JOB-3', 'Nova', '2026-10-23', null, null, null, null],
    ['A-025', 'C-24', 'JOB-3', 'Nova', '2026-10-22', null, null, null, null],
    ['A-026', 'C-25', 'JOB-3', 'Reprovado', '2026-03-10', null, 'Localizacao', 'Triagem', '2026-03-10'],
    ['A-027', 'C-08', 'JOB-3', 'Nova', '2026-10-25', null, null, null, null],
    ['A-028', 'C-10', 'JOB-4', 'Triagem', '2026-10-16', null, null, null, null],
    ['A-029', 'C-04', 'JOB-4', 'Nova', '2026-10-24', null, null, null, null],
    ['A-030', 'C-06', 'JOB-4', 'Desistiu', '2026-10-09', null, null, 'Triagem', null]
  ];

  var PATH = ['Nova', 'Triagem', 'Entrevista_RH', 'Entrevista_Tecnica', 'Proposta', 'Contratado'];

  function buildState() {
    var st = {
      version: 3,
      today: TODAY,
      settings: U.clone(RH.leave.DEFAULT_SETTINGS),
      absenceRules: U.clone(RH.leave.DEFAULT_ABSENCE_RULES),
      departments: DEPTS.map(function (d) { return { code: d.code, name: d.name }; }),
      positions: {},
      employees: [],
      holidays: HOLIDAYS.map(function (h) { return { date: h[0], name: h[1], location: h[2], type: h[3] }; }),
      positionHistory: [],
      leaveRequests: [],
      promotions: [],
      jobs: [],
      candidates: [],
      applications: [],
      stageHistory: [],
      cycle: null,
      goals: [],
      selfAssessments: {},
      reviews: {},
      onboardingPlans: [],
      portal: { boost: {}, log: [] },
      seq: { FE: 13, PR: 4, APP: 31, CAND: 26, GOAL: 1, PLAN: 2, TASK: 9, EH: 1, PRE: 2 },
      onboardingTemplates: U.clone(ONBOARDING_TEMPLATES)
    };

    POSITIONS.forEach(function (p) {
      st.positions[p[0]] = { code: p[0], name: p[1], level: p[2], track: p[3], band: { min: p[4][0], mid: p[4][1], max: p[4][2] }, next: p[5], active: true };
    });

    EMPLOYEES.forEach(function (e) {
      var first = e[1].split(' ')[0];
      var last = e[1].split(' ').slice(-1)[0];
      st.employees.push({
        num: e[0],
        name: e[1],
        email: U.slugify(first + ' ' + last).replace(/-/g, '.') + '@vetra.example',
        pos: e[2],
        dept: e[3],
        mgr: e[4],
        hire: e[5],
        term: e[7] === 'Desligado' ? '2026-08-14' : null,
        status: e[7],
        type: e[8],
        salary: e[6],
        location: e[9],
        absences: ABSENCES[e[0]] || {}
      });
    });
    // Colaborador contratado (aguarda ativacao pelo RH).
    st.employees.push({
      num: 'PRE-000001', name: 'Gabriel Nakamura', email: 'gabriel.nakamura@vetra.example', pos: 'P04', dept: 'COM', mgr: 'VTR-0007',
      hire: U.addDays(TODAY, 15), term: null, status: 'Pre_Admissao', type: 'CLT', salary: null, location: SP, absences: {}
    });

    var byNum = {};
    st.employees.forEach(function (e) { byNum[e.num] = e; });

    // Historico de cargo: admissao para todos, com trajetorias detalhadas para alguns.
    var custom = {
      'VTR-0022': [['P03', 'OPL', '2019-12-02', '2021-12-31', 4300, 'Admissao'], ['P04', 'OPL', '2022-01-01', '2025-06-30', 7400, 'Merito'], ['P05', 'OPL', '2025-07-01', null, 9200, 'Promocao']],
      'VTR-0015': [['P04', 'COM', '2021-03-01', '2024-03-31', 6100, 'Admissao'], ['P05', 'COM', '2024-04-01', null, 9600, 'Promocao']],
      'VTR-0016': [['P03', 'COM', '2020-06-15', '2022-06-30', 4300, 'Admissao'], ['P04', 'COM', '2022-07-01', null, 6900, 'Merito']],
      'VTR-0007': [['P05', 'COM', '2020-01-13', '2023-04-30', 9300, 'Admissao'], ['P08', 'COM', '2023-05-01', null, 16200, 'Promocao']]
    };
    st.employees.forEach(function (e) {
      if (e.status === 'Pre_Admissao') return;
      var rows = custom[e.num] || [[e.pos, e.dept, e.hire, e.term, e.salary, 'Admissao']];
      rows.forEach(function (r) {
        st.positionHistory.push({ empNum: e.num, pos: r[0], dept: r[1], start: r[2], end: r[3], salary: r[4], reason: r[5], promotionId: null });
      });
    });

    // ------------------------------------------------------------ Ferias
    function mkSteps(kind, requester, subjectNum, decisions) {
      var base = RH.approval.submit(kind, requester, byNum[subjectNum], byNum, '2026-10-01');
      var steps = base.steps;
      var di = 0;
      steps.forEach(function (s) {
        if (s.skipped) return;
        var d = decisions[di++];
        if (!d) return;
        s.status = d.status;
        s.decidedBy = d.by;
        s.decisionDate = d.date;
        s.comments = d.comment || '';
      });
      var rejected = steps.some(function (s) { return s.status === 'Rejeitado'; });
      if (rejected) steps.forEach(function (s) { if (s.status === 'Pendente') s.status = 'Cancelado'; });
      var pending = steps.filter(function (s) { return s.status === 'Pendente'; })[0];
      return { steps: steps, step: pending ? pending.order : 0 };
    }
    function addLeave(n, empNum, periodStart, start, days, sold, status, decisions, created, notes) {
      var emp = byNum[empNum];
      var st2 = status === 'Rascunho' ? { steps: [], step: 0 } : mkSteps('Leave', empNum, empNum, decisions || []);
      st.leaveRequests.push({
        id: 'FE-' + U.pad(n, 6), empNum: empNum, periodKey: empNum + '|' + periodStart, start: start, days: days, sold: sold || 0,
        status: status, step: st2.step, requestedBy: empNum, notes: notes || '', steps: st2.steps, createdAt: created, conflict: '', ruleCheck: null, location: emp.location
      });
    }
    var HR = 'VTR-0031';
    function ok(by, date) { return { status: 'Aprovado', by: by, date: date }; }
    addLeave(1, 'VTR-0015', '2024-03-01', '2025-12-01', 20, 10, 'Concluido', [ok('VTR-0007', '2025-10-10'), ok(HR, '2025-10-13')], '2025-10-06', 'Férias de fim de ano com abono');
    addLeave(2, 'VTR-0016', '2025-06-15', '2026-12-14', 14, 0, 'Aprovado', [ok('VTR-0007', '2026-10-05'), ok(HR, '2026-10-06')], '2026-10-01');
    addLeave(3, 'VTR-0017', '2025-02-01', '2026-12-07', 10, 0, 'Pendente', [], '2026-10-23');
    addLeave(4, 'VTR-0018', '2025-08-12', '2026-10-19', 15, 0, 'Em_Gozo', [ok('VTR-0007', '2026-08-20'), ok(HR, '2026-08-21')], '2026-08-17');
    addLeave(5, 'VTR-0019', '2025-01-10', '2026-11-30', 20, 0, 'Pendente', [ok('VTR-0008', '2026-10-22')], '2026-10-20');
    addLeave(6, 'VTR-0020', '2025-09-02', '2026-11-23', 10, 0, 'Rejeitado', [{ status: 'Rejeitado', by: 'VTR-0008', date: '2026-10-14', comment: 'Fechamento do trimestre e pico de vendas. Podemos reagendar para janeiro.' }], '2026-10-12');
    addLeave(7, 'VTR-0009', '2025-02-03', '2027-01-11', 20, 0, 'Aprovado', [ok('VTR-0003', '2026-10-02'), ok(HR, '2026-10-05')], '2026-09-28');
    addLeave(8, 'VTR-0014', '2024-07-19', '2026-04-13', 14, 0, 'Concluido', [ok('VTR-0006', '2026-02-20'), ok(HR, '2026-02-23')], '2026-02-16');
    addLeave(9, 'VTR-0014', '2024-07-19', '2026-06-22', 16, 0, 'Concluido', [ok('VTR-0006', '2026-04-20'), ok(HR, '2026-04-22')], '2026-04-16');
    addLeave(10, 'VTR-0036', '2025-01-08', '2026-12-21', 10, 0, 'Rascunho', [], '2026-10-24', 'Rascunho: falta enviar para aprovação');
    addLeave(11, 'VTR-0028', '2024-11-04', '2026-08-10', 15, 0, 'Cancelado', [], '2026-06-15', 'Cancelado pelo colaborador (projeto de fechamento)');
    addLeave(12, 'VTR-0037', '2025-06-12', '2026-11-23', 20, 0, 'Aprovado', [ok('VTR-0013', '2026-09-30'), ok(HR, '2026-10-01')], '2026-09-25');
    // Etapas do pedido cancelado: tudo cancelado.
    st.leaveRequests[10].steps = RH.approval.submit('Leave', 'VTR-0028', byNum['VTR-0028'], byNum, '2026-06-15').steps.map(function (s) {
      s.status = 'Cancelado'; return s;
    });
    st.leaveRequests[10].step = 0;

    // ------------------------------------------------------------ Promocoes
    function addPromo(n, empNum, curPos, newPos, curSal, propSal, justification, effective, status, requester, decisions, created) {
      var p = mkSteps('Promotion', requester, empNum, decisions);
      st.promotions.push({
        id: 'PR-' + U.pad(n, 6), empNum: empNum, curPos: curPos, newPos: newPos, curSalary: curSal, proposedSalary: propSal,
        justification: justification, effective: effective, status: status, step: p.step, requestedBy: requester, steps: p.steps,
        createdAt: created, outOfTrail: byNum[empNum] && st.positions[curPos].next !== newPos, hrComment: ''
      });
    }
    addPromo(1, 'VTR-0022', 'P04', 'P05', 7400, 9200, 'Liderou a reestruturação do roteiro de entregas e reduziu atrasos.', '2025-07-01', 'Efetivado', 'VTR-0009',
      [ok('VTR-0003', '2025-06-10'), ok(HR, '2025-06-12')], '2025-06-02');
    addPromo(2, 'VTR-0017', 'P03', 'P04', 4700, 5900, 'Assumiu contas médias e superou a meta por três trimestres seguidos.', '2026-12-01', 'Aprovado', 'VTR-0007',
      [ok('VTR-0002', '2026-10-20'), ok(HR, '2026-10-22')], '2026-10-15');
    addPromo(3, 'VTR-0029', 'P04', 'P05', 6400, null, 'Referência técnica em conciliação fiscal e mentora de dois assistentes.', '2026-11-16', 'Pendente', 'VTR-0011',
      [ok('VTR-0004', '2026-10-21')], '2026-10-14');
    st.promotions[0].hrComment = '';
    // Historico das promocoes ja efetivadas.
    st.positionHistory.forEach(function (h) {
      if (h.empNum === 'VTR-0022' && h.reason === 'Promocao') h.promotionId = 'PR-000001';
    });

    // ------------------------------------------------------------ Recrutamento
    var jobDesc = {
      'JOB-1': ['Atender e expandir a carteira de clientes da região Sudeste, conduzindo propostas e negociações.', 'Experiência com vendas B2B; domínio de CRM; boa comunicação escrita.'],
      'JOB-2': ['Evoluir e sustentar aplicações na plataforma Salesforce que apoiam as áreas comerciais e de pessoas.', 'Apex, Flow e LWC; testes automatizados; leitura crítica de requisitos.'],
      'JOB-3': ['Apoiar o planejamento de rotas e o acompanhamento diário das entregas do centro de distribuição.', 'Ensino superior em andamento ou concluído; domínio de planilhas; organização.'],
      'JOB-4': ['Responder pela apuração de tributos e pela conformidade fiscal das operações da distribuidora.', 'Experiência com apuração de impostos indiretos; fechamento mensal.']
    };
    [
      ['JOB-1', 'Analista de Vendas Pleno', 'P04', 'COM', 'VTR-0007', 'Aberta', true, 'Hibrido', 'São Paulo, SP', 2, '2026-09-14'],
      ['JOB-2', 'Analista de Sistemas Pleno (Salesforce)', 'P13', 'TEC', 'VTR-0013', 'Aberta', true, 'Remoto', 'Brasil (remoto)', 1, '2026-03-23'],
      ['JOB-3', 'Analista de Logística Júnior', 'P03', 'OPL', 'VTR-0009', 'Aberta', false, 'Presencial', 'Guarulhos, SP', 1, '2026-02-16'],
      ['JOB-4', 'Analista Fiscal Sênior', 'P05', 'FIN', 'VTR-0011', 'Pausada', false, 'Hibrido', 'São Paulo, SP', 1, '2026-08-03']
    ].forEach(function (j) {
      var taken = st.jobs.map(function (x) { return x.slug; });
      st.jobs.push({
        id: j[0], title: j[1], slug: RH.recruiting.uniqueSlug(j[1], taken), pos: j[2], dept: j[3], hiringManager: j[4], recruiter: 'VTR-0032',
        status: j[5], publishOnPortal: j[6], workModel: j[7], location: j[8], employmentType: 'CLT', description: jobDesc[j[0]][0],
        requirements: jobDesc[j[0]][1], openings: j[9], openedDate: j[10], closedDate: null
      });
    });

    CANDIDATE_NAMES.forEach(function (name, i) {
      var id = 'C-' + U.pad(i + 1, 2);
      var parts = name.split(' ');
      var email = U.slugify(parts[0] + ' ' + parts[parts.length - 1]).replace(/-/g, '.') + '@mail.example';
      st.candidates.push({
        id: id, name: name, email: email, emailNorm: email, phone: '(11) 9' + U.pad(4000 + i * 137, 4) + '-' + U.pad(1000 + i * 71, 4), city: CITIES[i % CITIES.length],
        linkedin: '', source: SOURCES[i % SOURCES.length], consent: true, consentDate: '2026-10-01', consentVersion: '2026-10', anonymized: false, lastActivity: null
      });
    });
    var cById = {};
    st.candidates.forEach(function (c) { cById[c.id] = c; });
    var ehSeq = 1;
    APPLICATIONS.forEach(function (a) {
      var app = {
        id: a[0], candidateId: a[1], jobId: a[2], stage: a[3], stageEntered: a[4], score: a[5], rejectionReason: a[6],
        source: cById[a[1]].source, coverLetter: '', createdAt: null, employeeNum: null
      };
      // Historico: caminho padrao ate a etapa atual, 3 dias por etapa.
      var path;
      if (a[3] === 'Reprovado' || a[3] === 'Desistiu') path = PATH.slice(0, PATH.indexOf(a[7]) + 1).concat([a[3]]);
      else path = PATH.slice(0, PATH.indexOf(a[3]) + 1);
      var k = path.length - 1;
      path.forEach(function (stg, i) {
        var at = U.addDays(a[4], -3 * (k - i));
        if (i === 0) app.createdAt = at;
        st.stageHistory.push({ id: 'EH-' + U.pad(ehSeq++, 6), appId: a[0], from: i === 0 ? '' : path[i - 1], to: stg, by: i === 0 ? 'Portal' : 'VTR-0032', at: at, daysInPrev: i === 0 ? null : 3 });
      });
      if (a[8]) cById[a[1]].lastActivity = a[8];
      st.applications.push(app);
    });
    st.seq.EH = ehSeq;
    // A candidatura contratada ja virou colaborador em pre-admissao.
    st.applications[0].employeeNum = 'PRE-000001';
    st.candidates.forEach(function (c) {
      if (c.lastActivity) return;
      c.lastActivity = st.applications.filter(function (a) { return a.candidateId === c.id; }).map(function (a) { return a.stageEntered; }).sort().pop() || '2026-10-01';
    });

    // ------------------------------------------------------------ Desempenho
    st.cycle = { id: 'CYC-2026', name: 'Ciclo 2026', start: '2026-01-01', end: '2026-12-31', selfDue: '2026-11-06', managerDue: '2026-11-20', status: 'Autoavaliacao', scaleMax: 5 };
    var STRENGTHS = ['Boa comunicação com a equipe e com clientes.', 'Entrega com qualidade e dentro do prazo.', 'Toma iniciativa e propõe melhorias.', 'Organização e atenção aos detalhes.'];
    var IMPROVE = ['Delegar mais e documentar decisões.', 'Planejar melhor as prioridades da semana.', 'Aprofundar conhecimento técnico da área.', 'Dar feedback com mais frequência.'];
    var n = 0;
    st.employees.forEach(function (e) {
      if (e.status === 'Desligado' || e.status === 'Pre_Admissao') return;
      n++;
      var tpl = GOAL_TEMPLATES[e.dept];
      var weights = [40, 30, 30];
      var count = e.num === 'VTR-0015' ? 2 : 3; // Carolina so fecha 70%: demonstra a regra A4
      for (var i = 0; i < count; i++) {
        st.goals.push({ id: 'G-' + U.pad(st.seq.GOAL++, 4), empNum: e.num, name: tpl[i], description: '', weight: weights[i], target: ['100% da meta', '90% de adesão', 'Sem pendências'][i], status: 'Ativa' });
      }
      var num = parseInt(e.num.slice(4), 10);
      var submitted = num % 2 === 0;
      st.selfAssessments[e.num] = {
        empNum: e.num, rating: submitted ? 3 + (num % 3) : null, strengths: submitted ? STRENGTHS[num % 4] : '', improvements: submitted ? IMPROVE[num % 4] : '',
        submitted: submitted, submittedDate: submitted ? '2026-10-' + U.pad(14 + (num % 10), 2) : null
      };
      if (e.mgr) {
        st.reviews[e.num] = { empNum: e.num, reviewer: e.mgr, status: 'Pendente', managerRating: null, comments: '', calibrated: null, releasedDate: null };
      }
    });

    // ------------------------------------------------------------ Onboarding
    var hire = U.addDays(TODAY, 15);
    var plan = { id: 'ON-000001', empNum: 'PRE-000001', appId: 'A-001', start: hire, status: 'Nao_Iniciado', tasks: [] };
    ONBOARDING_TEMPLATES.forEach(function (t, i) {
      var assigned = t.role === 'Colaborador' ? 'PRE-000001' : t.role === 'Gestor' ? 'VTR-0007' : 'VTR-0031';
      plan.tasks.push({
        id: 'T-' + U.pad(i + 1, 4), title: t.title, description: t.description, role: t.role, assigned: assigned, due: U.addDays(hire, t.offset),
        status: i === 0 ? 'Concluida' : 'Pendente', completedAt: i === 0 ? '2026-10-22' : null, order: i + 1
      });
    });
    st.onboardingPlans.push(plan);

    return st;
  }

  RH.seed = { build: buildState, ONBOARDING_TEMPLATES: ONBOARDING_TEMPLATES, DEPTS: DEPTS };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.seed;
})(globalThis);
