/* RH Core demo: regras de promocao (spec 12, P1 a P8). Puro, sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./util.js');
    require('./rules-visibility.js');
  }
  var RH = (g.RH = g.RH || {});
  var U = RH.util;
  var V = RH.visibility;

  var STATUS_LABEL = { Rascunho: 'Rascunho', Pendente: 'Pendente', Aprovado: 'Aprovado', Rejeitado: 'Rejeitado', Cancelado: 'Cancelado', Efetivado: 'Efetivado' };

  /**
   * Valida a solicitacao do gestor. ctx: { idx, positions, existing (solicitacoes) }.
   * Retorna { errors:[], warnings:[] }.
   */
  function validateRequest(input, ctx, today) {
    today = today || U.TODAY;
    var errors = [];
    var warnings = [];
    var subject = ctx.idx.byNum[input.subjectNum];
    var current = subject ? ctx.positions[subject.pos] : null;
    var proposed = ctx.positions[input.proposedPos];
    // P1
    if (!subject || !V.isInChainOf(ctx.idx, input.requesterNum, input.subjectNum)) {
      errors.push('Você só pode solicitar promoção para alguém da sua equipe.');
    }
    // P2
    if (!proposed || !proposed.active || (subject && input.proposedPos === subject.pos)) {
      errors.push('O novo cargo precisa ser diferente do atual e estar ativo.');
    } else if (current && current.next !== input.proposedPos) {
      warnings.push('Promoção fora da trilha prevista.');
    }
    // P3
    if (!input.effective || input.effective < today) errors.push('A data de efetivação não pode estar no passado.');
    // P4
    var pending = (ctx.existing || []).some(function (p) {
      return p.empNum === input.subjectNum && p.status === 'Pendente';
    });
    if (pending) errors.push('Este colaborador já possui uma solicitação de promoção pendente.');
    if (!input.justification || !input.justification.trim()) errors.push('Informe a justificativa.');
    return { errors: errors, warnings: warnings };
  }

  /** Compara um salario com a faixa do cargo. */
  function bandCheck(salary, position) {
    if (!position || !position.band || salary === null || salary === undefined || salary === '') return { status: 'unknown' };
    var b = position.band;
    if (salary < b.min) return { status: 'below', band: b };
    if (salary > b.max) return { status: 'above', band: b };
    return { status: 'within', band: b };
  }
  function increasePercent(current, proposed) {
    if (!current || !proposed) return null;
    return Math.round(((proposed - current) / current) * 1000) / 10;
  }

  /** P6: checagem da etapa do RH antes de decidir. */
  function hrDecisionCheck(req, position, decision, comment) {
    if (decision !== 'Aprovado') return { ok: true };
    if (!req.proposedSalary) return { ok: false, error: 'Informe o salário proposto antes de aprovar.' };
    var bc = bandCheck(req.proposedSalary, position);
    if (bc.status !== 'within' && !(comment || '').trim()) {
      return { ok: false, error: 'Salário fora da faixa do cargo: informe a justificativa na decisão.' };
    }
    return { ok: true };
  }

  RH.promotion = { STATUS_LABEL: STATUS_LABEL, validateRequest: validateRequest, bandCheck: bandCheck, increasePercent: increasePercent, hrDecisionCheck: hrDecisionCheck };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.promotion;
})(globalThis);
