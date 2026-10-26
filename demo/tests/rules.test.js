const test = require('node:test');
const assert = require('node:assert/strict');
const RH = (require('../js/util.js'), require('../js/rules-leave.js'), require('../js/rules-approval.js'), require('../js/rules-recruiting.js'), require('../js/rules-portal.js'), require('../js/rules-promotion.js'), require('../js/rules-performance.js'), require('../js/rules-visibility.js'), require('../js/data.js'), globalThis.RH);

const V = RH.visibility;
const A = RH.approval;
const R = RH.recruiting;
const PT = RH.portal;
const PR = RH.promotion;
const PF = RH.performance;

const st = RH.seed.build();
const idx = V.buildIndex(st.employees);

// ---------------------------------------------------------------- dados
test('seed: 40 colaboradores na arvore, 1 desligado, 2 estagiarios, matriculas VTR-0001...', () => {
  const tree = st.employees.filter((e) => e.num.startsWith('VTR-'));
  assert.equal(tree.length, 40);
  assert.equal(tree.filter((e) => e.status === 'Desligado').length, 1);
  assert.equal(tree.filter((e) => e.type === 'Estagio').length, 2);
  assert.equal(tree[0].num, 'VTR-0001');
  assert.equal(Object.keys(st.positions).length, 14);
  assert.equal(st.departments.length, 6);
  assert.equal(st.candidates.length, 25);
  assert.equal(st.applications.length, 30);
  assert.equal(st.jobs.length, 4);
  assert.equal(st.jobs.filter((j) => j.publishOnPortal).length, 2);
});

// ---------------------------------------------------------------- visibilidade e FLS
test('colaborador ve so a si e a cadeia de gestores', () => {
  const set = V.visibleSet('colaborador', idx, st.employees);
  assert.deepEqual(Object.keys(set).sort(), ['VTR-0001', 'VTR-0002', 'VTR-0007', 'VTR-0015']);
  assert.equal(set['VTR-0016'], undefined); // colega de mesmo nivel
});

test('gestor ve a subarvore (direta e indireta) e nao ve outras equipes', () => {
  const set = V.visibleSet('gestor', idx, st.employees);
  ['VTR-0015', 'VTR-0016', 'VTR-0017', 'VTR-0018', 'VTR-0007'].forEach((n) => assert.ok(set[n], n));
  assert.equal(set['VTR-0019'], undefined); // equipe de outro coordenador
  assert.equal(set['VTR-0009'], undefined);
  // diretor enxerga indiretos
  const dir = V.subtree(idx, 'VTR-0002');
  assert.ok(dir.includes('VTR-0015') && dir.includes('VTR-0019') && dir.includes('VTR-0007'));
});

test('RH ve todos; candidato nao ve ninguem', () => {
  assert.equal(Object.keys(V.visibleSet('rh', idx, st.employees)).length, st.employees.length);
  assert.equal(Object.keys(V.visibleSet('candidato', idx, st.employees)).length, 0);
});

test('FLS: salario so para o RH', () => {
  assert.equal(V.canSeeSalary('rh'), true);
  ['colaborador', 'gestor', 'recrutador', 'candidato'].forEach((p) => assert.equal(V.canSeeSalary(p), false, p));
});

test('detalhe: gestor so detalha a propria subarvore', () => {
  assert.equal(V.canSeeDetail('gestor', idx, 'VTR-0016'), true);
  assert.equal(V.canSeeDetail('gestor', idx, 'VTR-0019'), false);
  assert.equal(V.canSeeDetail('colaborador', idx, 'VTR-0016'), false);
  assert.equal(V.canSeeDetail('colaborador', idx, 'VTR-0015'), true);
});

// ---------------------------------------------------------------- aprovacao
test('aprovacao de ferias em 2 etapas: gestor e depois RH', () => {
  const subject = idx.byNum['VTR-0015'];
  const s = A.submit('Leave', 'VTR-0015', subject, idx.byNum, '2026-10-26');
  const req = { steps: s.steps, step: s.currentStep, status: 'Pendente', requestedBy: 'VTR-0015' };
  assert.equal(req.step, 1);
  assert.equal(A.decide(req, { empNum: 'VTR-0015', role: 'employee' }, 'Aprovado', '', 'x').error, 'Você não é o aprovador desta etapa.');
  assert.equal(A.decide(req, { empNum: 'VTR-0031', role: 'hr' }, 'Aprovado', '', 'x').ok, false); // RH nao decide etapa do gestor
  assert.equal(A.decide(req, { empNum: 'VTR-0007', role: 'manager' }, 'Aprovado', '', 'x').outcome, 'advanced');
  assert.equal(req.step, 2);
  assert.equal(A.decide(req, { empNum: 'VTR-0007', role: 'manager' }, 'Aprovado', '', 'x').ok, false); // gestor nao decide a etapa do RH
  assert.equal(A.decide(req, { empNum: 'VTR-0031', role: 'hr' }, 'Aprovado', '', 'x').outcome, 'approved');
  assert.equal(req.status, 'Aprovado');
});

test('rejeicao exige comentario e encerra as demais etapas', () => {
  const s = A.submit('Leave', 'VTR-0015', idx.byNum['VTR-0015'], idx.byNum, 'x');
  const req = { steps: s.steps, step: s.currentStep, status: 'Pendente', requestedBy: 'VTR-0015' };
  const mgr = { empNum: 'VTR-0007', role: 'manager' };
  assert.equal(A.decide(req, mgr, 'Rejeitado', '  ', 'x').error, 'Informe um comentário para rejeitar.');
  assert.equal(A.decide(req, mgr, 'Rejeitado', 'Pico de vendas', 'x').outcome, 'rejected');
  assert.equal(req.status, 'Rejeitado');
  assert.deepEqual(req.steps.map((x) => x.status), ['Rejeitado', 'Cancelado']);
});

test('cancelamento: so o solicitante e so pendente', () => {
  const s = A.submit('Leave', 'VTR-0015', idx.byNum['VTR-0015'], idx.byNum, 'x');
  const req = { steps: s.steps, step: 1, status: 'Pendente', requestedBy: 'VTR-0015' };
  assert.equal(A.cancel(req, { empNum: 'VTR-0007' }).ok, false);
  assert.equal(A.cancel(req, { empNum: 'VTR-0015' }).ok, true);
  assert.equal(req.status, 'Cancelado');
  assert.equal(A.cancel(req, { empNum: 'VTR-0015' }).error, 'Só solicitações pendentes podem ser canceladas.');
});

test('etapa pulada quando o aprovador e o proprio solicitante ou inexistente', () => {
  // CEO nao tem gestor: etapa 1 e pulada com o motivo registrado
  const s = A.submit('Leave', 'VTR-0001', idx.byNum['VTR-0001'], idx.byNum, 'x');
  assert.equal(s.steps[0].skipped, true);
  assert.equal(s.steps[0].comments, 'Etapa pulada: aprovador indisponível');
  assert.equal(s.currentStep, 2);
});

test('promocao: aprovador de 1a etapa e o gestor do gestor', () => {
  const s = A.submit('Promotion', 'VTR-0007', idx.byNum['VTR-0016'], idx.byNum, 'x');
  assert.equal(s.steps[0].approver, 'VTR-0002');
  assert.equal(s.steps[1].type, 'HR_Team');
});

// ---------------------------------------------------------------- recrutamento
const app = (stage, extra) => Object.assign({ stage, score: null }, extra || {});

test('transicoes validas seguem a maquina de etapas', () => {
  assert.equal(R.validateTransition(app('Nova'), 'Triagem').ok, true);
  assert.equal(R.validateTransition(app('Triagem'), 'Entrevista_RH').ok, true);
  assert.equal(R.validateTransition(app('Entrevista_RH'), 'Entrevista_Tecnica').ok, true);
  assert.equal(R.validateTransition(app('Proposta'), 'Contratado').ok, true);
  assert.equal(R.validateTransition(app('Nova'), 'Desistiu').ok, true);
});

test('transicao fora da lista tem a mensagem da spec', () => {
  const r = R.validateTransition(app('Nova'), 'Proposta');
  assert.equal(r.ok, false);
  assert.equal(r.error, 'Mudança de etapa não permitida: de Nova para Proposta.');
  assert.equal(R.validateTransition(app('Contratado'), 'Triagem').ok, false); // terminal
  assert.equal(R.validateTransition(app('Reprovado'), 'Nova').ok, false);
});

test('C2: Reprovado exige motivo; Proposta exige nota', () => {
  const rej = R.validateTransition(app('Triagem'), 'Reprovado');
  assert.deepEqual(rej.needs, ['reason']);
  assert.equal(R.validateTransition(app('Triagem'), 'Reprovado', { reason: 'Perfil' }).ok, true);
  const prop = R.validateTransition(app('Entrevista_Tecnica'), 'Proposta');
  assert.deepEqual(prop.needs, ['score']);
  assert.equal(R.validateTransition(app('Entrevista_Tecnica'), 'Proposta', { score: 4 }).ok, true);
  assert.equal(R.validateTransition(app('Entrevista_Tecnica', { score: 3 }), 'Proposta').ok, true); // nota ja registrada
  assert.equal(R.validateTransition(app('Entrevista_Tecnica'), 'Proposta', { score: 7 }).ok, false);
});

test('C4/C7/C11: e-mail normalizado, slug unico, anonimizacao', () => {
  assert.equal(R.normalizeEmail('  Ana.Souza @Mail.COM '), 'ana.souza@mail.com');
  assert.equal(R.uniqueSlug('Analista de Vendas Pleno', []), 'analista-de-vendas-pleno');
  assert.equal(R.uniqueSlug('Analista de Vendas Pleno', ['analista-de-vendas-pleno']), 'analista-de-vendas-pleno-2');
  assert.equal(R.uniqueSlug('Operações & Logística (SP)', []), 'operacoes-logistica-sp');
  const cand = { id: 'C-1', anonymized: false, lastActivity: '2026-01-01' };
  assert.equal(R.shouldAnonymize(cand, [{ candidateId: 'C-1', stage: 'Reprovado' }], '2026-10-26', 180), true);
  assert.equal(R.shouldAnonymize(cand, [{ candidateId: 'C-1', stage: 'Contratado' }], '2026-10-26', 180), false);
  assert.equal(R.shouldAnonymize(cand, [{ candidateId: 'C-1', stage: 'Triagem' }], '2026-10-26', 180), false);
  assert.equal(R.shouldAnonymize({ ...cand, lastActivity: '2026-09-01' }, [{ candidateId: 'C-1', stage: 'Reprovado' }], '2026-10-26', 180), false);
});

// ---------------------------------------------------------------- portal
function ctx(over) {
  return Object.assign(
    {
      jobs: st.jobs,
      nowMs: 100000,
      minSeconds: 3,
      dailyLimit: 3,
      countToday: () => 0,
      alreadyApplied: () => false
    },
    over || {}
  );
}
const form = (over) => Object.assign({ slug: 'analista-de-vendas-pleno', name: 'Ana Souza', email: 'Ana.Souza@Mail.com', phone: '', city: 'São Paulo', linkedin: '', message: 'Olá', consent: true, website: '', renderedAt: 90000 }, over || {});

test('portal G3: envio valido normaliza o e-mail e remove HTML', () => {
  const r = PT.validateSubmission(form({ message: '<script>x()</script>Olá <b>time</b>' }), ctx());
  assert.equal(r.ok, true);
  assert.equal(r.clean.email, 'ana.souza@mail.com');
  assert.equal(r.clean.message.includes('<'), false);
});

test('portal G3: honeypot responde sucesso falso sem gravar', () => {
  const r = PT.validateSubmission(form({ website: 'http://spam' }), ctx());
  assert.equal(r.ok, true);
  assert.equal(r.silent, true);
  assert.equal(r.clean, undefined);
});

test('portal G3: tempo minimo, limite diario, duplicidade, consentimento, vaga inelegivel', () => {
  assert.equal(PT.validateSubmission(form({ renderedAt: 99000 }), ctx()).code, 'TEMPO_MINIMO');
  const lim = PT.validateSubmission(form(), ctx({ countToday: () => 3 }));
  assert.equal(lim.message, 'Limite diário de candidaturas atingido.');
  assert.equal(PT.validateSubmission(form(), ctx({ alreadyApplied: () => true })).message, 'Este candidato já se inscreveu nesta vaga.');
  assert.equal(PT.validateSubmission(form({ consent: false }), ctx()).fieldErrors.consent.length > 0, true);
  assert.equal(PT.validateSubmission(form({ email: 'invalido' }), ctx()).fieldErrors.email.length > 0, true);
  assert.equal(PT.validateSubmission(form({ name: 'A' }), ctx()).fieldErrors.name.length > 0, true);
  assert.equal(PT.validateSubmission(form({ slug: 'analista-de-logistica-junior' }), ctx()).code, 'VAGA_INDISPONIVEL'); // nao publicada
  assert.equal(PT.validateSubmission(form({ slug: 'analista-fiscal-senior' }), ctx()).code, 'VAGA_INDISPONIVEL'); // pausada
});

test('portal G1: o DTO nao expoe ids, gestor nem recrutador', () => {
  const job = st.jobs[0];
  const dto = PT.toDto(job, 'Comercial');
  assert.deepEqual(Object.keys(dto).sort(), ['department', 'description', 'employmentType', 'location', 'openedDate', 'requirements', 'slug', 'title', 'workModel']);
  const text = JSON.stringify(dto);
  assert.equal(text.includes('VTR-'), false);
  assert.equal(text.includes('hiringManager'), false);
});

// ---------------------------------------------------------------- promocao e desempenho
test('P2/P6: faixa e salario fora da faixa exigem justificativa', () => {
  const pos = st.positions.P05;
  assert.equal(PR.bandCheck(9000, pos).status, 'within');
  assert.equal(PR.bandCheck(7000, pos).status, 'below');
  assert.equal(PR.bandCheck(13000, pos).status, 'above');
  assert.equal(PR.increasePercent(6400, 8800), 37.5);
  const req = { proposedSalary: 13000 };
  assert.equal(PR.hrDecisionCheck(req, pos, 'Aprovado', '').ok, false);
  assert.equal(PR.hrDecisionCheck(req, pos, 'Aprovado', 'Retenção estratégica').ok, true);
  assert.equal(PR.hrDecisionCheck({ proposedSalary: null }, pos, 'Aprovado', 'x').error, 'Informe o salário proposto antes de aprovar.');
  assert.equal(PR.hrDecisionCheck({ proposedSalary: null }, pos, 'Rejeitado', 'x').ok, true);
});

test('A3/A4/A5: regras da avaliacao de desempenho', () => {
  assert.equal(PF.weightSum([{ weight: 40, status: 'Ativa' }, { weight: 30, status: 'Ativa' }, { weight: 30, status: 'Cancelada' }]), 70);
  assert.equal(PF.validateSelfSubmit([{ weight: 40, status: 'Ativa' }], { rating: 4 }).length, 1);
  assert.equal(PF.validateSelfSubmit([{ weight: 100, status: 'Ativa' }], { rating: 6 }).length, 1);
  assert.equal(PF.validateSelfSubmit([{ weight: 100, status: 'Ativa' }], { rating: 5 }).length, 0);
  assert.equal(PF.canEditSelf('Avaliacao_Gestor', null, 'a', 'a').ok, false);
  assert.equal(PF.canEditSelf('Autoavaliacao', null, 'b', 'a').ok, false);
  assert.equal(PF.canEditSelf('Autoavaliacao', { submitted: true }, 'a', 'a').ok, false);
  assert.equal(PF.canEditManagerReview('Avaliacao_Gestor', { reviewer: 'x', status: 'Pendente' }, 'y').ok, false);
  assert.equal(PF.finalRating({ managerRating: 3, calibrated: 4 }), 4);
  assert.equal(PF.finalRating({ managerRating: 3, calibrated: null }), 3);
});
