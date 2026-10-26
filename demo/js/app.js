/* RH Core demo: casca da aplicacao (persona, navegacao, roteiro guiado, reinicio) e renderizacao. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var V = RH.visibility;
  var NOTICE = 'Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.';
  var root = null;
  var FOCUS_ATTRS = ['data-act', 'data-id', 'data-num', 'data-app', 'data-slug', 'data-plan', 'data-task', 'data-p', 'data-mode', 'data-view', 'data-job', 'data-kind', 'data-to', 'data-change'];

  function ctx() {
    var st = RH.store.state;
    var ui = RH.store.ui;
    return { st: st, ui: ui, persona: ui.persona, actor: RH.store.actor() };
  }

  function focusSelector(el) {
    if (!el || el === document.body) return null;
    if (el.id) return '#' + el.id;
    var parts = FOCUS_ATTRS.filter(function (a) { return el.hasAttribute && el.hasAttribute(a); }).map(function (a) { return '[' + a + '="' + el.getAttribute(a) + '"]'; });
    return parts.length ? el.tagName.toLowerCase() + parts.join('') : null;
  }

  // ---------------------------------------------------------------- casca
  function shellHtml() {
    return (
      '<div class="rhc-shell">' +
      '<div class="rhc-notice" role="note">' + UI.icon('shield') + '<span><strong>' + esc(NOTICE) + '</strong></span></div>' +
      '<header class="rhc-top"><div class="rhc-brand"><span class="rhc-logo" aria-hidden="true">' + UI.icon('team') + '</span><div><strong>RH Core</strong><small>Vetra Distribuidora · empresa fictícia</small></div></div>' +
      '<div class="rhc-top-actions"><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="app.tour" aria-expanded="false" id="rhc-tour-btn">' + UI.icon('play') + 'Roteiro guiado</button>' +
      '<button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="app.reset">' + UI.icon('refresh') + 'Reiniciar demo</button></div></header>' +
      '<section class="rhc-personabar" aria-label="Escolha a persona"><p class="rhc-personabar-label">Ver o produto como</p><div class="rhc-personas" id="rhc-personas"></div><p class="rhc-personactx" id="rhc-personactx" aria-live="polite"></p></section>' +
      '<nav class="rhc-nav" id="rhc-nav" aria-label="Seções do produto"></nav>' +
      '<div class="rhc-layout"><aside class="rhc-tourpanel" id="rhc-tour" aria-label="Roteiro guiado" hidden></aside><main id="rhc-main" tabindex="-1"></main></div>' +
      '<footer class="rhc-foot"><p>' + UI.icon('info') + 'As regras de férias seguem a CLT vigente com parâmetros configuráveis; convenção coletiva pode alterá-las, e o produto não substitui orientação jurídica. Data fixa da demonstração: ' + U.fmtBR(U.TODAY) + '.</p></footer>' +
      '</div><div id="rhc-toasts" role="status" aria-live="polite"></div><div id="rhc-modal-root"></div>'
    );
  }

  function personasHtml(c) {
    return V.PERSONA_ORDER.map(function (k) {
      var p = V.PERSONAS[k];
      var on = c.persona === k;
      return '<button type="button" class="rhc-persona' + (on ? ' is-active' : '') + '" data-act="app.persona" data-id="' + k + '" aria-pressed="' + on + '">' + UI.icon(p.icon) + '<span><strong>' + esc(p.label) + '</strong><small>' + esc(p.desc) + '</small></span></button>';
    }).join('');
  }

  function navHtml(c) {
    return V.NAV[c.persona].map(function (v) {
      var m = V.VIEW_META[v];
      var on = c.ui.view === v;
      var badge = '';
      if (v === 'approvals') {
        var n = RH.q.inbox(c.st, c.actor).filter(function (i) { return i.canDecide; }).length;
        if (n) badge = '<span class="rhc-navcount" aria-label="' + n + ' pendente(s)">' + n + '</span>';
      }
      return '<button type="button" class="rhc-navbtn' + (on ? ' is-active' : '') + '" data-act="app.nav" data-view="' + v + '"' + (on ? ' aria-current="page"' : '') + '>' + UI.icon(m.icon) + '<span>' + esc(m.label) + '</span>' + badge + '</button>';
    }).join('');
  }

  function tourHtml(c) {
    var tour = RH.tour.TOURS[c.persona];
    var i = c.ui.tourStep[c.persona] || 0;
    var step = tour.steps[i];
    var list = tour.steps.map(function (s, k) {
      return '<li><button type="button" class="rhc-tourstep' + (k === i ? ' is-current' : '') + (k < i ? ' is-done' : '') + '" data-act="tour.goto" data-id="' + k + '"' + (k === i ? ' aria-current="step"' : '') + '><span>' + (k < i ? UI.icon('check') : k + 1) + '</span>' + esc(s.title) + '</button></li>';
    }).join('');
    return (
      '<div class="rhc-tour-head"><div><p class="rhc-eyebrow">Roteiro guiado</p><h3>' + esc(tour.title) + '</h3></div><button type="button" class="rhc-iconbtn" data-act="app.tour" aria-label="Fechar roteiro">' + UI.icon('x') + '</button></div>' +
      '<div class="rhc-tour-now"><p class="rhc-eyebrow">Passo ' + (i + 1) + ' de ' + tour.steps.length + '</p><h4>' + esc(step.title) + '</h4><p>' + esc(step.text) + '</p>' +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="tour.prev"' + (i === 0 ? ' disabled' : '') + '>' + UI.icon('chevronLeft') + 'Anterior</button>' +
      '<button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="tour.go">' + UI.icon('target') + 'Ir para esta tela</button>' +
      '<button type="button" class="rhc-btn rhc-btn-primary rhc-btn-sm" data-act="tour.next"' + (i === tour.steps.length - 1 ? ' disabled' : '') + '>Próximo' + UI.icon('chevronRight') + '</button></div></div>' +
      '<ol class="rhc-tourlist">' + list + '</ol>'
    );
  }

  function render() {
    var c = ctx();
    var prev = document.activeElement;
    var sel = prev && root.contains(prev) ? focusSelector(prev) : null;
    var caret = prev && prev.selectionStart !== undefined ? prev.selectionStart : null;

    root.querySelector('#rhc-personas').innerHTML = personasHtml(c);
    var p = V.PERSONAS[c.persona];
    var me = p.empNum ? RH.q.emp(c.st, p.empNum) : null;
    root.querySelector('#rhc-personactx').innerHTML = (me ? 'Você está como <strong>' + esc(me.name) + '</strong> (' + esc(p.label) + ').' : 'Você é um <strong>visitante</strong> do portal, sem login.') + ' Hoje na demo: segunda-feira, ' + U.fmtBR(c.st.today) + '.';
    root.querySelector('#rhc-nav').innerHTML = navHtml(c);

    var main = root.querySelector('#rhc-main');
    var view = RH.views[c.ui.view];
    if (!view || V.NAV[c.persona].indexOf(c.ui.view) < 0) {
      c.ui.view = V.DEFAULT_VIEW[c.persona];
      view = RH.views[c.ui.view];
    }
    try {
      main.innerHTML = view.render(c);
    } catch (err) {
      if (g.console) console.error(err);
      main.innerHTML = UI.card('Erro ao montar a tela', '<p class="rhc-error">Algo deu errado ao montar esta tela. Use "Reiniciar demo" para voltar ao estado inicial.</p><pre>' + esc(String(err && err.message)) + '</pre>');
    }
    var tourEl = root.querySelector('#rhc-tour');
    tourEl.hidden = !c.ui.tourOpen;
    if (c.ui.tourOpen) tourEl.innerHTML = tourHtml(c);
    root.querySelector('#rhc-tour-btn').setAttribute('aria-expanded', c.ui.tourOpen ? 'true' : 'false');
    root.classList.toggle('has-tour', !!c.ui.tourOpen);

    if (sel) {
      var el = null;
      try {
        el = root.querySelector(sel);
      } catch (e) {
        el = null;
      }
      if (el && el !== document.activeElement && !el.disabled) {
        el.focus({ preventScroll: true });
        if (caret !== null && el.setSelectionRange && /^(text|search|number|email|url|tel)$/.test(el.type || '')) {
          try {
            el.setSelectionRange(caret, caret);
          } catch (e2) {
            /* tipos sem selecao */
          }
        }
      }
    }
  }

  function focusTitle() {
    var t = root.querySelector('#rhc-page-title');
    if (t) t.focus({ preventScroll: false });
  }

  // ---------------------------------------------------------------- roteiro
  function goStep(persona, index) {
    var tour = RH.tour.TOURS[persona];
    var step = tour.steps[index];
    RH.store.setUi(function (ui) {
      ui.tourStep[persona] = index;
      ui.persona = persona;
      ui.view = step.go.view;
    });
    var view = RH.views[step.go.view];
    if (step.go.job && RH.views.recruiting.focusJob) RH.views.recruiting.focusJob(step.go.job);
    if (step.go.tab && view) (view.setTab || view.openTab || function () {})(step.go.tab);
    render();
    focusTitle();
  }

  UI.on('app.persona', function (el) {
    RH.store.setPersona(el.getAttribute('data-id'));
    focusTitle();
  });
  UI.on('app.nav', function (el) {
    RH.store.setView(el.getAttribute('data-view'));
    focusTitle();
  });
  UI.on('app.tour', function () {
    RH.store.setUi(function (ui) {
      ui.tourOpen = !ui.tourOpen;
    });
  });
  UI.on('tour.go', function () {
    var c = ctx();
    goStep(c.persona, c.ui.tourStep[c.persona] || 0);
  });
  UI.on('tour.next', function () {
    var c = ctx();
    var i = (c.ui.tourStep[c.persona] || 0) + 1;
    if (i < RH.tour.TOURS[c.persona].steps.length) goStep(c.persona, i);
  });
  UI.on('tour.prev', function () {
    var c = ctx();
    var i = (c.ui.tourStep[c.persona] || 0) - 1;
    if (i >= 0) goStep(c.persona, i);
  });
  UI.on('tour.goto', function (el) {
    goStep(ctx().persona, parseInt(el.getAttribute('data-id'), 10));
  });
  UI.on('app.reset', function () {
    UI.modal({
      title: 'Reiniciar a demonstração?',
      body: '<p>Todos os dados voltam ao estado inicial: pedidos, aprovações, candidaturas e avaliações que você criou serão descartados.</p>',
      confirm: 'Reiniciar demo',
      tone: 'danger',
      onConfirm: function () {
        Object.keys(RH.views).forEach(function (k) {
          if (RH.views[k].reset) RH.views[k].reset();
        });
        RH.store.reset();
        UI.toast('Demo reiniciada. Os dados voltaram ao estado inicial.', 'success');
        return true;
      }
    });
  });

  RH.app = {
    ctx: ctx,
    render: render,
    init: function (el) {
      root = el;
      RH.store.init();
      root.classList.add('rhc');
      root.innerHTML = shellHtml();
      UI.mount(root);
      Object.keys(RH.views).forEach(function (k) {
        if (RH.views[k].bind) RH.views[k].bind(root);
      });
      RH.store.subscribe(render);
      render();
    }
  };
})(globalThis);
