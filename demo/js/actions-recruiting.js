/* RH Core demo: acoes de recrutamento e do portal publico (JobApplicationService, CandidateService,
   JobPortalController). Mutam o estado recebido; sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./queries.js');
    require('./rules-recruiting.js');
    require('./rules-portal.js');
  }
  var RH = (g.RH = g.RH || {});
  RH.actions = RH.actions || {};
  var U = RH.util;
  var Q = RH.q;
  var R = RH.recruiting;

  var INTERVIEW = ['Entrevista_RH', 'Entrevista_Tecnica'];

  /** Quem pode abrir/mover a candidatura: recrutador e RH em todas; gestor contratante so nas proprias vagas. */
  function canAccess(st, actor, app) {
    if (actor.role === 'recruiter' || actor.role === 'hr') return true;
    if (actor.role === 'manager') {
      var job = Q.jobById(st, app.jobId);
      return !!job && job.hiringManager === actor.empNum;
    }
    return false;
  }
  function visibleApplications(st, actor) {
    return st.applications.filter(function (a) { return canAccess(st, actor, a); });
  }
  function visibleJobs(st, actor) {
    if (actor.role === 'recruiter' || actor.role === 'hr') return st.jobs;
    if (actor.role === 'manager') return st.jobs.filter(function (j) { return j.hiringManager === actor.empNum; });
    return [];
  }

  function pushHistory(st, app, from, to, by, note) {
    st.stageHistory.push({
      id: 'EH-' + U.pad(st.seq.EH++, 6), appId: app.id, from: from, to: to, by: by, at: st.today,
      daysInPrev: from ? R.daysInStage(app.stageEntered, st.today) : null, note: note || ''
    });
  }

  /** C10 / O1: cria colaborador em pre-admissao e o plano de onboarding. Idempotente. */
  function onHired(st, actor, app) {
    if (app.employeeNum) return { ok: true, created: false };
    var job = Q.jobById(st, app.jobId);
    var cand = Q.candidateById(st, app.candidateId);
    var num = 'PRE-' + U.pad(st.seq.PRE++, 6);
    var hire = U.addDays(st.today, 15);
    st.employees.push({
      num: num, name: cand.name, email: cand.email, pos: job.pos, dept: job.dept, mgr: job.hiringManager, hire: hire, term: null, status: 'Pre_Admissao',
      type: job.employmentType, salary: null, location: 'SP-SAO_PAULO', absences: {}
    });
    app.employeeNum = num;
    var rhUser = actor.role === 'recruiter' || actor.role === 'hr' ? actor.empNum : job.recruiter;
    var plan = { id: 'ON-' + U.pad(st.seq.PLAN++, 6), empNum: num, appId: app.id, start: hire, status: 'Nao_Iniciado', tasks: [] };
    st.onboardingTemplates.forEach(function (t, i) {
      plan.tasks.push({
        id: 'T-' + U.pad(st.seq.TASK++, 4), title: t.title, description: t.description, role: t.role,
        assigned: t.role === 'Colaborador' ? num : t.role === 'Gestor' ? job.hiringManager : rhUser,
        due: U.addDays(hire, t.offset), status: 'Pendente', completedAt: null, order: i + 1
      });
    });
    st.onboardingPlans.push(plan);
    return { ok: true, created: true, employeeNum: num };
  }

  /** C1 a C3: move a candidatura. extra: { score, reason }. Retorna needs quando falta nota ou motivo. */
  function move(st, actor, appId, to, extra) {
    extra = extra || {};
    var app = Q.appById(st, appId);
    if (!app) return { ok: false, error: 'Candidatura não encontrada.', needs: [] };
    if (!canAccess(st, actor, app)) return { ok: false, error: 'Você não tem acesso a esta candidatura.', needs: [] };
    if (actor.role === 'manager' && INTERVIEW.indexOf(app.stage) < 0) {
      return { ok: false, error: 'O gestor contratante movimenta apenas candidaturas em etapas de entrevista.', needs: [] };
    }
    var v = R.validateTransition(app, to, extra);
    if (!v.ok) return v;
    var from = app.stage;
    pushHistory(st, app, from, to, actor.empNum, to === 'Reprovado' ? 'Motivo: ' + extra.reason : '');
    if (extra.score !== undefined && extra.score !== null && extra.score !== '') app.score = Number(extra.score);
    if (to === 'Reprovado') app.rejectionReason = extra.reason;
    app.stage = to;
    app.stageEntered = st.today;
    var cand = Q.candidateById(st, app.candidateId);
    if (cand) cand.lastActivity = st.today;
    var hired = null;
    if (to === 'Contratado') hired = onHired(st, actor, app);
    return { ok: true, app: app, hired: hired };
  }

  /** Nota do gestor contratante ou do recrutador (0 a 5). */
  function setScore(st, actor, appId, score) {
    var app = Q.appById(st, appId);
    if (!app || !canAccess(st, actor, app)) return { ok: false, error: 'Você não tem acesso a esta candidatura.' };
    var n = Number(score);
    if (!(n >= 0 && n <= 5) || Math.floor(n) !== n) return { ok: false, error: 'A nota deve ser um número inteiro de 0 a 5.' };
    app.score = n;
    return { ok: true };
  }

  /** C6: fechar ou cancelar a vaga reprova as candidaturas nao terminais. */
  function closeJob(st, actor, jobId, status) {
    if (actor.role !== 'recruiter' && actor.role !== 'hr') return { ok: false, error: 'Somente recrutador ou RH encerram vagas.' };
    var job = Q.jobById(st, jobId);
    if (!job) return { ok: false, error: 'Vaga não encontrada.' };
    if (status !== 'Fechada' && status !== 'Cancelada') return { ok: false, error: 'Status inválido.' };
    var n = 0;
    st.applications.forEach(function (a) {
      if (a.jobId === jobId && !R.stage(a.stage).terminal) {
        pushHistory(st, a, a.stage, 'Reprovado', actor.empNum, 'Vaga encerrada');
        a.stage = 'Reprovado';
        a.rejectionReason = 'Outro';
        a.stageEntered = st.today;
        n++;
      }
    });
    job.status = status;
    job.closedDate = st.today;
    job.publishOnPortal = false;
    return { ok: true, rejected: n };
  }

  function setJobStatus(st, actor, jobId, status) {
    if (actor.role !== 'recruiter' && actor.role !== 'hr') return { ok: false, error: 'Somente recrutador ou RH alteram vagas.' };
    var job = Q.jobById(st, jobId);
    if (!job) return { ok: false, error: 'Vaga não encontrada.' };
    if (job.status === 'Fechada' || job.status === 'Cancelada') return { ok: false, error: 'Vagas encerradas não podem ser reabertas.' };
    if (status !== 'Aberta' && status !== 'Pausada') return { ok: false, error: 'Status inválido.' };
    job.status = status;
    return { ok: true };
  }
  function togglePublish(st, actor, jobId) {
    if (actor.role !== 'recruiter' && actor.role !== 'hr') return { ok: false, error: 'Somente recrutador ou RH publicam vagas.' };
    var job = Q.jobById(st, jobId);
    if (!job) return { ok: false, error: 'Vaga não encontrada.' };
    job.publishOnPortal = !job.publishOnPortal;
    return { ok: true, published: job.publishOnPortal };
  }

  /** C11: rotina de retencao LGPD. Nunca anonimiza contratado nem candidato com candidatura ativa. */
  function runRetention(st, actor) {
    if (actor.role !== 'recruiter' && actor.role !== 'hr') return { ok: false, error: 'Somente recrutador ou RH executam a retenção.' };
    var names = [];
    st.candidates.forEach(function (c) {
      if (R.shouldAnonymize(c, st.applications, st.today, st.settings.candidateRetentionDays)) {
        names.push(c.name);
        var f = R.anonymizedFields(c);
        Object.keys(f).forEach(function (k) { c[k] = f[k]; });
        st.applications.forEach(function (a) { if (a.candidateId === c.id) a.coverLetter = ''; });
      }
    });
    return { ok: true, count: names.length, names: names };
  }

  /** Contagem diaria de candidaturas por e-mail (inclui o reforco da simulacao de limite). */
  function countToday(st, email) {
    var n = (st.portal.boost && st.portal.boost[email]) || 0;
    st.applications.forEach(function (a) {
      var c = Q.candidateById(st, a.candidateId);
      if (c && c.emailNorm === email && a.createdAt === st.today) n++;
    });
    return n;
  }

  function portalJobs(st) {
    return st.jobs.filter(RH.portal.isEligible).map(function (j) {
      return RH.portal.toDto(j, Q.deptName(st, j.dept));
    });
  }

  /** G3: JobPortalController.submitApplication. input vem do formulario publico; nowMs em epoch ms. */
  function portalSubmit(st, input, nowMs) {
    var res = RH.portal.validateSubmission(input, {
      jobs: st.jobs,
      nowMs: nowMs,
      minSeconds: st.settings.portalMinSubmitSeconds,
      dailyLimit: st.settings.portalDailyLimit,
      countToday: function (email) { return countToday(st, email); },
      alreadyApplied: function (email, jobId) {
        return st.applications.some(function (a) {
          var c = Q.candidateById(st, a.candidateId);
          return a.jobId === jobId && c && c.emailNorm === email;
        });
      }
    });
    function log(kind, text) {
      st.portal.log.unshift({ at: st.today, code: res.code, kind: kind, text: text });
      st.portal.log = st.portal.log.slice(0, 20);
    }
    if (!res.ok) {
      log('rejeitada', res.message);
      return res;
    }
    if (res.silent) {
      log('descartada', 'Honeypot preenchido: o servidor respondeu sucesso, mas nada foi gravado.');
      return res;
    }
    var c = res.clean;
    var cand = st.candidates.filter(function (x) { return x.emailNorm === c.email; })[0];
    if (cand) {
      // C4: reaproveita o candidato por e-mail normalizado.
      cand.lastActivity = st.today;
      cand.name = c.name || cand.name;
      cand.phone = c.phone || cand.phone;
    } else {
      cand = {
        id: 'C-' + U.pad(st.seq.CAND++, 2), name: c.name, email: c.email, emailNorm: c.email, phone: c.phone, city: c.city, linkedin: c.linkedin, source: 'Portal',
        consent: true, consentDate: st.today, consentVersion: st.settings.consentVersion, anonymized: false, lastActivity: st.today
      };
      st.candidates.push(cand);
    }
    var app = {
      id: 'A-' + U.pad(st.seq.APP++, 3), candidateId: cand.id, jobId: res.job.id, stage: 'Nova', stageEntered: st.today, score: null, rejectionReason: null,
      source: 'Portal', coverLetter: c.message, createdAt: st.today, employeeNum: null
    };
    st.applications.push(app);
    st.stageHistory.push({ id: 'EH-' + U.pad(st.seq.EH++, 6), appId: app.id, from: '', to: 'Nova', by: 'Portal', at: st.today, daysInPrev: null, note: '' });
    log('gravada', 'Candidatura ' + app.id + ' criada na etapa Nova, origem Portal, na fila do recrutamento.');
    res.application = app;
    return res;
  }

  RH.actions.recruiting = {
    INTERVIEW: INTERVIEW,
    canAccess: canAccess,
    visibleApplications: visibleApplications,
    visibleJobs: visibleJobs,
    move: move,
    setScore: setScore,
    closeJob: closeJob,
    setJobStatus: setJobStatus,
    togglePublish: togglePublish,
    runRetention: runRetention,
    countToday: countToday,
    portalJobs: portalJobs,
    portalSubmit: portalSubmit
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.actions.recruiting;
})(globalThis);
