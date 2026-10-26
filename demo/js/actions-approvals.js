/* RH Core demo: decisao e cancelamento de solicitacoes (ApprovalService.decide/cancel). Sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./queries.js');
    require('./rules-approval.js');
    require('./rules-promotion.js');
    require('./actions-promotion.js');
  }
  var RH = (g.RH = g.RH || {});
  RH.actions = RH.actions || {};

  function findReq(st, kind, id) {
    var list = kind === 'Leave' ? st.leaveRequests : st.promotions;
    return list.filter(function (r) { return r.id === id; })[0] || null;
  }

  /** decision: 'Aprovado' ou 'Rejeitado'. A etapa do RH de uma promocao exige salario proposto (P6). */
  function decide(st, actor, kind, id, decision, comment) {
    var req = findReq(st, kind, id);
    if (!req) return { ok: false, error: 'Solicitação não encontrada.' };
    if (!RH.approval.canDecide(req, actor)) return { ok: false, error: 'Você não é o aprovador desta etapa.' };
    var step = RH.approval.currentStepOf(req);
    if (kind === 'Promotion' && step.type === 'HR_Team') {
      var chk = RH.promotion.hrDecisionCheck(req, st.positions[req.newPos], decision, comment);
      if (!chk.ok) return chk;
    }
    var res = RH.approval.decide(req, actor, decision, comment, st.today);
    if (!res.ok) return res;
    if (kind === 'Promotion') {
      if (step.type === 'HR_Team') req.hrComment = (comment || '').trim();
      if (res.outcome === 'approved') RH.actions.promotion.onApproved(st, id);
    }
    return { ok: true, outcome: res.outcome, request: req };
  }

  function cancel(st, actor, kind, id) {
    var req = findReq(st, kind, id);
    if (!req) return { ok: false, error: 'Solicitação não encontrada.' };
    return RH.approval.cancel(req, actor);
  }

  /** Atalho de demonstracao: decide como o aprovador de uma etapa que nao e uma das personas. */
  function simulateAs(st, kind, id, decision, comment) {
    var req = findReq(st, kind, id);
    if (!req) return { ok: false, error: 'Solicitação não encontrada.' };
    var step = RH.approval.currentStepOf(req);
    if (!step || step.type === 'HR_Team') return { ok: false, error: 'Esta etapa é do RH. Troque para a persona RH.' };
    return decide(st, { persona: 'sim', role: 'employee', empNum: step.approver }, kind, id, decision, comment);
  }

  RH.actions.approvals = { findReq: findReq, decide: decide, cancel: cancel, simulateAs: simulateAs };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.actions.approvals;
})(globalThis);
