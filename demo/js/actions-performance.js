/* RH Core demo: acoes de avaliacao de desempenho (ReviewCycleService, GoalService, SelfAssessmentService,
   PerformanceReviewService). Mutam o estado recebido; sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./queries.js');
    require('./rules-performance.js');
  }
  var RH = (g.RH = g.RH || {});
  RH.actions = RH.actions || {};
  var U = RH.util;
  var Q = RH.q;
  var P = RH.performance;

  function goalsOf(st, empNum) {
    return st.goals.filter(function (x) { return x.empNum === empNum; });
  }

  // ---- metas (colaborador, antes de enviar a autoavaliacao)
  function guardGoals(st, actor, empNum) {
    if (actor.empNum !== empNum) return { ok: false, error: 'Só o próprio colaborador edita suas metas.' };
    if (st.cycle.status !== 'Planejado' && st.cycle.status !== 'Autoavaliacao') return { ok: false, error: 'As metas só podem ser alteradas até o fim da autoavaliação.' };
    var self = st.selfAssessments[empNum];
    if (self && self.submitted) return { ok: false, error: 'A autoavaliação já foi enviada e as metas ficam travadas.' };
    return { ok: true };
  }
  function addGoal(st, actor, empNum, data) {
    var gd = guardGoals(st, actor, empNum);
    if (!gd.ok) return gd;
    var name = (data.name || '').trim();
    var w = Number(data.weight);
    if (!name) return { ok: false, error: 'Informe o nome da meta.' };
    if (!(w > 0 && w <= 100)) return { ok: false, error: 'O peso deve estar entre 1% e 100%.' };
    st.goals.push({ id: 'G-' + U.pad(st.seq.GOAL++, 4), empNum: empNum, name: name, description: '', weight: w, target: (data.target || '').trim(), status: 'Ativa' });
    return { ok: true };
  }
  function updateGoalWeight(st, actor, goalId, weight) {
    var goal = st.goals.filter(function (x) { return x.id === goalId; })[0];
    if (!goal) return { ok: false, error: 'Meta não encontrada.' };
    var gd = guardGoals(st, actor, goal.empNum);
    if (!gd.ok) return gd;
    var w = Number(weight);
    if (!(w > 0 && w <= 100)) return { ok: false, error: 'O peso deve estar entre 1% e 100%.' };
    goal.weight = w;
    return { ok: true };
  }
  function removeGoal(st, actor, goalId) {
    var goal = st.goals.filter(function (x) { return x.id === goalId; })[0];
    if (!goal) return { ok: false, error: 'Meta não encontrada.' };
    var gd = guardGoals(st, actor, goal.empNum);
    if (!gd.ok) return gd;
    st.goals = st.goals.filter(function (x) { return x.id !== goalId; });
    return { ok: true };
  }

  // ---- autoavaliacao
  function saveSelf(st, actor, empNum, data, send) {
    var self = st.selfAssessments[empNum];
    var chk = P.canEditSelf(st.cycle.status, self, actor.empNum, empNum);
    if (!chk.ok) return chk;
    var draft = { rating: data.rating ? Number(data.rating) : null, strengths: (data.strengths || '').trim(), improvements: (data.improvements || '').trim() };
    if (send) {
      var errors = P.validateSelfSubmit(goalsOf(st, empNum), draft);
      if (errors.length) return { ok: false, error: errors[0], errors: errors };
    }
    self.rating = draft.rating;
    self.strengths = draft.strengths;
    self.improvements = draft.improvements;
    if (send) {
      self.submitted = true;
      self.submittedDate = st.today;
    }
    return { ok: true };
  }

  // ---- avaliacao do gestor
  function saveManagerReview(st, actor, empNum, data, send) {
    var rv = st.reviews[empNum];
    if (!rv) return { ok: false, error: 'Avaliação não encontrada.' };
    var chk = P.canEditManagerReview(st.cycle.status, rv, actor.empNum);
    if (!chk.ok) return chk;
    var rating = data.rating ? Number(data.rating) : null;
    if (send && !P.validRating(rating)) return { ok: false, error: 'Informe uma nota de 1 a ' + P.SCALE_MAX + ' para enviar.' };
    rv.managerRating = rating;
    rv.comments = (data.comments || '').trim();
    rv.status = send ? 'Enviada' : 'Em_Andamento';
    return { ok: true };
  }

  // ---- RH: fases, calibracao e liberacao
  function advancePhase(st, actor) {
    if (actor.role !== 'hr') return { ok: false, error: 'Somente o RH avança as fases do ciclo.' };
    var cur = st.cycle.status;
    if (cur === 'Calibracao') return { ok: false, error: 'Use "Liberar resultados" para concluir o ciclo.' };
    var next = P.nextPhase(cur);
    if (!next || cur === 'Concluido') return { ok: false, error: 'O ciclo já foi concluído.' };
    st.cycle.status = next;
    return { ok: true, status: next };
  }
  function calibrate(st, actor, empNum, rating) {
    if (actor.role !== 'hr') return { ok: false, error: 'Somente o RH calibra as notas.' };
    if (st.cycle.status !== 'Calibracao') return { ok: false, error: 'O ciclo não está na fase de calibração.' };
    var rv = st.reviews[empNum];
    if (!rv || (rv.status !== 'Enviada' && rv.status !== 'Calibrada')) return { ok: false, error: 'A avaliação do gestor ainda não foi enviada.' };
    var n = Number(rating);
    if (!P.validRating(n)) return { ok: false, error: 'Informe uma nota de 1 a ' + P.SCALE_MAX + '.' };
    rv.calibrated = n;
    rv.status = 'Calibrada';
    return { ok: true };
  }
  /** A7: libera as avaliacoes enviadas ou calibradas e conclui o ciclo. */
  function release(st, actor) {
    if (actor.role !== 'hr') return { ok: false, error: 'Somente o RH libera os resultados.' };
    if (st.cycle.status !== 'Calibracao') return { ok: false, error: 'O ciclo precisa estar em calibração para liberar.' };
    var released = 0;
    var left = 0;
    Object.keys(st.reviews).forEach(function (k) {
      var rv = st.reviews[k];
      if (rv.status === 'Enviada' || rv.status === 'Calibrada') {
        rv.status = 'Liberada';
        rv.releasedDate = st.today;
        released++;
      } else {
        left++;
      }
    });
    st.cycle.status = 'Concluido';
    return { ok: true, released: released, left: left };
  }
  /** Quem pode ler a avaliacao do gestor: o avaliador, a cadeia e o RH; o colaborador so depois de liberada. */
  function canReadReview(st, actor, empNum) {
    var rv = st.reviews[empNum];
    if (!rv) return false;
    if (actor.role === 'hr') return true;
    if (actor.empNum === empNum) return rv.status === 'Liberada';
    var idx = Q.index(st);
    return RH.visibility.isInChainOf(idx, actor.empNum, empNum);
  }

  RH.actions.performance = {
    goalsOf: goalsOf,
    addGoal: addGoal,
    updateGoalWeight: updateGoalWeight,
    removeGoal: removeGoal,
    saveSelf: saveSelf,
    saveManagerReview: saveManagerReview,
    advancePhase: advancePhase,
    calibrate: calibrate,
    release: release,
    canReadReview: canReadReview
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.actions.performance;
})(globalThis);
