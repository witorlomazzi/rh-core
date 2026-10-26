/* RH Core demo: regras de avaliacao de desempenho (spec 16, A1 a A8). Puro, sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) require('./util.js');
  var RH = (g.RH = g.RH || {});

  var PHASES = ['Planejado', 'Autoavaliacao', 'Avaliacao_Gestor', 'Calibracao', 'Concluido'];
  var PHASE_LABEL = { Planejado: 'Planejado', Autoavaliacao: 'Autoavaliação', Avaliacao_Gestor: 'Avaliação do gestor', Calibracao: 'Calibração', Concluido: 'Concluído' };
  var REVIEW_LABEL = { Pendente: 'Pendente', Em_Andamento: 'Em andamento', Enviada: 'Enviada', Calibrada: 'Calibrada', Liberada: 'Liberada' };
  var SCALE_MAX = 5;

  /** A4: soma dos pesos das metas ativas. */
  function weightSum(goals) {
    return goals.reduce(function (a, x) {
      return a + (x.status === 'Ativa' ? Number(x.weight) || 0 : 0);
    }, 0);
  }
  function validRating(n) {
    n = Number(n);
    return Math.floor(n) === n && n >= 1 && n <= SCALE_MAX;
  }

  /** A3: autoavaliacao so editavel pelo proprio colaborador, com o ciclo em Autoavaliacao, ate enviar. */
  function canEditSelf(cycleStatus, self, actorNum, ownerNum) {
    if (actorNum !== ownerNum) return { ok: false, error: 'Só o próprio colaborador edita a autoavaliação.' };
    if (cycleStatus !== 'Autoavaliacao') return { ok: false, error: 'O ciclo não está na fase de autoavaliação.' };
    if (self && self.submitted) return { ok: false, error: 'A autoavaliação já foi enviada e não pode mais ser alterada.' };
    return { ok: true };
  }
  /** A3 e A4 no envio. */
  function validateSelfSubmit(goals, self) {
    var errors = [];
    if (!validRating(self.rating)) errors.push('Informe uma nota de 1 a ' + SCALE_MAX + '.');
    var total = weightSum(goals);
    if (total !== 100) errors.push('A soma dos pesos das metas ativas precisa ser 100% (hoje: ' + total + '%).');
    return errors;
  }
  /** A5: avaliacao do gestor so pelo Reviewer, com o ciclo em Avaliacao_Gestor. */
  function canEditManagerReview(cycleStatus, review, actorNum) {
    if (review.reviewer !== actorNum) return { ok: false, error: 'Só o gestor direto (avaliador) registra esta avaliação.' };
    if (cycleStatus !== 'Avaliacao_Gestor') return { ok: false, error: 'O ciclo não está na fase de avaliação do gestor.' };
    if (review.status === 'Enviada' || review.status === 'Calibrada' || review.status === 'Liberada') return { ok: false, error: 'A avaliação já foi enviada.' };
    return { ok: true };
  }
  function nextPhase(phase) {
    var i = PHASES.indexOf(phase);
    return i >= 0 && i < PHASES.length - 1 ? PHASES[i + 1] : null;
  }
  /** Nota final: a calibrada, quando existir. */
  function finalRating(review) {
    if (review.calibrated !== null && review.calibrated !== undefined) return review.calibrated;
    return review.managerRating;
  }

  RH.performance = {
    PHASES: PHASES,
    PHASE_LABEL: PHASE_LABEL,
    REVIEW_LABEL: REVIEW_LABEL,
    SCALE_MAX: SCALE_MAX,
    weightSum: weightSum,
    validRating: validRating,
    canEditSelf: canEditSelf,
    validateSelfSubmit: validateSelfSubmit,
    canEditManagerReview: canEditManagerReview,
    nextPhase: nextPhase,
    finalRating: finalRating
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.performance;
})(globalThis);
