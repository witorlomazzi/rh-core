/* Fluxos de ponta a ponta sobre o estado compartilhado (sem DOM), como a interface os usa. */
const test = require('node:test');
const assert = require('node:assert/strict');
['util', 'rules-leave', 'rules-approval', 'rules-recruiting', 'rules-portal', 'rules-promotion', 'rules-performance', 'rules-visibility', 'data', 'queries', 'actions-leave', 'actions-promotion', 'actions-approvals', 'actions-recruiting', 'actions-performance', 'actions-onboarding'].forEach((m) => require('../js/' + m + '.js'));
const RH = globalThis.RH;
const { leave: AL, approvals: AA, promotion: AP, recruiting: AR, performance: AF, onboarding: AO } = RH.actions;
const act = (p) => RH.visibility.actorFor(p);
const fresh = () => RH.seed.build();

// ---------------------------------------------------------------- ferias
test('ferias: colaborador envia, gestor aprova, RH aprova; saldo e visibilidade corretos', () => {
  const st = fresh();
  const carol = act('colaborador');
  const input = { empNum: 'VTR-0015', periodKey: 'VTR-0015|2025-03-01', start: '2026-12-14', days: 14, sold: 0 };
  const ev = AL.evaluate(st, carol, input);
  assert.equal(ev.summary.canSubmit, true);
  assert.equal(ev.results.find((r) => r.code === 'CONFLITO_EQUIPE').status, 'warning'); // Lucas tem ferias no mesmo intervalo
  const sub = AL.submit(st, carol, input);
  assert.equal(sub.ok, true);
  const id = sub.request.id;
  assert.equal(sub.request.status, 'Pendente');
  assert.equal(sub.request.step, 1);
  assert.match(sub.request.conflict, /Lucas Andrade/);
  // aprovador errado
  assert.equal(AA.decide(st, carol, 'Leave', id, 'Aprovado', '').error, 'Você não é o aprovador desta etapa.');
  assert.equal(AA.decide(st, act('rh'), 'Leave', id, 'Aprovado', '').ok, false);
  // caixa de aprovacoes do gestor
  const box = RH.q.inbox(st, act('gestor')).filter((i) => i.canDecide).map((i) => i.req.id);
  assert.ok(box.includes(id));
  assert.equal(AA.decide(st, act('gestor'), 'Leave', id, 'Aprovado', 'ok').outcome, 'advanced');
  assert.equal(AA.decide(st, act('rh'), 'Leave', id, 'Aprovado', '').outcome, 'approved');
  const p = RH.q.periodsOf(st, 'VTR-0015').find((x) => x.period.key === input.periodKey);
  assert.equal(p.bal.balance, 16);
  assert.equal(p.status, 'Disponivel');
  // outro colaborador nao enxerga o pedido; gestor da equipe sim
  assert.equal(AL.visibleRequests(st, act('gestor')).some((r) => r.id === id), true);
  const other = { persona: 'recrutador', role: 'recruiter', empNum: 'VTR-0032' };
  assert.equal(AL.visibleRequests(st, other).some((r) => r.id === id), false);
});

test('ferias: pedido com bloqueio nao e enviado; rejeicao encerra', () => {
  const st = fresh();
  const carol = act('colaborador');
  const bad = AL.submit(st, carol, { empNum: 'VTR-0015', periodKey: 'VTR-0015|2025-03-01', start: '2026-11-27', days: 14, sold: 0 }); // sexta-feira
  assert.equal(bad.ok, false);
  assert.ok(bad.results.some((r) => r.code === 'INICIO_ANTES_DESCANSO' && r.status === 'blocking'));
  const ok = AL.submit(st, carol, { empNum: 'VTR-0015', periodKey: 'VTR-0015|2025-03-01', start: '2026-12-01', days: 14, sold: 0 });
  assert.equal(ok.ok, true);
  assert.equal(AA.decide(st, act('gestor'), 'Leave', ok.request.id, 'Rejeitado', '').error, 'Informe um comentário para rejeitar.');
  assert.equal(AA.decide(st, act('gestor'), 'Leave', ok.request.id, 'Rejeitado', 'Fechamento do mês').outcome, 'rejected');
  assert.equal(ok.request.status, 'Rejeitado');
  assert.equal(RH.q.periodsOf(st, 'VTR-0015').find((x) => x.period.key === 'VTR-0015|2025-03-01').bal.balance, 30);
});

test('ferias: colaborador nao solicita por outro; RH pode usar excecao de antecedencia', () => {
  const st = fresh();
  const input = { empNum: 'VTR-0016', periodKey: 'VTR-0016|2025-06-15', start: '2026-11-02', days: 5, sold: 0 };
  assert.equal(AL.evaluate(st, act('colaborador'), input).ok, false);
  const hr = act('rh');
  assert.equal(AL.evaluate(st, hr, input).results.find((r) => r.code === 'ANTECEDENCIA').status, 'blocking');
  assert.equal(AL.evaluate(st, hr, { ...input, allowNoticeException: true }).results.find((r) => r.code === 'ANTECEDENCIA').status, 'warning');
  // a excecao e ignorada para quem nao e RH
  assert.equal(AL.evaluate(st, act('colaborador'), { ...input, empNum: 'VTR-0015', periodKey: 'VTR-0015|2025-03-01', allowNoticeException: true }).results.find((r) => r.code === 'ANTECEDENCIA').status, 'blocking');
});

test('ferias: periodo perdido e periodo em aquisicao nao aceitam pedido', () => {
  const st = fresh();
  const rh = act('rh');
  const lost = AL.evaluate(st, rh, { empNum: 'VTR-0024', periodKey: 'VTR-0024|2025-05-09', start: '2027-02-01', days: 14 });
  assert.equal(lost.ok, false);
  const acq = AL.evaluate(st, act('colaborador'), { empNum: 'VTR-0015', periodKey: 'VTR-0015|2026-03-01', start: '2026-12-14', days: 14 });
  assert.equal(acq.results.find((r) => r.code === 'PERIODO_NAO_ADQUIRIDO').status, 'blocking');
});

test('ferias: rotina diaria muda status e o do colaborador', () => {
  const st = fresh();
  st.today = '2026-11-03';
  AL.runStatusBatch(st);
  assert.equal(st.leaveRequests.find((r) => r.id === 'FE-000004').status, 'Concluido');
  assert.equal(RH.q.emp(st, 'VTR-0018').status, 'Ativo');
});

// ---------------------------------------------------------------- promocoes
test('promocao: P1, P3, P4 e fluxo completo ate a efetivacao', () => {
  const st = fresh();
  const gestor = act('gestor');
  const base = { subjectNum: 'VTR-0016', proposedPos: 'P05', effective: '2026-12-01', justification: 'Entregas acima da meta.' };
  assert.equal(AP.create(st, gestor, { ...base, subjectNum: 'VTR-0019' }).error, 'Você só pode solicitar promoção para alguém da sua equipe.');
  assert.equal(AP.create(st, gestor, { ...base, effective: '2026-10-01' }).error, 'A data de efetivação não pode estar no passado.');
  assert.equal(AP.create(st, act('colaborador'), base).ok, false);
  const r = AP.create(st, gestor, base);
  assert.equal(r.ok, true);
  assert.equal(r.request.curSalary, 6900); // snapshot
  assert.equal(r.warnings.length, 0); // P05 e o proximo de P04
  assert.equal(AP.create(st, gestor, base).error, 'Este colaborador já possui uma solicitação de promoção pendente.');
  // etapa 1: gestor de 2o nivel (Rodrigo), simulado
  assert.equal(AA.decide(st, gestor, 'Promotion', r.request.id, 'Aprovado', '').ok, false);
  assert.equal(AA.simulateAs(st, 'Promotion', r.request.id, 'Aprovado', '').outcome, 'advanced');
  // etapa 2: RH precisa do salario proposto
  const rh = act('rh');
  assert.equal(AA.decide(st, rh, 'Promotion', r.request.id, 'Aprovado', '').error, 'Informe o salário proposto antes de aprovar.');
  AP.setProposedSalary(st, rh, r.request.id, 13500);
  assert.match(AA.decide(st, rh, 'Promotion', r.request.id, 'Aprovado', '').error, /fora da faixa/);
  AP.setProposedSalary(st, rh, r.request.id, 9000);
  assert.equal(AA.decide(st, rh, 'Promotion', r.request.id, 'Aprovado', '').outcome, 'approved');
  assert.equal(r.request.status, 'Aprovado'); // data futura
  st.today = '2026-12-01';
  AP.runEffectivationBatch(st);
  assert.equal(r.request.status, 'Efetivado');
  const e = RH.q.emp(st, 'VTR-0016');
  assert.equal(e.pos, 'P05');
  assert.equal(e.salary, 9000);
  const hist = st.positionHistory.filter((h) => h.empNum === 'VTR-0016');
  assert.equal(hist.filter((h) => !h.end).length, 1);
  assert.equal(hist.find((h) => h.pos === 'P04').end, '2026-11-30');
});

test('promocao: data de hoje efetiva na hora; fora da trilha gera aviso', () => {
  const st = fresh();
  const gestor = act('gestor');
  const r = AP.create(st, gestor, { subjectNum: 'VTR-0018', proposedPos: 'P04', effective: '2026-10-26', justification: 'Acelerar a carreira.' });
  assert.equal(r.ok, true);
  assert.deepEqual(r.warnings, ['Promoção fora da trilha prevista.']);
  AA.simulateAs(st, 'Promotion', r.request.id, 'Aprovado', '');
  AP.setProposedSalary(st, act('rh'), r.request.id, 6000);
  AA.decide(st, act('rh'), 'Promotion', r.request.id, 'Aprovado', '');
  assert.equal(r.request.status, 'Efetivado');
});

// ---------------------------------------------------------------- recrutamento
test('recrutamento: mover etapa grava historico, dias na etapa e exige nota/motivo', () => {
  const st = fresh();
  const rec = act('recrutador');
  assert.equal(AR.move(st, rec, 'A-008', 'Proposta').error, 'Mudança de etapa não permitida: de Nova para Proposta.');
  const m = AR.move(st, rec, 'A-006', 'Entrevista_RH');
  assert.equal(m.ok, true);
  const h = st.stageHistory.filter((x) => x.appId === 'A-006').pop();
  assert.equal(h.from, 'Triagem');
  assert.equal(h.to, 'Entrevista_RH');
  assert.equal(h.daysInPrev, 11); // entrou na triagem em 15/10
  assert.deepEqual(AR.move(st, rec, 'A-007', 'Reprovado').needs, ['reason']);
  assert.equal(AR.move(st, rec, 'A-007', 'Reprovado', { reason: 'Perfil' }).ok, true);
  assert.deepEqual(AR.move(st, rec, 'A-003', 'Proposta').needs, ['score']);
  assert.equal(AR.move(st, rec, 'A-003', 'Proposta', { score: 4 }).ok, true);
  assert.equal(RH.q.candidateById(st, 'C-02').lastActivity, '2026-10-26');
});

test('recrutamento: gestor contratante ve so as proprias vagas e so move entrevistas', () => {
  const st = fresh();
  const g = act('gestor'); // Patricia: gestora da JOB-1
  const visible = AR.visibleApplications(st, g);
  assert.ok(visible.length > 0);
  assert.ok(visible.every((a) => a.jobId === 'JOB-1'));
  assert.equal(AR.move(st, g, 'A-013', 'Entrevista_Tecnica').error, 'Você não tem acesso a esta candidatura.'); // JOB-2
  assert.match(AR.move(st, g, 'A-008', 'Triagem').error, /apenas candidaturas em etapas de entrevista/);
  assert.equal(AR.move(st, g, 'A-005', 'Entrevista_Tecnica').ok, true);
  assert.equal(AR.visibleApplications(st, act('colaborador')).length, 0); // colaborador comum nao ve candidato
});

test('recrutamento: Contratado cria colaborador em pre-admissao e plano com 8 tarefas, de forma idempotente', () => {
  const st = fresh();
  const rec = act('recrutador');
  const before = st.employees.length;
  const m = AR.move(st, rec, 'A-002', 'Contratado');
  assert.equal(m.ok, true);
  assert.equal(m.hired.created, true);
  assert.equal(st.employees.length, before + 1);
  const e = RH.q.emp(st, m.hired.employeeNum);
  assert.equal(e.status, 'Pre_Admissao');
  assert.equal(e.mgr, 'VTR-0007');
  const plan = RH.q.planOf(st, e.num);
  assert.equal(plan.tasks.length, 8);
  assert.equal(plan.tasks[0].due, RH.util.addDays(e.hire, -10));
  assert.equal(AR.move(st, rec, 'A-002', 'Contratado').ok, false); // terminal
});

test('recrutamento: fechar a vaga reprova as candidaturas abertas (C6) e a retencao LGPD anonimiza (C11)', () => {
  const st = fresh();
  const rec = act('recrutador');
  const open = st.applications.filter((a) => a.jobId === 'JOB-3' && !RH.recruiting.stage(a.stage).terminal).length;
  const r = AR.closeJob(st, rec, 'JOB-3', 'Cancelada');
  assert.equal(r.rejected, open);
  assert.ok(st.applications.filter((a) => a.jobId === 'JOB-3').every((a) => RH.recruiting.stage(a.stage).terminal));
  assert.ok(st.stageHistory.some((h) => h.note === 'Vaga encerrada'));
  assert.equal(AR.closeJob(st, act('colaborador'), 'JOB-1', 'Fechada').ok, false);
  const ret = AR.runRetention(st, rec);
  assert.equal(ret.count, 2); // C-20 e C-25 estao parados ha mais de 180 dias
  const c = RH.q.candidateById(st, 'C-25');
  assert.equal(c.name, 'Candidato anonimizado');
  assert.equal(c.email, 'anon-C-25@anon.invalid');
  assert.equal(c.anonymized, true);
  assert.equal(RH.q.candidateById(st, 'C-03').anonymized, false); // contratado nunca
  assert.equal(AR.runRetention(st, rec).count, 0); // idempotente
});

// ---------------------------------------------------------------- portal
test('portal: candidatura publica aparece no funil do recrutador; mesmo candidato e reaproveitado', () => {
  const st = fresh();
  const now = Date.now();
  const f = { slug: 'analista-de-vendas-pleno', name: 'Nina Albuquerque', email: 'Nina@Mail.example', phone: '', city: 'Santos', linkedin: '', message: 'Quero contribuir.', consent: true, website: '', renderedAt: now - 20000 };
  const r = AR.portalSubmit(st, f, now);
  assert.equal(r.ok, true);
  const app = r.application;
  assert.equal(app.stage, 'Nova');
  assert.equal(app.source, 'Portal');
  assert.ok(AR.visibleApplications(st, act('recrutador')).some((a) => a.id === app.id));
  const cand = RH.q.candidateById(st, app.candidateId);
  assert.equal(cand.emailNorm, 'nina@mail.example');
  assert.equal(cand.consent, true);
  assert.equal(cand.consentVersion, '2026-10');
  // duplicada
  assert.equal(AR.portalSubmit(st, f, now).message, 'Este candidato já se inscreveu nesta vaga.');
  // mesmo e-mail em outra vaga reaproveita o candidato (C4)
  const total = st.candidates.length;
  const r2 = AR.portalSubmit(st, { ...f, slug: 'analista-de-sistemas-pleno-salesforce' }, now);
  assert.equal(r2.ok, true);
  assert.equal(st.candidates.length, total);
});

test('portal: honeypot, tempo minimo e limite diario nao gravam nada', () => {
  const st = fresh();
  const now = Date.now();
  const f = { slug: 'analista-de-vendas-pleno', name: 'Robô', email: 'bot@mail.example', phone: '', city: '', linkedin: '', message: '', consent: true, website: 'http://x', renderedAt: now - 20000 };
  const apps = st.applications.length;
  const hp = AR.portalSubmit(st, f, now);
  assert.equal(hp.ok, true);
  assert.equal(hp.silent, true);
  assert.equal(st.applications.length, apps);
  assert.equal(AR.portalSubmit(st, { ...f, website: '', renderedAt: now - 500 }, now).code, 'TEMPO_MINIMO');
  st.portal.boost['bot@mail.example'] = 3;
  assert.equal(AR.portalSubmit(st, { ...f, website: '', renderedAt: now - 20000 }, now).message, 'Limite diário de candidaturas atingido.');
  assert.equal(st.applications.length, apps);
  assert.equal(st.portal.log.length, 3);
  assert.equal(AR.portalJobs(st).length, 2);
});

// ---------------------------------------------------------------- desempenho
test('desempenho: ciclo completo, colaborador so le depois de liberar', () => {
  const st = fresh();
  const carol = act('colaborador');
  const gestor = act('gestor');
  const rh = act('rh');
  // A4: Carolina tem metas somando 70%
  assert.match(AF.saveSelf(st, carol, 'VTR-0015', { rating: 4, strengths: 'a', improvements: 'b' }, true).error, /100%/);
  assert.equal(AF.addGoal(st, carol, 'VTR-0015', { name: 'Treinar a equipe', weight: 30 }).ok, true);
  assert.equal(AF.saveSelf(st, carol, 'VTR-0015', { rating: 4, strengths: 'a', improvements: 'b' }, true).ok, true);
  assert.match(AF.saveSelf(st, carol, 'VTR-0015', { rating: 5 }, true).error, /já foi enviada/); // A3
  assert.match(AF.addGoal(st, carol, 'VTR-0015', { name: 'x', weight: 10 }).error, /travadas/);
  assert.equal(AF.saveSelf(st, gestor, 'VTR-0015', { rating: 5 }, false).ok, false); // so o proprio colaborador
  // A5: gestor so avalia na fase certa
  assert.match(AF.saveManagerReview(st, gestor, 'VTR-0015', { rating: 4 }, true).error, /fase de avaliação do gestor/);
  assert.equal(AF.advancePhase(st, gestor).ok, false);
  assert.equal(AF.advancePhase(st, rh).status, 'Avaliacao_Gestor');
  assert.equal(AF.saveManagerReview(st, carol, 'VTR-0015', { rating: 4 }, true).ok, false); // nao e o avaliador
  assert.equal(AF.saveManagerReview(st, gestor, 'VTR-0015', { rating: 4, comments: 'Muito bom' }, true).ok, true);
  assert.equal(AF.canReadReview(st, carol, 'VTR-0015'), false);
  assert.equal(AF.advancePhase(st, rh).status, 'Calibracao');
  assert.match(AF.calibrate(st, rh, 'VTR-0016', 4).error, /ainda não foi enviada/);
  assert.equal(AF.calibrate(st, gestor, 'VTR-0015', 5).ok, false);
  assert.equal(AF.calibrate(st, rh, 'VTR-0015', 5).ok, true);
  assert.equal(AF.canReadReview(st, carol, 'VTR-0015'), false); // ainda nao liberada
  const rel = AF.release(st, rh);
  assert.equal(rel.released, 1);
  assert.equal(st.cycle.status, 'Concluido');
  assert.equal(AF.canReadReview(st, carol, 'VTR-0015'), true);
  assert.equal(RH.performance.finalRating(st.reviews['VTR-0015']), 5);
  assert.equal(AF.canReadReview(st, act('recrutador'), 'VTR-0015'), false);
});

// ---------------------------------------------------------------- onboarding
test('onboarding: so o responsavel ou o RH conclui; ativacao valida matricula e recalcula datas', () => {
  const st = fresh();
  const plan = st.onboardingPlans[0];
  const rhTask = plan.tasks.find((t) => t.role === 'RH');
  const gTask = plan.tasks.find((t) => t.role === 'Gestor');
  assert.equal(AO.setTask(st, act('gestor'), plan.id, rhTask.id, true).error, 'Somente o responsável pela tarefa ou o RH pode concluí-la.');
  assert.equal(AO.setTask(st, act('gestor'), plan.id, gTask.id, true).ok, true);
  assert.equal(AO.setTask(st, act('rh'), plan.id, rhTask.id, true).ok, true);
  assert.equal(AO.progress(plan).done, 3);
  assert.equal(AO.activate(st, act('gestor'), { empNum: 'PRE-000001', number: 'VTR-0041', hireDate: '2026-11-16' }).ok, false);
  assert.equal(AO.activate(st, act('rh'), { empNum: 'PRE-000001', number: 'VTR-0001', hireDate: '2026-11-16' }).error, 'Esta matrícula já está em uso.');
  const a = AO.activate(st, act('rh'), { empNum: 'PRE-000001', number: 'VTR-0041', hireDate: '2026-11-16', salary: 7000 });
  assert.equal(a.ok, true);
  assert.equal(plan.status, 'Em_Andamento');
  assert.equal(plan.empNum, 'VTR-0041');
  const pend = plan.tasks.filter((t) => t.status === 'Pendente' && t.role === 'Gestor' && t.order === 5)[0];
  assert.equal(pend.due, '2026-11-16'); // reuniao de boas-vindas no dia da admissao (O6)
  assert.equal(RH.q.emp(st, 'VTR-0041').status, 'Ativo');
  assert.ok(st.positionHistory.some((h) => h.empNum === 'VTR-0041' && h.reason === 'Admissao'));
  assert.ok(plan.tasks.find((t) => t.role === 'Colaborador').assigned === 'VTR-0041');
});
