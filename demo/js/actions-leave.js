/* RH Core demo: acoes de ferias (LeaveRequestService). Mutam o estado recebido; sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./queries.js');
    require('./rules-approval.js');
  }
  var RH = (g.RH = g.RH || {});
  RH.actions = RH.actions || {};
  var U = RH.util;
  var Q = RH.q;
  var L = RH.leave;

  function canActFor(actor, empNum) {
    return actor.empNum === empNum || actor.role === 'hr';
  }

  /** Roda o motor sobre um pedido (sem gravar). input: { empNum, periodKey, start, days, sold, excludeId, allowNoticeException } */
  function evaluate(st, actor, input) {
    if (!canActFor(actor, input.empNum)) return { ok: false, error: 'Você só pode solicitar férias para o seu próprio cadastro.' };
    var e = Q.emp(st, input.empNum);
    var item = Q.periodsOf(st, input.empNum).filter(function (x) { return x.period.key === input.periodKey; })[0];
    if (!e || !item) return { ok: false, error: 'Selecione um período aquisitivo válido.' };
    if (item.period.lost) return { ok: false, error: 'Este período foi perdido (mais de 32 faltas injustificadas).' };
    var mine = Q.leaveRequestsOf(st, input.empNum).filter(function (r) { return r.id !== input.excludeId; });
    var results = L.evaluate({
      period: item.period,
      existing: mine.filter(function (r) { return r.periodKey === input.periodKey; }),
      employeeRequests: mine,
      request: { start: input.start, days: Number(input.days), sold: Number(input.sold || 0) },
      today: st.today,
      settings: st.settings,
      holidaySet: Q.holidaySetFor(st, e),
      teamLeaves: Q.teamLeaves(st, e, input.excludeId),
      allowNoticeException: !!input.allowNoticeException && actor.role === 'hr'
    });
    return { ok: true, results: results, summary: L.summarize(results), period: item.period };
  }

  /** Salva rascunho (asDraft) ou envia para aprovacao (so sem bloqueios). */
  function submit(st, actor, input, asDraft) {
    var ev = evaluate(st, actor, input);
    if (!ev.ok) return ev;
    if (!asDraft && !ev.summary.canSubmit) return { ok: false, error: 'O pedido tem regras bloqueantes.', results: ev.results, summary: ev.summary };
    var e = Q.emp(st, input.empNum);
    var req = input.requestId ? st.leaveRequests.filter(function (r) { return r.id === input.requestId; })[0] : null;
    if (req && req.status !== 'Rascunho') return { ok: false, error: 'Só rascunhos podem ser editados.' };
    if (!req) {
      req = { id: 'FE-' + U.pad(st.seq.FE++, 6), empNum: e.num, requestedBy: actor.empNum, createdAt: st.today, notes: '' };
      st.leaveRequests.push(req);
    }
    var conflict = ev.results.filter(function (r) { return r.code === 'CONFLITO_EQUIPE' && r.status === 'warning'; })[0];
    req.periodKey = input.periodKey;
    req.start = input.start;
    req.days = Number(input.days);
    req.sold = Number(input.sold || 0);
    req.location = e.location;
    req.ruleCheck = ev.results.map(function (r) { return { code: r.code, status: r.status }; });
    req.conflict = conflict ? conflict.message : '';
    if (asDraft) {
      req.status = 'Rascunho';
      req.steps = [];
      req.step = 0;
    } else {
      var s = RH.approval.submit('Leave', e.num, e, Q.index(st).byNum, st.today);
      req.steps = s.steps;
      req.step = s.currentStep;
      req.status = 'Pendente';
    }
    return { ok: true, request: req, results: ev.results, summary: ev.summary };
  }

  function deleteDraft(st, actor, id) {
    var r = st.leaveRequests.filter(function (x) { return x.id === id; })[0];
    if (!r || r.status !== 'Rascunho') return { ok: false, error: 'Só rascunhos podem ser excluídos.' };
    if (!canActFor(actor, r.empNum)) return { ok: false, error: 'Sem permissão.' };
    st.leaveRequests = st.leaveRequests.filter(function (x) { return x.id !== id; });
    return { ok: true };
  }

  /** Visibilidade (sharing): colaborador ve os proprios; gestor, a subarvore; RH, todos. */
  function visibleRequests(st, actor) {
    var idx = Q.index(st);
    return st.leaveRequests.filter(function (r) {
      return RH.visibility.canSeeDetail(actor.persona, idx, r.empNum);
    });
  }

  /** Rotina diaria (LeaveStatusBatch): Aprovado que comecou vira Em_Gozo; Em_Gozo que acabou vira Concluido. */
  function runStatusBatch(st) {
    var changed = 0;
    st.leaveRequests.forEach(function (r) {
      var e = Q.emp(st, r.empNum);
      if (r.status === 'Aprovado' && r.start <= st.today) {
        r.status = 'Em_Gozo';
        if (e && e.status === 'Ativo') e.status = 'Ferias';
        changed++;
      }
      if (r.status === 'Em_Gozo' && L.requestEnd(r) < st.today) {
        r.status = 'Concluido';
        if (e && e.status === 'Ferias') e.status = 'Ativo';
        changed++;
      }
    });
    return { ok: true, changed: changed };
  }

  RH.actions.leave = { evaluate: evaluate, submit: submit, deleteDraft: deleteDraft, visibleRequests: visibleRequests, runStatusBatch: runStatusBatch };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.actions.leave;
})(globalThis);
