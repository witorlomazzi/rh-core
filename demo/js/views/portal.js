/* RH Core demo: portal publico de vagas (spec 14). Mesmo estado do recrutador: a candidatura enviada aparece no funil. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var A = RH.actions;

  var local = { slug: null, filters: { model: '', dept: '', q: '' }, values: {}, errors: {}, renderedAt: 0, done: null, formError: '', sim: null, simOpen: false };

  function jobs(ctx) {
    var f = local.filters;
    var q = f.q.trim().toLowerCase();
    return A.recruiting.portalJobs(ctx.st).filter(function (j) {
      return (!f.model || j.workModel === f.model) && (!f.dept || j.department === f.dept) && (!q || (j.title + ' ' + j.department).toLowerCase().indexOf(q) >= 0);
    });
  }

  function listHtml(ctx) {
    var all = A.recruiting.portalJobs(ctx.st);
    var models = {};
    var depts = {};
    all.forEach(function (j) {
      models[j.workModel] = true;
      depts[j.department] = true;
    });
    var shown = jobs(ctx);
    var modelLabel = { Presencial: 'Presencial', Hibrido: 'Híbrido', Remoto: 'Remoto' };
    var filters =
      '<div class="rhc-toolbar rhc-portal-filters" role="search">' +
      UI.field({ id: 'pf-q', label: 'Buscar vaga', type: 'search', value: local.filters.q, attrs: 'data-input="portal.filter" placeholder="Título ou área"', cls: 'rhc-inline-field' }) +
      UI.field({ id: 'pf-model', label: 'Modelo de trabalho', type: 'select', value: local.filters.model, options: [{ value: '', label: 'Todos' }].concat(Object.keys(models).map(function (m) { return { value: m, label: modelLabel[m] || m }; })), attrs: 'data-change="portal.filter"', cls: 'rhc-inline-field' }) +
      UI.field({ id: 'pf-dept', label: 'Área', type: 'select', value: local.filters.dept, options: [{ value: '', label: 'Todas' }].concat(Object.keys(depts).map(function (d) { return { value: d, label: d }; })), attrs: 'data-change="portal.filter"', cls: 'rhc-inline-field' }) +
      '</div>';
    var cards = shown.length
      ? '<div class="rhc-pjobs">' + shown.map(function (j) {
          return (
            '<article class="rhc-pjob"><header>' + UI.icon('briefcase') + '<div><h3>' + esc(j.title) + '</h3><p>' + esc(j.department) + '</p></div></header>' +
            '<div class="rhc-chips">' + UI.badge(modelLabel[j.workModel] || j.workModel, 'info', 'building') + UI.badge(j.location, 'neutral', 'pin') + UI.badge(j.employmentType, 'neutral') + '</div>' +
            '<p class="rhc-pjob-desc">' + esc(j.description) + '</p>' +
            '<footer><small>Publicada em ' + U.fmtBR(j.openedDate) + '</small><button type="button" class="rhc-btn rhc-btn-primary" data-act="portal.open" data-slug="' + esc(j.slug) + '">Ver vaga e candidatar-se' + UI.icon('arrowRight') + '</button></footer></article>'
          );
        }).join('') + '</div>'
      : UI.empty('search', 'Nenhuma vaga com esses filtros', 'Limpe os filtros para ver todas as vagas abertas.');
    return '<div id="rhc-portal-list">' + filters + '<p class="rhc-muted" role="status" id="rhc-portal-count">' + shown.length + (shown.length === 1 ? ' vaga aberta' : ' vagas abertas') + '</p><div id="rhc-portal-cards">' + cards + '</div></div>';
  }

  function formHtml(ctx, job) {
    var v = local.values;
    var e = local.errors;
    var err = local.formError ? '<p class="rhc-error" role="alert">' + esc(local.formError) + '</p>' : '';
    return (
      '<form class="rhc-form" data-submit="portal.submit" novalidate>' +
      '<div class="rhc-grid-form">' +
      UI.field({ id: 'ap-name', name: 'name', label: 'Nome completo', value: v.name || '', required: true, error: e.name, attrs: 'data-input="portal.value" autocomplete="name"' }) +
      UI.field({ id: 'ap-email', name: 'email', label: 'E-mail', type: 'email', value: v.email || '', required: true, error: e.email, attrs: 'data-input="portal.value" autocomplete="email"' }) +
      UI.field({ id: 'ap-phone', name: 'phone', label: 'Telefone', type: 'tel', value: v.phone || '', error: e.phone, attrs: 'data-input="portal.value" autocomplete="tel"' }) +
      UI.field({ id: 'ap-city', name: 'city', label: 'Cidade', value: v.city || '', error: e.city, attrs: 'data-input="portal.value"' }) +
      UI.field({ id: 'ap-linkedin', name: 'linkedin', label: 'LinkedIn (endereço completo)', type: 'url', value: v.linkedin || '', error: e.linkedin, attrs: 'data-input="portal.value" placeholder="https://"', cls: 'rhc-col-2' }) +
      UI.field({ id: 'ap-message', name: 'message', label: 'Mensagem para o time', type: 'textarea', rows: 4, value: v.message || '', error: e.message, attrs: 'data-input="portal.value"', cls: 'rhc-col-2', help: 'Sem upload de currículo nesta versão.' }) +
      '</div>' +
      '<div class="rhc-honey" aria-hidden="true"><label for="ap-website">Não preencha este campo</label><input id="ap-website" name="website" type="text" tabindex="-1" autocomplete="off" value=""></div>' +
      '<div class="rhc-consent"><h4>' + UI.icon('shield') + 'Privacidade e LGPD <small>(versão ' + esc(ctx.st.settings.consentVersion) + ')</small></h4><p>' + esc(RH.portal.CONSENT_TEXT) + '</p>' +
      UI.field({ id: 'ap-consent', name: 'consent', type: 'checkbox', value: !!v.consent, label: 'Li e concordo com o termo de privacidade.', error: e.consent, required: true, attrs: 'data-change="portal.value"' }) + '</div>' +
      err + '<div class="rhc-actions"><button type="submit" class="rhc-btn rhc-btn-primary">' + UI.icon('send') + 'Enviar candidatura</button><button type="button" class="rhc-btn rhc-btn-ghost" data-act="portal.back">Voltar às vagas</button></div></form>'
    );
  }

  function detailHtml(ctx) {
    var job = A.recruiting.portalJobs(ctx.st).filter(function (j) { return j.slug === local.slug; })[0];
    if (!job) {
      local.slug = null;
      return listHtml(ctx);
    }
    if (local.done) {
      var d = local.done;
      return (
        '<div class="rhc-success" role="status">' + UI.icon('check') + '<h3>' + esc(d.message) + '</h3><p>Você se candidatou a <strong>' + esc(job.title) + '</strong>. O time de recrutamento da Vetra (empresa fictícia) entra em contato se o perfil avançar.</p></div>' +
        (d.app ? '<div class="rhc-backstage">' + UI.icon('inbox') + '<div><strong>Nos bastidores (visível só nesta demo)</strong><p>A candidatura <code>' + esc(d.app.id) + '</code> foi criada na etapa <strong>Nova</strong>, com origem Portal e o consentimento da versão ' + esc(ctx.st.settings.consentVersion) + ' registrado. Ela já está no funil do recrutador, na fila de recrutamento.</p>' +
          '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-primary" data-act="portal.seeFunnel" data-job="' + esc(d.app.jobId) + '">' + UI.icon('board') + 'Ver no funil como Recrutador</button><button type="button" class="rhc-btn rhc-btn-ghost" data-act="portal.back">Voltar às vagas</button></div></div></div>'
          : '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-ghost" data-act="portal.back">Voltar às vagas</button></div>')
      );
    }
    return (
      '<button type="button" class="rhc-link rhc-backlink" data-act="portal.back">' + UI.icon('chevronLeft') + 'Todas as vagas</button>' +
      '<article class="rhc-pdetail"><header><h3>' + esc(job.title) + '</h3><div class="rhc-chips">' + UI.badge(job.department, 'neutral', 'building') + UI.badge(job.location, 'neutral', 'pin') + UI.badge(job.workModel === 'Hibrido' ? 'Híbrido' : job.workModel, 'info') + UI.badge(job.employmentType, 'neutral') + '</div></header>' +
      '<h4>Sobre a vaga</h4><p>' + esc(job.description) + '</p><h4>Requisitos</h4><p>' + esc(job.requirements) + '</p><p class="rhc-muted">Publicada em ' + U.fmtBR(job.openedDate) + '</p></article>' +
      '<h4 class="rhc-form-title">Candidate-se</h4>' + formHtml(ctx, job)
    );
  }

  // ---------------------------------------------------------------- simulacao de seguranca
  function simPanel(ctx) {
    var st = ctx.st;
    var logRows = st.portal.log.length
      ? '<ul class="rhc-abslist">' + st.portal.log.slice(0, 6).map(function (l) {
          var tone = l.kind === 'gravada' ? 'success' : l.kind === 'descartada' ? 'warning' : 'danger';
          return '<li>' + UI.icon(l.kind === 'gravada' ? 'check' : l.kind === 'descartada' ? 'bot' : 'ban') + '<span>' + esc(l.text) + '</span>' + UI.badge(l.kind === 'gravada' ? 'Gravada' : l.kind === 'descartada' ? 'Descartada em silêncio' : 'Rejeitada', tone) + '</li>';
        }).join('') + '</ul>'
      : '<p class="rhc-muted">O registro de eventos aparece aqui conforme você testa.</p>';
    var sim = local.sim
      ? '<div class="rhc-simresult" role="status"><div><small>O que o visitante vê</small><strong>' + esc(local.sim.visible) + '</strong></div><div><small>O que o servidor fez</small><strong>' + esc(local.sim.server) + '</strong></div></div>'
      : '';
    return (
      '<details class="rhc-sim"' + (local.simOpen ? ' open' : '') + ' data-toggle="portal.sim"><summary>' + UI.icon('shield') + 'Como o portal se defende (simulação de segurança)</summary>' +
      '<p class="rhc-muted">Estes botões enviam candidaturas forjadas ao mesmo serviço do formulário. Nenhuma delas é gravada.</p>' +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="portal.simBot">' + UI.icon('bot') + 'Enviar como robô (campo oculto preenchido)</button>' +
      '<button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="portal.simFast">' + UI.icon('clock') + 'Enviar rápido demais (menos de ' + st.settings.portalMinSubmitSeconds + ' s)</button>' +
      '<button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="portal.simLimit">' + UI.icon('ban') + 'Simular limite diário (' + st.settings.portalDailyLimit + ' candidaturas hoje)</button>' +
      '<button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="portal.simReset">Limpar simulação</button></div>' + sim +
      '<h5 class="rhc-subtitle">Registro do servidor</h5>' + logRows + '</details>'
    );
  }

  RH.views.portal = {
    render: function (ctx) {
      var isPublic = ctx.persona === 'candidato';
      var body = local.slug ? detailHtml(ctx) : listHtml(ctx);
      var frame =
        '<div class="rhc-portal"><div class="rhc-portal-bar">' + UI.icon('building') + '<strong>Vagas Vetra</strong><span>Portal público · sem login</span></div><div class="rhc-portal-body">' + body + '</div></div>';
      return (
        UI.pageHead('Portal de vagas', isPublic ? 'Você é um visitante, sem login. Veja as vagas abertas e candidate-se.' : 'Pré-visualização do portal público que o candidato usa, sem login.') +
        (isPublic ? '' : '<p class="rhc-note rhc-note-info">' + UI.icon('globe') + '<span>Qualquer pessoa acessa esta página. Para ver como o candidato, troque para a persona <strong>Candidato</strong>; o que ele enviar aparece no funil do recrutador.</span></p>') +
        frame + simPanel(ctx)
      );
    }
  };

  function readValues(form) {
    var d = UI.formData(form);
    local.values = { name: d.name, email: d.email, phone: d.phone, city: d.city, linkedin: d.linkedin, message: d.message, consent: d.consent };
    return d;
  }

  UI.on('portal.open', function (el) {
    local.slug = el.getAttribute('data-slug');
    local.errors = {};
    local.formError = '';
    local.done = null;
    local.renderedAt = Date.now();
    RH.app.render();
    var t = UI.root().querySelector('#rhc-page-title');
    if (t) t.focus();
  });
  UI.on('portal.back', function () {
    local.slug = null;
    local.done = null;
    local.errors = {};
    local.formError = '';
    RH.app.render();
  });
  UI.on('portal.filter', function (el) {
    var id = el.id;
    if (id === 'pf-q') local.filters.q = el.value;
    if (id === 'pf-model') local.filters.model = el.value;
    if (id === 'pf-dept') local.filters.dept = el.value;
    // atualiza so a lista, para nao perder o foco do campo de busca
    var ctx = RH.app.ctx();
    var host = document.getElementById('rhc-portal-list');
    if (host) {
      var tmp = document.createElement('div');
      tmp.innerHTML = listHtml(ctx);
      var cards = tmp.querySelector('#rhc-portal-cards');
      var count = tmp.querySelector('#rhc-portal-count');
      host.querySelector('#rhc-portal-cards').innerHTML = cards.innerHTML;
      host.querySelector('#rhc-portal-count').textContent = count.textContent;
    }
  });
  UI.on('portal.value', function (el) {
    var form = el.closest('form');
    if (form) readValues(form);
  });
  UI.on('portal.submit', function (form) {
    var d = readValues(form);
    var res = RH.store.act(function (st) {
      return A.recruiting.portalSubmit(st, { slug: local.slug, name: d.name, email: d.email, phone: d.phone, city: d.city, linkedin: d.linkedin, message: d.message, consent: d.consent === true, website: d.website, renderedAt: local.renderedAt }, Date.now());
    });
    local.errors = res.fieldErrors || {};
    if (!res.ok) {
      local.formError = Object.keys(local.errors).length ? '' : res.message;
      if (Object.keys(local.errors).length) local.formError = res.message;
      RH.app.render();
      var firstErr = UI.root().querySelector('.has-error input, .has-error textarea');
      if (firstErr) firstErr.focus();
      return;
    }
    local.formError = '';
    local.done = { message: res.message, app: res.silent ? null : res.application };
    local.values = {};
    RH.app.render();
    var t = UI.root().querySelector('#rhc-page-title');
    if (t) t.focus();
  });
  UI.on('portal.seeFunnel', function (el) {
    RH.views.recruiting.focusJob(el.getAttribute('data-job'));
    RH.store.setUi(function (ui) {
      ui.persona = 'recrutador';
      ui.view = 'recruiting';
    });
  });

  function simSubmit(label, mutate) {
    var st = RH.store.state;
    var job = A.recruiting.portalJobs(st)[0];
    var base = { slug: local.slug || job.slug, name: local.values.name || 'Visitante de Teste', email: local.values.email || 'visitante.teste@mail.example', phone: '', city: '', linkedin: '', message: '', consent: true, website: '', renderedAt: Date.now() - 20000 };
    var input = mutate(base, st);
    var before = RH.store.state.applications.length;
    var res = RH.store.act(function (s) { return A.recruiting.portalSubmit(s, input, Date.now()); });
    var after = RH.store.state.applications.length;
    local.simOpen = true;
    local.sim = {
      visible: res.ok ? 'Sucesso: "' + res.message + '"' : 'Erro: "' + res.message + '"',
      server: after === before ? 'Nada foi gravado (' + label + ').' : 'Gravou uma candidatura.'
    };
    RH.app.render();
  }
  UI.on('portal.simBot', function () {
    simSubmit('honeypot preenchido, resposta falsa de sucesso para o robô', function (b) { b.website = 'https://spam.example'; return b; });
  });
  UI.on('portal.simFast', function () {
    simSubmit('envio abaixo do tempo mínimo', function (b) { b.renderedAt = Date.now() - 400; return b; });
  });
  UI.on('portal.simLimit', function () {
    simSubmit('limite diário por e-mail', function (b, st) {
      st.portal.boost[b.email.trim().toLowerCase()] = st.settings.portalDailyLimit;
      return b;
    });
  });
  UI.on('portal.simReset', function () {
    RH.store.act(function (st) { st.portal.boost = {}; st.portal.log = []; });
    local.sim = null;
    UI.toast('Simulação limpa.', 'info');
  });
  RH.views.portal.bind = function (root) {
    root.addEventListener('toggle', function (ev) {
      if (ev.target.matches && ev.target.matches('details[data-toggle="portal.sim"]')) local.simOpen = ev.target.open;
    }, true);
  };
  RH.views.portal.reset = function () {
    local.slug = null;
    local.values = {};
    local.errors = {};
    local.done = null;
    local.sim = null;
    local.simOpen = false;
    local.filters = { model: '', dept: '', q: '' };
  };
})(globalThis);
