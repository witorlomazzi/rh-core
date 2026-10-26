/* RH Core demo: motor de aprovacao em etapas (spec 10, ApprovalService). Puro, sem DOM.
   Configuracao espelha HR_Approval_Step__mdt: Leave 1 Gestor direto, 2 RH; Promotion 1 Gestor de 2o nivel, 2 RH. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) require('./util.js');
  var RH = (g.RH = g.RH || {});

  var STEP_CONFIG = {
    Leave: [
      { order: 1, type: 'Direct_Manager' },
      { order: 2, type: 'HR_Team' }
    ],
    Promotion: [
      { order: 1, type: 'Second_Level_Manager' },
      { order: 2, type: 'HR_Team' }
    ]
  };
  var STEP_LABEL = {
    Direct_Manager: 'Gestor direto',
    Second_Level_Manager: 'Gestor de segundo nível',
    HR_Team: 'Equipe de RH'
  };

  /** Resolve o aprovador (matricula) de uma etapa. RH retorna null (grupo). */
  function resolveApprover(type, subject, byNum) {
    if (type === 'HR_Team') return null;
    var mgr = subject.mgr ? byNum[subject.mgr] : null;
    if (type === 'Direct_Manager') return mgr ? mgr.num : null;
    if (type === 'Second_Level_Manager') {
      if (mgr && mgr.mgr && byNum[mgr.mgr]) return mgr.mgr;
      return mgr ? mgr.num : null;
    }
    return null;
  }

  /**
   * submit: cria as etapas. Se o aprovador e o proprio solicitante ou esta vazio, pula a etapa
   * e registra o motivo. Retorna { steps, currentStep, status }.
   */
  function submit(kind, requesterNum, subject, byNum, now) {
    var steps = STEP_CONFIG[kind].map(function (c) {
      var approver = resolveApprover(c.type, subject, byNum);
      var skip = c.type !== 'HR_Team' && (!approver || approver === requesterNum);
      return {
        order: c.order,
        type: c.type,
        approver: approver,
        status: skip ? 'Cancelado' : 'Pendente',
        skipped: skip,
        decidedBy: null,
        decisionDate: skip ? now : null,
        comments: skip ? 'Etapa pulada: aprovador indisponível' : ''
      };
    });
    var first = steps.filter(function (s) { return !s.skipped; })[0];
    return { steps: steps, currentStep: first ? first.order : 0, status: 'Pendente' };
  }

  function currentStepOf(req) {
    return req.steps.filter(function (s) {
      return s.order === req.step && s.status === 'Pendente';
    })[0];
  }

  /** O ator pode decidir a etapa atual? actor = { empNum, role } com role 'hr' para o grupo HR_Team. */
  function canDecide(req, actor) {
    var st = currentStepOf(req);
    if (!st || req.status !== 'Pendente') return false;
    if (st.type === 'HR_Team') return actor.role === 'hr';
    return st.approver === actor.empNum;
  }

  /**
   * decide: valida o aprovador e aplica. Retorna { ok, error, outcome } onde outcome e
   * 'advanced', 'approved' ou 'rejected'. Muta req (copie antes se precisar).
   */
  function decide(req, actor, decision, comment, now) {
    var st = currentStepOf(req);
    if (!st || req.status !== 'Pendente') return { ok: false, error: 'Esta solicitação não está aguardando decisão.' };
    if (!canDecide(req, actor)) return { ok: false, error: 'Você não é o aprovador desta etapa.' };
    comment = (comment || '').trim();
    if (decision === 'Rejeitado' && !comment) return { ok: false, error: 'Informe um comentário para rejeitar.' };
    st.decidedBy = actor.empNum || 'RH';
    st.decisionDate = now;
    st.comments = comment;
    if (decision === 'Rejeitado') {
      st.status = 'Rejeitado';
      req.steps.forEach(function (s) {
        if (s.status === 'Pendente') s.status = 'Cancelado';
      });
      req.status = 'Rejeitado';
      return { ok: true, outcome: 'rejected' };
    }
    st.status = 'Aprovado';
    var next = req.steps.filter(function (s) {
      return s.order > st.order && s.status === 'Pendente';
    })[0];
    if (next) {
      req.step = next.order;
      return { ok: true, outcome: 'advanced' };
    }
    req.status = 'Aprovado';
    return { ok: true, outcome: 'approved' };
  }

  /** cancel: so o solicitante, so com status Pendente. */
  function cancel(req, actor) {
    if (req.requestedBy !== actor.empNum) return { ok: false, error: 'Só o solicitante pode cancelar.' };
    if (req.status !== 'Pendente') return { ok: false, error: 'Só solicitações pendentes podem ser canceladas.' };
    req.steps.forEach(function (s) {
      if (s.status === 'Pendente') s.status = 'Cancelado';
    });
    req.status = 'Cancelado';
    return { ok: true };
  }

  RH.approval = { STEP_CONFIG: STEP_CONFIG, STEP_LABEL: STEP_LABEL, resolveApprover: resolveApprover, submit: submit, currentStepOf: currentStepOf, canDecide: canDecide, decide: decide, cancel: cancel };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.approval;
})(globalThis);
