/* RH Core demo: regras do portal publico de vagas (spec 14, G1 a G5). Puro, sem DOM.
   validateSubmission espelha JobPortalController.submitApplication. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./util.js');
    require('./rules-recruiting.js');
  }
  var RH = (g.RH = g.RH || {});
  var U = RH.util;
  var R = RH.recruiting;

  var LIMITS = { name: [2, 120], email: 120, phone: 30, city: 80, linkedin: 200, message: 2000 };
  var CONSENT_TEXT =
    'Concordo com o tratamento dos meus dados pessoais pela Vetra Distribuidora (empresa fictícia) apenas para este processo seletivo, ' +
    'conforme a LGPD. Os dados de candidatos não contratados são anonimizados após 180 dias.';

  /** G1: DTO publico. Nunca expoe Ids de usuario, gestor ou recrutador. */
  function toDto(job, departmentName) {
    return {
      title: job.title,
      slug: job.slug,
      department: departmentName,
      location: job.location,
      workModel: job.workModel,
      employmentType: job.employmentType,
      description: job.description,
      requirements: job.requirements,
      openedDate: job.openedDate
    };
  }
  /** G2 */
  function isEligible(job) {
    return job.status === 'Aberta' && job.publishOnPortal === true;
  }

  /**
   * G3. input: { slug, name, email, phone, city, linkedin, message, consent, website, renderedAt }
   * ctx: { jobs, nowMs, minSeconds, dailyLimit, countToday(emailNorm), alreadyApplied(emailNorm, jobId) }
   * Retorna { ok, silent?, code, message, fieldErrors }.
   */
  function validateSubmission(input, ctx) {
    var fe = {};
    var job = (ctx.jobs || []).filter(function (j) { return j.slug === input.slug; })[0];
    if (!job || !isEligible(job)) {
      return { ok: false, code: 'VAGA_INDISPONIVEL', message: 'Esta vaga não está mais disponível.', fieldErrors: fe };
    }
    // Honeypot: responde sucesso falso, sem gravar, para nao ensinar o robo.
    if (input.website && String(input.website).trim() !== '') {
      return { ok: true, silent: true, code: 'HONEYPOT', message: 'Candidatura recebida.', fieldErrors: fe };
    }
    var name = U.stripHtml(input.name);
    var email = R.normalizeEmail(input.email);
    var phone = U.stripHtml(input.phone);
    var city = U.stripHtml(input.city);
    var linkedin = U.stripHtml(input.linkedin);
    var message = U.stripHtml(input.message);

    if (name.length < LIMITS.name[0] || name.length > LIMITS.name[1]) fe.name = 'Informe seu nome (2 a 120 caracteres).';
    if (!R.isValidEmail(email) || email.length > LIMITS.email) fe.email = 'Informe um e-mail válido.';
    if (phone.length > LIMITS.phone) fe.phone = 'Telefone muito longo (até 30 caracteres).';
    if (city.length > LIMITS.city) fe.city = 'Cidade muito longa (até 80 caracteres).';
    if (linkedin && (linkedin.length > LIMITS.linkedin || !/^https?:\/\//i.test(linkedin))) fe.linkedin = 'Use um endereço que comece com http:// ou https://.';
    if (message.length > LIMITS.message) fe.message = 'A mensagem passa de 2000 caracteres.';
    if (input.consent !== true) fe.consent = 'É necessário aceitar o termo de privacidade para se candidatar.';
    if (Object.keys(fe).length) {
      return { ok: false, code: 'VALIDACAO', message: 'Revise os campos destacados.', fieldErrors: fe };
    }
    var elapsed = (ctx.nowMs - Number(input.renderedAt || 0)) / 1000;
    if (!(elapsed >= ctx.minSeconds)) {
      return { ok: false, code: 'TEMPO_MINIMO', message: 'Não foi possível enviar agora. Tente novamente em instantes.', fieldErrors: fe };
    }
    if (ctx.countToday(email) >= ctx.dailyLimit) {
      return { ok: false, code: 'LIMITE_DIARIO', message: 'Limite diário de candidaturas atingido.', fieldErrors: fe };
    }
    if (ctx.alreadyApplied(email, job.id)) {
      return { ok: false, code: 'DUPLICADA', message: 'Este candidato já se inscreveu nesta vaga.', fieldErrors: fe };
    }
    return {
      ok: true,
      code: 'OK',
      message: 'Candidatura recebida. Obrigado pelo interesse!',
      fieldErrors: fe,
      clean: { name: name, email: email, phone: phone, city: city, linkedin: linkedin, message: message },
      job: job
    };
  }

  RH.portal = { LIMITS: LIMITS, CONSENT_TEXT: CONSENT_TEXT, toDto: toDto, isEligible: isEligible, validateSubmission: validateSubmission };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.portal;
})(globalThis);
