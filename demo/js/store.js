/* RH Core demo: estado compartilhado da demonstracao (memoria + localStorage). Todas as personas leem e
   escrevem o mesmo estado: o que o candidato envia aparece no funil do recrutador. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    ['util', 'rules-leave', 'rules-approval', 'rules-recruiting', 'rules-visibility', 'data'].forEach(function (m) { require('./' + m + '.js'); });
  }
  var RH = (g.RH = g.RH || {});
  var KEY = 'rhcore-demo-v3';
  var state = null;
  var ui = null;
  var subs = [];

  function defaultUi() {
    return { persona: 'colaborador', view: 'home', tourOpen: false, tourStep: {}, sel: {} };
  }
  function storage() {
    try {
      return g.localStorage || null;
    } catch (e) {
      return null;
    }
  }
  function load() {
    var ls = storage();
    try {
      var raw = ls && ls.getItem(KEY);
      if (raw) {
        var o = JSON.parse(raw);
        if (o && o.state && o.state.version === 3) {
          state = o.state;
          ui = Object.assign(defaultUi(), o.ui || {});
          return;
        }
      }
    } catch (e) {
      /* localStorage indisponivel ou corrompido: segue com o estado inicial */
    }
    state = RH.seed.build();
    ui = defaultUi();
  }
  function save() {
    var ls = storage();
    try {
      if (ls) ls.setItem(KEY, JSON.stringify({ state: state, ui: ui }));
    } catch (e) {
      /* sem persistencia: a demo continua em memoria */
    }
  }
  function emit() {
    subs.forEach(function (fn) { fn(); });
  }

  RH.store = {
    init: function () {
      load();
      return this;
    },
    get state() {
      return state;
    },
    get ui() {
      return ui;
    },
    actor: function () {
      return RH.visibility.actorFor(ui.persona);
    },
    /** Executa uma acao sobre o estado, persiste e notifica a interface. Retorna o que a acao devolver. */
    act: function (fn) {
      var r = fn(state, this.actor());
      save();
      emit();
      return r;
    },
    /** Muda so a interface (persona, tela, selecao). */
    setUi: function (fn) {
      fn(ui);
      save();
      emit();
    },
    setPersona: function (key) {
      ui.persona = key;
      ui.view = RH.visibility.DEFAULT_VIEW[key];
      save();
      emit();
    },
    setView: function (view) {
      ui.view = view;
      save();
      emit();
    },
    /** Reinicia os dados e a interface. */
    reset: function () {
      var keepTour = ui ? ui.tourOpen : false;
      state = RH.seed.build();
      ui = defaultUi();
      ui.tourOpen = keepTour;
      save();
      emit();
    },
    subscribe: function (fn) {
      subs.push(fn);
    }
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.store;
})(globalThis);
