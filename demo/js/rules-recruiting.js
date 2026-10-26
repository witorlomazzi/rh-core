/* RH Core demo: maquina de etapas do recrutamento (spec 13). Pura, sem DOM.
   Espelha Recruiting_Stage__mdt (C1, C2) e as regras C4 a C7 e C11. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) require('./util.js');
  var RH = (g.RH = g.RH || {});
  var U = RH.util;

  var STAGES = [
    { value: 'Nova', label: 'Nova', order: 1, terminal: false, next: ['Triagem', 'Reprovado', 'Desistiu'], color: '#5c5c66' },
    { value: 'Triagem', label: 'Triagem', order: 2, terminal: false, next: ['Entrevista_RH', 'Reprovado', 'Desistiu'], color: '#0176d3' },
    { value: 'Entrevista_RH', label: 'Entrevista RH', order: 3, terminal: false, next: ['Entrevista_Tecnica', 'Reprovado', 'Desistiu'], color: '#0b5cab' },
    { value: 'Entrevista_Tecnica', label: 'Entrevista técnica', order: 4, terminal: false, next: ['Proposta', 'Reprovado', 'Desistiu'], color: '#014486' },
    { value: 'Proposta', label: 'Proposta', order: 5, terminal: false, next: ['Contratado', 'Reprovado', 'Desistiu'], color: '#8a5a00', requiresScore: true },
    { value: 'Contratado', label: 'Contratado', order: 6, terminal: true, next: [], color: '#2e844a' },
    { value: 'Reprovado', label: 'Reprovado', order: 7, terminal: true, next: [], color: '#ba0517', requiresRejectionReason: true },
    { value: 'Desistiu', label: 'Desistiu', order: 8, terminal: true, next: [], color: '#706e6b' }
  ];
  var REJECTION_REASONS = [
    { value: 'Perfil', label: 'Perfil não aderente' },
    { value: 'Salario', label: 'Pretensão salarial' },
    { value: 'Localizacao', label: 'Localização' },
    { value: 'Desistencia', label: 'Desistência' },
    { value: 'Outro', label: 'Outro' }
  ];

  function stage(value) {
    return STAGES.filter(function (s) {
      return s.value === value;
    })[0];
  }
  function label(value) {
    var s = stage(value);
    return s ? s.label : value;
  }

  /** C1 e C2. Retorna { ok, error, needs:['score'|'reason'] }. */
  function validateTransition(app, to, extra) {
    extra = extra || {};
    var from = stage(app.stage);
    var target = stage(to);
    if (!from || !target || from.next.indexOf(to) < 0) {
      return { ok: false, error: 'Mudança de etapa não permitida: de ' + label(app.stage) + ' para ' + label(to) + '.', needs: [] };
    }
    var needs = [];
    if (target.requiresRejectionReason && !extra.reason) needs.push('reason');
    // C2: Entrevista_Tecnica -> Proposta exige Score__c (0 a 5).
    if (target.requiresScore) {
      var score = extra.score !== undefined && extra.score !== null && extra.score !== '' ? extra.score : app.score;
      if (score === undefined || score === null || score === '') needs.push('score');
    }
    if (needs.length) {
      var msg = needs.indexOf('reason') >= 0 ? 'Informe o motivo da reprovação.' : 'Informe a nota (0 a 5) antes de enviar a proposta.';
      return { ok: false, error: msg, needs: needs };
    }
    if (extra.score !== undefined && extra.score !== null && extra.score !== '') {
      var n = Number(extra.score);
      if (!(n >= 0 && n <= 5) || Math.floor(n) !== n) return { ok: false, error: 'A nota deve ser um número inteiro de 0 a 5.', needs: ['score'] };
    }
    return { ok: true, needs: [] };
  }

  /** C3: dias na etapa anterior, com uma casa decimal. */
  function daysInStage(enteredDate, today) {
    return Math.max(0, U.diffDays(enteredDate, today || U.TODAY));
  }

  function normalizeEmail(email) {
    return String(email || '').trim().toLowerCase().replace(/\s+/g, '');
  }
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email);
  }
  /** C5 */
  function applicationKey(candidateId, jobId) {
    return candidateId + '|' + jobId;
  }
  /** C6: so vagas Abertas recebem candidatura nova. */
  function canApply(job) {
    return job.status === 'Aberta';
  }
  /** C7: slug unico a partir do titulo. */
  function uniqueSlug(title, existing) {
    var base = U.slugify(title) || 'vaga';
    var slug = base;
    var i = 2;
    while (existing.indexOf(slug) >= 0) {
      slug = base + '-' + i++;
    }
    return slug;
  }
  /** C11: candidato elegivel a anonimizacao LGPD. */
  function shouldAnonymize(candidate, applications, today, retentionDays) {
    if (candidate.anonymized) return false;
    var mine = applications.filter(function (a) {
      return a.candidateId === candidate.id;
    });
    if (mine.some(function (a) { return a.stage === 'Contratado'; })) return false;
    if (mine.some(function (a) { return !stage(a.stage).terminal; })) return false;
    if (!candidate.lastActivity) return false;
    return U.diffDays(candidate.lastActivity, today) > retentionDays;
  }
  function anonymizedFields(candidate) {
    return {
      name: 'Candidato anonimizado',
      email: 'anon-' + candidate.id + '@anon.invalid',
      emailNorm: 'anon-' + candidate.id + '@anon.invalid',
      phone: '',
      linkedin: '',
      city: '',
      anonymized: true
    };
  }

  RH.recruiting = {
    STAGES: STAGES,
    REJECTION_REASONS: REJECTION_REASONS,
    stage: stage,
    label: label,
    validateTransition: validateTransition,
    daysInStage: daysInStage,
    normalizeEmail: normalizeEmail,
    isValidEmail: isValidEmail,
    applicationKey: applicationKey,
    canApply: canApply,
    uniqueSlug: uniqueSlug,
    shouldAnonymize: shouldAnonymize,
    anonymizedFields: anonymizedFields
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.recruiting;
})(globalThis);
