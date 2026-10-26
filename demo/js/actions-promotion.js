/* RH Core demo: acoes de promocao (PromotionService). Mutam o estado recebido; sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./queries.js');
    require('./rules-approval.js');
    require('./rules-promotion.js');
  }
  var RH = (g.RH = g.RH || {});
  RH.actions = RH.actions || {};
  var U = RH.util;
  var Q = RH.q;
  var P = RH.promotion;

  function find(st, id) {
    return st.promotions.filter(function (p) { return p.id === id; })[0] || null;
  }

  /** P1 a P5: o gestor solicita. O snapshot de cargo e salario e gravado em contexto de sistema. */
  function create(st, actor, input) {
    if (actor.role !== 'manager' && actor.role !== 'hr') return { ok: false, error: 'Somente gestores e RH solicitam promoção.' };
    var idx = Q.index(st);
    var check = P.validateRequest(
      { requesterNum: actor.empNum, subjectNum: input.subjectNum, proposedPos: input.proposedPos, effective: input.effective, justification: input.justification },
      { idx: idx, positions: st.positions, existing: st.promotions },
      st.today
    );
    if (check.errors.length) return { ok: false, error: check.errors[0], errors: check.errors, warnings: check.warnings };
    var subject = idx.byNum[input.subjectNum];
    var s = RH.approval.submit('Promotion', actor.empNum, subject, idx.byNum, st.today);
    var req = {
      id: 'PR-' + U.pad(st.seq.PR++, 6), empNum: subject.num, curPos: subject.pos, newPos: input.proposedPos, curSalary: subject.salary, proposedSalary: null,
      justification: input.justification.trim(), effective: input.effective, status: 'Pendente', step: s.currentStep, requestedBy: actor.empNum, steps: s.steps,
      createdAt: st.today, outOfTrail: check.warnings.length > 0, hrComment: ''
    };
    st.promotions.push(req);
    return { ok: true, request: req, warnings: check.warnings };
  }

  /** O RH informa o salario proposto antes de decidir (P6). */
  function setProposedSalary(st, actor, id, salary) {
    if (actor.role !== 'hr') return { ok: false, error: 'Somente o RH informa o salário proposto.' };
    var r = find(st, id);
    if (!r || r.status !== 'Pendente') return { ok: false, error: 'Solicitação indisponível.' };
    var n = Number(salary);
    if (!(n > 0)) return { ok: false, error: 'Informe um salário válido.' };
    r.proposedSalary = Math.round(n * 100) / 100;
    return { ok: true };
  }

  /** P7 e P8: efetiva imediatamente ou na data. */
  function effectivate(st, id) {
    var r = find(st, id);
    if (!r || r.status !== 'Aprovado') return { ok: false, error: 'Só promoções aprovadas podem ser efetivadas.' };
    var e = Q.emp(st, r.empNum);
    var open = st.positionHistory.filter(function (h) { return h.empNum === e.num && !h.end; })[0];
    if (open) open.end = U.addDays(r.effective, -1);
    e.pos = r.newPos;
    if (r.proposedSalary) e.salary = r.proposedSalary;
    st.positionHistory.push({ empNum: e.num, pos: r.newPos, dept: e.dept, start: r.effective, end: null, salary: e.salary, reason: 'Promocao', promotionId: r.id });
    r.status = 'Efetivado';
    return { ok: true, request: r };
  }

  /** Rotina diaria (PromotionEffectivationBatch). */
  function runEffectivationBatch(st) {
    var n = 0;
    st.promotions.forEach(function (p) {
      if (p.status === 'Aprovado' && p.effective <= st.today) {
        if (effectivate(st, p.id).ok) n++;
      }
    });
    return { ok: true, changed: n };
  }

  /** Depois da aprovacao final: efetiva na hora quando a data ja chegou. */
  function onApproved(st, id) {
    var r = find(st, id);
    if (r && r.effective <= st.today) return effectivate(st, id);
    return { ok: true };
  }

  RH.actions.promotion = { find: find, create: create, setProposedSalary: setProposedSalary, effectivate: effectivate, runEffectivationBatch: runEffectivationBatch, onApproved: onApproved };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.actions.promotion;
})(globalThis);
