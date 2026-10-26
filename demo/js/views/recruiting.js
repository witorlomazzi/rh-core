/* RH Core demo: recrutamento (spec 13): kanban com arrastar e soltar e alternativa por teclado, regras da maquina
   de etapas, motivo e nota obrigatorios, historico com dias na etapa, gestao de vagas e retencao LGPD. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var A = RH.actions;
  var R = RH.recruiting;

  var local = { persona: null, tab: 'board', job: 'JOB-1', dragId: null };

  function resetFor(ctx) {
    if (local.persona === ctx.persona) return;
    local.persona = ctx.persona;
    local.tab = 'board';
    local.job = 'JOB-1';
  }
  function isStaff(ctx) {
    return ctx.actor.role === 'recruiter' || ctx.actor.role === 'hr';
  }

  function stars(score) {
    if (score === null || score === undefined) return '<span class="rhc-muted">Sem nota</span>';
    return '<span class="rhc-stars" role="img" aria-label="Nota ' + score + ' de 5">' + [1, 2, 3, 4, 5].map(function (i) { return '<i class="' + (i <= score ? 'on' : '') + '"></i>'; }).join('') + '<small>' + score + '/5</small></span>';
  }

  function canMoveCard(ctx, app) {
    if (isStaff(ctx)) return !R.stage(app.stage).terminal;
    return ctx.actor.role === 'manager' && A.recruiting.INTERVIEW.indexOf(app.stage) >= 0;
  }

  function card(ctx, app) {
    var cand = Q.candidateById(ctx.st, app.candidateId);
    var days = R.daysInStage(app.stageEntered, ctx.st.today);
    var st = R.stage(app.stage);
    var movable = canMoveCard(ctx, app);
    var isNew = app.createdAt === ctx.st.today && app.source === 'Portal';
    var opts = st.next.map(function (n) { return '<option value="' + n + '">' + esc(R.label(n)) + '</option>'; }).join('');
    return (
      '<article class="rhc-kcard' + (movable ? '' : ' is-locked') + '" ' + (movable ? 'draggable="true"' : '') + ' data-app="' + app.id + '" aria-label="Candidatura ' + esc(cand.name) + ', etapa ' + esc(st.label) + '">' +
      '<header>' + (movable ? '<span class="rhc-grip" aria-hidden="true">' + UI.icon('grip') + '</span>' : '') + UI.avatar(cand.name) +
      '<button type="button" class="rhc-kname" data-act="rec.open" data-app="' + app.id + '"><strong>' + esc(cand.name) + '</strong><small>' + esc(cand.city || 'Cidade não informada') + '</small></button></header>' +
      '<div class="rhc-kmeta">' + stars(app.score) + '<span class="rhc-days' + (days >= 7 && !st.terminal ? ' is-late' : '') + '" title="Tempo nesta etapa">' + UI.icon('clock') + days + ' d</span></div>' +
      '<div class="rhc-ktags">' + UI.badge(app.source === 'Portal' ? 'Portal' : app.source === 'Indicacao' ? 'Indicação' : app.source, 'neutral') + (isNew ? UI.badge('Nova hoje', 'info', 'globe') : '') + (app.rejectionReason ? UI.badge(R.REJECTION_REASONS.filter(function (x) { return x.value === app.rejectionReason; })[0].label, 'danger') : '') + '</div>' +
      (movable && st.next.length ? '<label class="rhc-sr" for="mv-' + app.id + '">Mover ' + esc(cand.name) + ' para</label><select id="mv-' + app.id + '" class="rhc-move" data-change="rec.moveSel" data-app="' + app.id + '"><option value="">Mover para…</option>' + opts + '</select>' : '') +
      '</article>'
    );
  }

  function summaryHtml(ctx, job, apps) {
    var byStage = {};
    apps.forEach(function (a) { byStage[a.stage] = (byStage[a.stage] || 0) + 1; });
    var sums = {};
    var ids = apps.map(function (a) { return a.id; });
    ctx.st.stageHistory.forEach(function (h) {
      if (ids.indexOf(h.appId) >= 0 && h.daysInPrev !== null && h.from) {
        (sums[h.from] = sums[h.from] || []).push(h.daysInPrev);
      }
    });
    var maxAvg = 1;
    var avgs = R.STAGES.map(function (s) {
      var arr = sums[s.value] || [];
      var avg = arr.length ? arr.reduce(function (a, b) { return a + b; }, 0) / arr.length : 0;
      if (avg > maxAvg) maxAvg = avg;
      return { s: s, avg: avg, n: arr.length };
    }).filter(function (x) { return !x.s.terminal; });
    return (
      '<div class="rhc-kpis"><div class="rhc-kpi">' + UI.icon('users') + '<div><strong>' + apps.length + '</strong><span>candidaturas na vaga</span></div></div>' +
      '<div class="rhc-kpi">' + UI.icon('flag') + '<div><strong>' + job.openings + '</strong><span>vaga(s) a preencher</span></div></div>' +
      '<div class="rhc-kpi">' + UI.icon('check') + '<div><strong>' + (byStage.Contratado || 0) + '</strong><span>contratado(s)</span></div></div></div>' +
      '<h5 class="rhc-subtitle">Tempo médio por etapa (dias)</h5><ul class="rhc-bars">' + avgs.map(function (x) {
        return '<li><span>' + esc(x.s.label) + '</span><div class="rhc-bar"><i style="width:' + Math.round((x.avg / maxAvg) * 100) + '%"></i></div><b>' + (x.n ? x.avg.toFixed(1).replace('.', ',') : '-') + '</b></li>';
      }).join('') + '</ul>'
    );
  }

  function boardHtml(ctx) {
    var jobs = A.recruiting.visibleJobs(ctx.st, ctx.actor);
    if (!jobs.length) return UI.empty('lock', 'Sem acesso a candidaturas', 'Somente recrutadores, RH e gestores contratantes (das próprias vagas) acessam candidatos.');
    if (!jobs.some(function (j) { return j.id === local.job; })) local.job = jobs[0].id;
    var job = Q.jobById(ctx.st, local.job);
    var apps = ctx.st.applications.filter(function (a) { return a.jobId === job.id; });
    var cols = R.STAGES.map(function (s) {
      var list = apps.filter(function (a) { return a.stage === s.value; });
      return (
        '<section class="rhc-col' + (s.terminal ? ' is-terminal' : '') + '" data-stage="' + s.value + '" aria-label="Etapa ' + esc(s.label) + ', ' + list.length + ' candidatura(s)">' +
        '<header style="--stage:' + s.color + '"><strong>' + esc(s.label) + '</strong><span class="rhc-count">' + list.length + '</span></header>' +
        '<div class="rhc-col-body" data-drop="' + s.value + '">' + (list.length ? list.map(function (a) { return card(ctx, a); }).join('') : '<p class="rhc-col-empty">Solte uma candidatura aqui</p>') + '</div></section>'
      );
    }).join('');
    var note =
      ctx.actor.role === 'manager'
        ? '<p class="rhc-note rhc-note-info">' + UI.icon('shield') + '<span>Gestor contratante: você vê só as candidaturas das suas vagas, dá nota e move entre as etapas de entrevista. As demais etapas são do recrutamento.</span></p>'
        : '<p class="rhc-note rhc-note-info">' + UI.icon('info') + '<span>Arraste um cartão ou use o menu "Mover para". A máquina de etapas valida a transição e pede motivo ou nota quando a regra exige.</span></p>';
    return (
      '<div class="rhc-toolbar">' + UI.field({ id: 'rec-job', label: 'Vaga', type: 'select', value: job.id, options: jobs.map(function (j) { return { value: j.id, label: j.title + ' · ' + j.status }; }), attrs: 'data-change="rec.job"', cls: 'rhc-inline-field' }) +
      '<div class="rhc-chips">' + UI.badge(job.status, job.status === 'Aberta' ? 'success' : 'warning') + UI.badge(job.publishOnPortal ? 'Publicada no portal' : 'Não publicada', job.publishOnPortal ? 'info' : 'neutral', 'globe') + UI.badge(Q.deptName(ctx.st, job.dept), 'neutral', 'building') + '</div></div>' +
      note + '<div class="rhc-kanban" id="rhc-kanban">' + cols + '</div>' +
      UI.card('Resumo da vaga', summaryHtml(ctx, job, apps), { icon: 'chart' })
    );
  }

  function jobsHtml(ctx) {
    var jobs = A.recruiting.visibleJobs(ctx.st, ctx.actor);
    var staff = isStaff(ctx);
    return '<div class="rhc-joblist">' + jobs.map(function (j) {
      var n = ctx.st.applications.filter(function (a) { return a.jobId === j.id; }).length;
      var open = ctx.st.applications.filter(function (a) { return a.jobId === j.id && !R.stage(a.stage).terminal; }).length;
      var closed = j.status === 'Fechada' || j.status === 'Cancelada';
      var hm = Q.emp(ctx.st, j.hiringManager);
      return (
        '<article class="rhc-job"><header>' + UI.icon('briefcase') + '<div><strong>' + esc(j.title) + '</strong><small>' + esc(Q.deptName(ctx.st, j.dept)) + ' · ' + esc(j.location) + ' · ' + esc(j.workModel) + '</small></div>' + UI.badge(j.status, j.status === 'Aberta' ? 'success' : closed ? 'neutral' : 'warning') + '</header>' +
        '<dl class="rhc-kvlist rhc-kvlist-inline">' + UI.kv('Gestor contratante', esc(hm ? hm.name : '-')) + UI.kv('Candidaturas', n + ' (' + open + ' ativas)') + UI.kv('Vagas', String(j.openings)) + UI.kv('Portal', j.publishOnPortal ? 'Publicada' : 'Não publicada') + UI.kv('Slug público', '<code>' + esc(j.slug) + '</code>') + '</dl>' +
        (staff && !closed ? '<footer class="rhc-actions">' +
          '<button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="rec.status" data-id="' + j.id + '" data-to="' + (j.status === 'Aberta' ? 'Pausada' : 'Aberta') + '">' + UI.icon(j.status === 'Aberta' ? 'clock' : 'play') + (j.status === 'Aberta' ? 'Pausar' : 'Reabrir') + '</button>' +
          '<button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="rec.publish" data-id="' + j.id + '">' + UI.icon('globe') + (j.publishOnPortal ? 'Despublicar do portal' : 'Publicar no portal') + '</button>' +
          '<button type="button" class="rhc-btn rhc-btn-danger-ghost rhc-btn-sm" data-act="rec.close" data-id="' + j.id + '">' + UI.icon('x') + 'Encerrar vaga</button></footer>' : '') + '</article>'
      );
    }).join('') + '</div>';
  }

  function lgpdHtml(ctx) {
    var st = ctx.st;
    var elig = st.candidates.filter(function (c) { return R.shouldAnonymize(c, st.applications, st.today, st.settings.candidateRetentionDays); });
    var done = st.candidates.filter(function (c) { return c.anonymized; });
    return (
      '<p class="rhc-lead">Candidatos não contratados, sem candidatura ativa e parados há mais de <strong>' + st.settings.candidateRetentionDays + ' dias</strong> são anonimizados pela rotina semanal. Quem foi contratado nunca é anonimizado.</p>' +
      '<div class="rhc-kpis"><div class="rhc-kpi">' + UI.icon('clock') + '<div><strong>' + elig.length + '</strong><span>elegível(is) agora</span></div></div><div class="rhc-kpi">' + UI.icon('shield') + '<div><strong>' + done.length + '</strong><span>já anonimizado(s)</span></div></div></div>' +
      (elig.length ? '<ul class="rhc-abslist">' + elig.map(function (c) { return '<li>' + UI.avatar(c.name) + '<span><strong>' + esc(c.name) + '</strong> · última atividade em ' + U.fmtBR(c.lastActivity) + '</span>' + UI.badge('Elegível', 'warning', 'clock') + '</li>'; }).join('') + '</ul>' : UI.empty('check', 'Nenhum candidato elegível', 'Todos os candidatos estão dentro do prazo de retenção ou têm candidatura ativa.')) +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-primary" data-act="rec.retention"' + (elig.length ? '' : ' disabled') + '>' + UI.icon('shield') + 'Executar a rotina de retenção (simulada)</button></div>' +
      (done.length ? '<h5 class="rhc-subtitle">Registros anonimizados</h5><ul class="rhc-abslist">' + done.map(function (c) { return '<li>' + UI.icon('lock') + '<span><strong>' + esc(c.name) + '</strong> · <code>' + esc(c.email) + '</code></span>' + UI.badge('Anonimizado', 'neutral', 'shield') + '</li>'; }).join('') + '</ul>' : '')
    );
  }

  RH.views.recruiting = {
    render: function (ctx) {
      resetFor(ctx);
      var staff = isStaff(ctx);
      var tabs = [['board', 'Funil', 'board'], ['jobs', 'Vagas', 'briefcase']];
      if (staff) tabs.push(['lgpd', 'Retenção LGPD', 'shield']);
      if (!tabs.some(function (t) { return t[0] === local.tab; })) local.tab = 'board';
      var nav = '<div class="rhc-tabs" role="tablist" aria-label="Seções do recrutamento">' + tabs.map(function (t) {
        return '<button type="button" role="tab" class="rhc-tab' + (local.tab === t[0] ? ' is-active' : '') + '" aria-selected="' + (local.tab === t[0]) + '" data-act="rec.tab" data-id="' + t[0] + '">' + UI.icon(t[2]) + t[1] + '</button>';
      }).join('') + '</div>';
      var body = local.tab === 'board' ? boardHtml(ctx) : local.tab === 'jobs' ? UI.card('Vagas', jobsHtml(ctx), { icon: 'briefcase', cls: 'rhc-mt0' }) : UI.card('Retenção de dados (LGPD)', lgpdHtml(ctx), { icon: 'shield', cls: 'rhc-mt0' });
      return UI.pageHead('Recrutamento', 'Funil por vaga, com as regras de etapa do produto e candidaturas vindas do portal público.') + nav + '<div role="tabpanel">' + body + '</div>';
    }
  };

  // ---------------------------------------------------------------- movimentacao
  function reasonOptions() {
    return R.REJECTION_REASONS.map(function (r) { return { value: r.value, label: r.label }; });
  }
  function doMove(appId, to, extra, silentToast) {
    var r = RH.store.act(function (st, actor) { return A.recruiting.move(st, actor, appId, to, extra); });
    if (r.ok) {
      var cand = Q.candidateById(RH.store.state, Q.appById(RH.store.state, appId).candidateId);
      var msg = cand.name + ' movido para ' + R.label(to) + '.';
      if (r.hired && r.hired.created) msg += ' Colaborador ' + r.hired.employeeNum + ' criado em pré-admissão, com plano de onboarding de 8 tarefas.';
      UI.toast(msg, 'success');
      return true;
    }
    return r;
  }
  function requestMove(appId, to) {
    var app = Q.appById(RH.store.state, appId);
    var cand = Q.candidateById(RH.store.state, app.candidateId);
    var res = doMove(appId, to, {});
    if (res === true) return;
    if (res.needs && res.needs.length) {
      var body = '';
      if (res.needs.indexOf('reason') >= 0) body += UI.field({ id: 'mv-reason', name: 'reason', label: 'Motivo da reprovação', type: 'select', required: true, value: '', options: [{ value: '', label: 'Selecione…' }].concat(reasonOptions()) });
      if (res.needs.indexOf('score') >= 0) body += UI.field({ id: 'mv-score', name: 'score', label: 'Nota do candidato (0 a 5)', type: 'select', required: true, value: '', options: [{ value: '', label: 'Selecione…' }, { value: '0', label: '0' }, { value: '1', label: '1' }, { value: '2', label: '2' }, { value: '3', label: '3' }, { value: '4', label: '4' }, { value: '5', label: '5' }] });
      UI.modal({
        title: 'Mover ' + cand.name + ' para ' + R.label(to),
        body: '<p class="rhc-muted">' + esc(res.error) + '</p>' + body,
        confirm: 'Confirmar movimentação',
        onConfirm: function (d) {
          var r2 = doMove(appId, to, { reason: d.reason || undefined, score: d.score === '' || d.score === undefined ? undefined : d.score });
          return r2 === true ? true : r2.error;
        }
      });
      return;
    }
    UI.toast(res.error, 'danger');
  }

  function openDetail(appId) {
    var st = RH.store.state;
    var app = Q.appById(st, appId);
    var cand = Q.candidateById(st, app.candidateId);
    var job = Q.jobById(st, app.jobId);
    var hist = st.stageHistory.filter(function (h) { return h.appId === appId; });
    var ctx = RH.app.ctx();
    var canScore = A.recruiting.canAccess(st, ctx.actor, app);
    var scoreBtns = [0, 1, 2, 3, 4, 5].map(function (n) { return '<button type="button" class="rhc-chip' + (app.score === n ? ' is-active' : '') + '" data-act="rec.score" data-app="' + appId + '" data-n="' + n + '" aria-pressed="' + (app.score === n) + '">' + n + '</button>'; }).join('');
    UI.modal({
      title: cand.name,
      wide: true,
      cancel: false,
      confirm: 'Fechar',
      body:
        '<p class="rhc-muted">' + esc(job.title) + ' · etapa atual: <strong>' + esc(R.label(app.stage)) + '</strong> há ' + R.daysInStage(app.stageEntered, st.today) + ' dia(s)</p>' +
        '<dl class="rhc-kvlist rhc-kvlist-inline">' + UI.kv('E-mail', esc(cand.email)) + UI.kv('Telefone', esc(cand.phone || '-')) + UI.kv('Cidade', esc(cand.city || '-')) + UI.kv('Origem', esc(app.source)) +
        UI.kv('Consentimento LGPD', cand.consent ? 'Sim, versão ' + esc(cand.consentVersion) + ' em ' + U.fmtBR(cand.consentDate) : 'Não') + '</dl>' +
        (app.coverLetter ? '<p class="rhc-note rhc-note-info">' + UI.icon('mail') + '<span>' + esc(app.coverLetter) + '</span></p>' : '') +
        (canScore ? '<div class="rhc-scorebox"><span>Nota:</span>' + scoreBtns + '</div>' : '') +
        '<h5 class="rhc-subtitle">Histórico de etapas</h5><ol class="rhc-timeline">' + hist.map(function (h) {
          return '<li><span class="rhc-timeline-dot"></span><div><strong>' + (h.from ? esc(R.label(h.from)) + ' para ' : 'Entrada em ') + esc(R.label(h.to)) + '</strong><small>' + U.fmtBR(h.at) + (h.daysInPrev !== null && h.from ? ' · ' + h.daysInPrev + ' dia(s) na etapa anterior' : '') + (h.note ? ' · ' + esc(h.note) : '') + '</small></div></li>';
        }).join('') + '</ol>',
      onConfirm: function () { return true; }
    });
  }

  UI.on('rec.tab', function (el) {
    local.tab = el.getAttribute('data-id');
    RH.app.render();
  });
  UI.on('rec.job', function (el) {
    local.job = el.value;
    RH.app.render();
  });
  UI.on('rec.open', function (el) {
    openDetail(el.getAttribute('data-app'));
  });
  UI.on('rec.moveSel', function (el) {
    var to = el.value;
    var id = el.getAttribute('data-app');
    el.value = '';
    if (to) requestMove(id, to);
  });
  UI.on('rec.score', function (el) {
    var id = el.getAttribute('data-app');
    var n = el.getAttribute('data-n');
    var r = RH.store.act(function (st, actor) { return A.recruiting.setScore(st, actor, id, n); });
    UI.toast(r.ok ? 'Nota ' + n + ' registrada.' : r.error, r.ok ? 'success' : 'danger');
    if (r.ok) {
      UI.closeModal();
      openDetail(id);
    }
  });
  UI.on('rec.status', function (el) {
    var r = RH.store.act(function (st, actor) { return A.recruiting.setJobStatus(st, actor, el.getAttribute('data-id'), el.getAttribute('data-to')); });
    UI.toast(r.ok ? 'Status da vaga atualizado.' : r.error, r.ok ? 'success' : 'danger');
  });
  UI.on('rec.publish', function (el) {
    var r = RH.store.act(function (st, actor) { return A.recruiting.togglePublish(st, actor, el.getAttribute('data-id')); });
    UI.toast(r.ok ? (r.published ? 'Vaga publicada no portal público.' : 'Vaga retirada do portal.') : r.error, r.ok ? 'success' : 'danger');
  });
  UI.on('rec.close', function (el) {
    var id = el.getAttribute('data-id');
    var job = Q.jobById(RH.store.state, id);
    var open = RH.store.state.applications.filter(function (a) { return a.jobId === id && !R.stage(a.stage).terminal; }).length;
    UI.modal({
      title: 'Encerrar a vaga "' + job.title + '"',
      tone: 'danger',
      confirm: 'Encerrar vaga',
      body: '<p>' + open + ' candidatura(s) ativa(s) serão reprovadas com o motivo "Outro" e o histórico "Vaga encerrada". A vaga sai do portal.</p>' + UI.field({ id: 'cl-status', name: 'status', label: 'Encerrar como', type: 'select', value: 'Fechada', options: [{ value: 'Fechada', label: 'Fechada (preenchida)' }, { value: 'Cancelada', label: 'Cancelada' }] }),
      onConfirm: function (d) {
        var r = RH.store.act(function (st, actor) { return A.recruiting.closeJob(st, actor, id, d.status); });
        if (!r.ok) return r.error;
        UI.toast('Vaga encerrada. ' + r.rejected + ' candidatura(s) reprovada(s) automaticamente.', 'warning');
        return true;
      }
    });
  });
  UI.on('rec.retention', function () {
    var r = RH.store.act(function (st, actor) { return A.recruiting.runRetention(st, actor); });
    UI.toast(r.ok ? r.count + ' candidato(s) anonimizado(s). Nome, e-mail, telefone e cidade foram apagados.' : r.error, r.ok ? 'success' : 'danger');
  });

  // ---------------------------------------------------------------- arrastar e soltar
  RH.views.recruiting.bind = function (root) {
    function colOf(ev) {
      return ev.target.closest && ev.target.closest('[data-drop]');
    }
    function clear() {
      Array.prototype.forEach.call(root.querySelectorAll('.rhc-col'), function (c) {
        c.classList.remove('is-allowed', 'is-blocked', 'is-over');
      });
    }
    root.addEventListener('dragstart', function (ev) {
      var cardEl = ev.target.closest && ev.target.closest('.rhc-kcard');
      if (!cardEl) return;
      local.dragId = cardEl.getAttribute('data-app');
      ev.dataTransfer.setData('text/plain', local.dragId);
      ev.dataTransfer.effectAllowed = 'move';
      cardEl.classList.add('is-dragging');
      var app = Q.appById(RH.store.state, local.dragId);
      Array.prototype.forEach.call(root.querySelectorAll('.rhc-col'), function (c) {
        var to = c.getAttribute('data-stage');
        var ok = R.stage(app.stage).next.indexOf(to) >= 0;
        c.classList.add(ok ? 'is-allowed' : 'is-blocked');
      });
    });
    root.addEventListener('dragend', function () {
      local.dragId = null;
      clear();
      Array.prototype.forEach.call(root.querySelectorAll('.is-dragging'), function (c) { c.classList.remove('is-dragging'); });
    });
    root.addEventListener('dragover', function (ev) {
      var col = colOf(ev);
      if (!col || !local.dragId) return;
      ev.preventDefault();
      ev.dataTransfer.dropEffect = 'move';
      var sec = col.closest('.rhc-col');
      Array.prototype.forEach.call(root.querySelectorAll('.rhc-col.is-over'), function (c) { if (c !== sec) c.classList.remove('is-over'); });
      sec.classList.add('is-over');
    });
    root.addEventListener('drop', function (ev) {
      var col = colOf(ev);
      if (!col || !local.dragId) return;
      ev.preventDefault();
      var id = local.dragId;
      var to = col.getAttribute('data-drop');
      clear();
      local.dragId = null;
      var app = Q.appById(RH.store.state, id);
      if (app.stage === to) return;
      requestMove(id, to);
    });
  };
  RH.views.recruiting.setTab = function (t) {
    local.tab = t;
  };
  RH.views.recruiting.reset = function () {
    local.persona = null;
    local.job = 'JOB-1';
  };
  RH.views.recruiting.focusJob = function (job) {
    local.job = job;
    local.tab = 'board';
  };
})(globalThis);
