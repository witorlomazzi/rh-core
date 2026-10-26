const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../js/rules-leave.js');

const TODAY = '2026-01-12'; // segunda-feira
const period = { key: 'X|2025-01-01', start: '2025-01-01', end: '2025-12-31', concessionDeadline: '2026-12-31', entitled: 30 };
const holidaySet = { '2026-04-21': 'Tiradentes', '2026-05-01': 'Dia do Trabalho' };

function run(request, existing = [], extra = {}) {
  return L.evaluate({ period, existing, employeeRequests: existing, request, today: TODAY, settings: L.DEFAULT_SETTINGS, holidaySet, teamLeaves: [], ...extra });
}
const get = (res, code) => res.find((r) => r.code === code);
const frac = (start, days, sold = 0, status = 'Aprovado') => ({ start, days, sold, status });

test('14+10+6 e valido, fracao a fracao', () => {
  const r1 = frac('2026-03-02', 14);
  const r2 = frac('2026-04-06', 10);
  assert.equal(L.summarize(run({ start: '2026-03-02', days: 14 })).canSubmit, true);
  assert.equal(L.summarize(run({ start: '2026-04-06', days: 10 }, [r1])).canSubmit, true);
  assert.equal(L.summarize(run({ start: '2026-05-04', days: 6 }, [r1, r2])).canSubmit, true);
});

test('5+5+20 e valido', () => {
  const r1 = frac('2026-03-02', 5);
  const r2 = frac('2026-04-06', 5);
  assert.equal(L.summarize(run({ start: '2026-03-02', days: 5 })).canSubmit, true);
  assert.equal(L.summarize(run({ start: '2026-04-06', days: 5 }, [r1])).canSubmit, true);
  assert.equal(L.summarize(run({ start: '2026-05-04', days: 20 }, [r1, r2])).canSubmit, true);
});

test('5+5+5 e invalido (V7 PERIODO_PRINCIPAL)', () => {
  const r1 = frac('2026-03-02', 5);
  const r2 = frac('2026-04-06', 5);
  const res = run({ start: '2026-05-04', days: 5 }, [r1, r2]);
  assert.equal(get(res, 'PERIODO_PRINCIPAL').status, 'blocking');
});

test('V7 bloqueia quando o saldo restante nao permite mais uma fracao de 14 dias', () => {
  const r1 = frac('2026-03-02', 10);
  const res = run({ start: '2026-04-06', days: 10 }, [r1]); // restariam 10, sem fracao principal
  assert.equal(get(res, 'PERIODO_PRINCIPAL').status, 'blocking');
});

test('V6: fracao de 4 dias e invalida', () => {
  assert.equal(get(run({ start: '2026-03-02', days: 4 }), 'MINIMO_FRACAO').status, 'blocking');
  assert.equal(get(run({ start: '2026-03-02', days: 5 }), 'MINIMO_FRACAO').status, 'ok');
});

test('V5: quarta fracao e bloqueada', () => {
  const ex = [frac('2026-03-02', 14), frac('2026-04-06', 5), frac('2026-05-04', 5)];
  assert.equal(get(run({ start: '2026-06-01', days: 5 }, ex), 'QUANTIDADE_PERIODOS').status, 'blocking');
});

test('V4: inicio na sexta com descanso no domingo e invalido; sabado tambem', () => {
  assert.equal(get(run({ start: '2026-03-06', days: 14 }), 'INICIO_ANTES_DESCANSO').status, 'blocking'); // sexta
  assert.equal(get(run({ start: '2026-03-07', days: 14 }), 'INICIO_ANTES_DESCANSO').status, 'blocking'); // sabado
  assert.equal(get(run({ start: '2026-03-05', days: 14 }), 'INICIO_ANTES_DESCANSO').status, 'ok'); // quinta
});

test('V4: vespera de feriado e invalida', () => {
  const res = run({ start: '2026-04-20', days: 14 }); // segunda, feriado na terca
  assert.equal(get(res, 'INICIO_ANTES_DESCANSO').status, 'blocking');
  assert.match(get(res, 'INICIO_ANTES_DESCANSO').message, /Tiradentes/);
});

test('V8: abono de 11 dias em 30 e invalido; 10 e valido', () => {
  assert.equal(get(run({ start: '2026-03-02', days: 14, sold: 11 }), 'ABONO_LIMITE').status, 'blocking');
  assert.equal(get(run({ start: '2026-03-02', days: 14, sold: 10 }), 'ABONO_LIMITE').status, 'ok');
});

test('V8 soma o abono ja vendido no periodo', () => {
  const ex = [frac('2026-03-02', 14, 6)];
  assert.equal(get(run({ start: '2026-04-06', days: 6, sold: 5 }, ex), 'ABONO_LIMITE').status, 'blocking');
});

test('V9: abono fora do prazo e aviso, nao bloqueio', () => {
  const r = get(run({ start: '2026-03-02', days: 14, sold: 5 }), 'ABONO_PRAZO');
  assert.equal(r.status, 'warning');
  assert.equal(r.blocking, false);
  assert.match(r.message, /concordância da empresa/);
});

test('V1: periodo ainda em aquisicao e bloqueante', () => {
  const p2 = { ...period, end: '2026-12-31' };
  const res = L.evaluate({ period: p2, existing: [], employeeRequests: [], request: { start: '2026-03-02', days: 14 }, today: TODAY, settings: L.DEFAULT_SETTINGS, holidaySet, teamLeaves: [] });
  assert.equal(get(res, 'PERIODO_NAO_ADQUIRIDO').status, 'blocking');
});

test('V2: saldo insuficiente', () => {
  const ex = [frac('2026-03-02', 20)];
  assert.equal(get(run({ start: '2026-05-04', days: 14 }, ex), 'SALDO_INSUFICIENTE').status, 'blocking');
  assert.equal(get(run({ start: '2026-05-04', days: 10 }, ex), 'SALDO_INSUFICIENTE').status, 'ok');
});

test('V3: antecedencia menor que 30 dias bloqueia; excecao do RH vira aviso', () => {
  const blocked = get(run({ start: '2026-02-02', days: 14 }), 'ANTECEDENCIA');
  assert.equal(blocked.status, 'blocking');
  const allowed = get(run({ start: '2026-02-02', days: 14 }, [], { allowNoticeException: true }), 'ANTECEDENCIA');
  assert.equal(allowed.status, 'warning');
  assert.equal(get(run({ start: '2026-02-11', days: 14 }), 'ANTECEDENCIA').status, 'ok'); // exatamente 30 dias
});

test('V10: gozo depois do prazo concessivo e aviso de pagamento em dobro', () => {
  const p2 = { ...period, concessionDeadline: '2026-03-10' };
  const res = L.evaluate({ period: p2, existing: [], employeeRequests: [], request: { start: '2026-03-02', days: 14 }, today: TODAY, settings: L.DEFAULT_SETTINGS, holidaySet, teamLeaves: [] });
  const v = get(res, 'PRAZO_CONCESSIVO');
  assert.equal(v.status, 'warning');
  assert.match(v.message, /em dobro \(art\. 137/);
});

test('V11: sobreposicao com outro pedido do colaborador bloqueia (qualquer periodo)', () => {
  const other = [{ start: '2026-03-09', days: 10, sold: 0, status: 'Pendente' }];
  const res = L.evaluate({ period, existing: [], employeeRequests: other, request: { start: '2026-03-02', days: 14 }, today: TODAY, settings: L.DEFAULT_SETTINGS, holidaySet, teamLeaves: [] });
  assert.equal(get(res, 'SOBREPOSICAO').status, 'blocking');
  const cancelled = [{ start: '2026-03-09', days: 10, sold: 0, status: 'Cancelado' }];
  const ok = L.evaluate({ period, existing: [], employeeRequests: cancelled, request: { start: '2026-03-02', days: 14 }, today: TODAY, settings: L.DEFAULT_SETTINGS, holidaySet, teamLeaves: [] });
  assert.equal(get(ok, 'SOBREPOSICAO').status, 'ok');
});

test('V12: conflito de equipe e aviso nao bloqueante', () => {
  const res = run({ start: '2026-03-02', days: 14 }, [], { teamLeaves: [{ name: 'Lucas Andrade', start: '2026-03-09', end: '2026-03-20' }] });
  const v = get(res, 'CONFLITO_EQUIPE');
  assert.equal(v.status, 'warning');
  assert.match(v.message, /Lucas Andrade/);
  assert.equal(L.summarize(res).canSubmit, true);
});

test('dados invalidos retornam um unico bloqueio', () => {
  const res = run({ start: '', days: 0 });
  assert.equal(res.length, 1);
  assert.equal(res[0].code, 'DADOS_INVALIDOS');
});

test('R3: tabela do art. 130', () => {
  assert.deepEqual(L.entitledDays(0), { days: 30, lost: false });
  assert.deepEqual(L.entitledDays(5), { days: 30, lost: false });
  assert.deepEqual(L.entitledDays(10), { days: 24, lost: false });
  assert.deepEqual(L.entitledDays(16), { days: 18, lost: false });
  assert.deepEqual(L.entitledDays(32), { days: 12, lost: false });
  assert.deepEqual(L.entitledDays(33), { days: 0, lost: true });
});

test('R1/R2: periodos aquisitivos e prazo concessivo', () => {
  const emp = { num: 'T-1', hire: '2023-12-01', type: 'CLT', status: 'Ativo', absences: { '2024-12-01': 10 } };
  const ps = L.buildPeriods(emp, { today: '2026-10-26', requests: [{ periodKey: 'T-1|2024-12-01' }, { periodKey: 'T-1|2025-12-01' }] });
  assert.equal(ps.length, 3);
  assert.equal(ps[0].start, '2023-12-01');
  assert.equal(ps[0].end, '2024-11-30');
  assert.equal(ps[0].concessionDeadline, '2025-11-30');
  assert.equal(ps[1].entitled, 24); // 10 faltas
  assert.equal(L.buildPeriods({ ...emp, type: 'Estagio' }, { today: '2026-10-26' }).length, 0);
  assert.equal(L.buildPeriods({ ...emp, status: 'Desligado' }, { today: '2026-10-26' }).length, 0);
});

test('R3/R4: 33 faltas perde o periodo; status por prazo', () => {
  const emp = { num: 'T-2', hire: '2024-01-08', type: 'CLT', status: 'Ativo', absences: { '2024-01-08': 33 } };
  const [p1, p2] = L.buildPeriods(emp, { today: '2026-10-26', requests: [{ periodKey: 'T-2|2025-01-08' }] });
  assert.equal(p1.lost, true);
  assert.equal(L.periodStatus(p1, L.balanceOf(p1, []), '2026-10-26'), 'Perdido');
  assert.equal(p2.start, '2025-01-08');
  // concessivo acaba em 2027-01-07: faltam 73 dias, saldo cheio -> Disponivel; perto do prazo -> Prazo_Proximo
  assert.equal(L.periodStatus(p2, L.balanceOf(p2, []), '2026-10-26'), 'Disponivel');
  assert.equal(L.periodStatus(p2, L.balanceOf(p2, []), '2026-11-20'), 'Prazo_Proximo');
  assert.equal(L.periodStatus(p2, L.balanceOf(p2, []), '2026-01-01'), 'Em_Aquisicao');
});

test('roll-ups: saldo desconta aprovado, pendente e abono', () => {
  const emp = { num: 'T-3', hire: '2024-01-08', type: 'CLT', status: 'Ativo' };
  const reqs = [
    { periodKey: 'T-3|2024-01-08', status: 'Aprovado', days: 14, sold: 5 },
    { periodKey: 'T-3|2024-01-08', status: 'Pendente', days: 6, sold: 0 },
    { periodKey: 'T-3|2024-01-08', status: 'Rejeitado', days: 10, sold: 0 },
    { periodKey: 'T-3|2024-01-08', status: 'Cancelado', days: 10, sold: 0 }
  ];
  const [p] = L.buildPeriods(emp, { today: '2026-10-26', requests: reqs });
  assert.deepEqual(L.balanceOf(p, reqs), { taken: 14, sold: 5, pending: 6, balance: 5 });
});
