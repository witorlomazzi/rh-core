/* RH Core demo: componentes de interface compartilhados (HTML em string, eventos por delegacao). */
(function (g) {
  'use strict';
  var RH = (g.RH = g.RH || {});
  var U = RH.util;
  var esc = U.esc;
  var handlers = {};
  var rootEl = null;
  var lastFocus = null;

  function icon(name, cls) {
    return RH.icons.html(name, cls);
  }

  /** tone: neutral | info | success | warning | danger */
  function badge(text, tone, iconName) {
    return '<span class="rhc-badge rhc-badge-' + (tone || 'neutral') + '">' + (iconName ? icon(iconName) : '') + esc(text) + '</span>';
  }
  function avatar(name, tone) {
    var palette = ['a', 'b', 'c', 'd', 'e'];
    var h = 0;
    for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 5;
    return '<span class="rhc-avatar rhc-avatar-' + (tone || palette[h]) + '" aria-hidden="true">' + esc(U.initials(name)) + '</span>';
  }
  function card(title, body, opts) {
    opts = opts || {};
    return (
      '<section class="rhc-card' + (opts.cls ? ' ' + opts.cls : '') + '"' + (opts.id ? ' id="' + opts.id + '"' : '') + (opts.label ? ' aria-label="' + esc(opts.label) + '"' : '') + '>' +
      (title
        ? '<header class="rhc-card-head"><h3>' + (opts.icon ? icon(opts.icon) : '') + '<span>' + esc(title) + '</span></h3>' + (opts.actions ? '<div class="rhc-card-actions">' + opts.actions + '</div>' : '') + '</header>'
        : '') +
      '<div class="rhc-card-body">' + body + '</div></section>'
    );
  }
  function empty(iconName, title, text) {
    return '<div class="rhc-empty">' + icon(iconName || 'info') + '<strong>' + esc(title) + '</strong>' + (text ? '<p>' + esc(text) + '</p>' : '') + '</div>';
  }
  function pageHead(title, sub, actions) {
    return '<div class="rhc-pagehead"><div><h2 tabindex="-1" id="rhc-page-title">' + esc(title) + '</h2>' + (sub ? '<p>' + sub + '</p>' : '') + '</div>' + (actions ? '<div class="rhc-pagehead-actions">' + actions + '</div>' : '') + '</div>';
  }
  /** Valor protegido por FLS: o campo existe, mas esta mascarado para esta persona. */
  function locked(label) {
    return '<span class="rhc-locked" title="Campo restrito por FLS: somente os permission sets de RH leem este valor.">' + icon('lock') + '<span class="rhc-locked-dots" aria-hidden="true">R$ ••••••</span><span class="rhc-sr">' + esc(label || 'Salário restrito ao RH') + '</span></span>';
  }
  function salaryCell(value, canSee) {
    if (value === null || value === undefined || value === '') return '<span class="rhc-muted">-</span>';
    return canSee ? '<strong class="rhc-money">' + esc(U.brl(value)) + '</strong>' : locked('Salário restrito ao RH');
  }
  function kv(label, valueHtml) {
    return '<div class="rhc-kv"><dt>' + esc(label) + '</dt><dd>' + valueHtml + '</dd></div>';
  }

  /** field: { id, label, type, value, help, options, attrs, required, rows, cls } */
  function field(f) {
    var id = f.id;
    var req = f.required ? ' required' : '';
    var attrs = f.attrs ? ' ' + f.attrs : '';
    var help = f.help ? '<small class="rhc-help" id="' + id + '-help">' + f.help + '</small>' : '';
    var desc = f.help ? ' aria-describedby="' + id + '-help"' : '';
    var control;
    if (f.type === 'select') {
      control =
        '<select id="' + id + '" name="' + (f.name || id) + '"' + req + desc + attrs + '>' +
        (f.options || []).map(function (o) {
          return '<option value="' + esc(o.value) + '"' + (String(o.value) === String(f.value) ? ' selected' : '') + (o.disabled ? ' disabled' : '') + '>' + esc(o.label) + '</option>';
        }).join('') + '</select>';
    } else if (f.type === 'textarea') {
      control = '<textarea id="' + id + '" name="' + (f.name || id) + '" rows="' + (f.rows || 3) + '"' + req + desc + attrs + '>' + esc(f.value || '') + '</textarea>';
    } else if (f.type === 'checkbox') {
      return (
        '<div class="rhc-field rhc-field-check' + (f.cls ? ' ' + f.cls : '') + '"><label for="' + id + '"><input type="checkbox" id="' + id + '" name="' + (f.name || id) + '"' + (f.value ? ' checked' : '') + req + desc + attrs + '><span>' + f.label + '</span></label>' + help + (f.error ? '<small class="rhc-error" role="alert">' + esc(f.error) + '</small>' : '') + '</div>'
      );
    } else {
      control = '<input id="' + id + '" name="' + (f.name || id) + '" type="' + (f.type || 'text') + '" value="' + esc(f.value === undefined || f.value === null ? '' : f.value) + '"' + req + desc + attrs + '>';
    }
    return (
      '<div class="rhc-field' + (f.cls ? ' ' + f.cls : '') + (f.error ? ' has-error' : '') + '"><label for="' + id + '">' + esc(f.label) + (f.required ? ' <span aria-hidden="true">*</span>' : '') + '</label>' + control + help + (f.error ? '<small class="rhc-error" role="alert">' + esc(f.error) + '</small>' : '') + '</div>'
    );
  }

  function formData(form) {
    var out = {};
    Array.prototype.forEach.call(form.elements, function (el) {
      if (!el.name) return;
      if (el.type === 'checkbox') out[el.name] = el.checked;
      else if (el.type === 'radio') {
        if (el.checked) out[el.name] = el.value;
      } else out[el.name] = el.value;
    });
    return out;
  }

  // ---------------------------------------------------------------- toast e modal
  function toast(msg, tone) {
    if (!rootEl) return;
    var host = rootEl.querySelector('#rhc-toasts');
    if (!host) return;
    var el = document.createElement('div');
    el.className = 'rhc-toast rhc-toast-' + (tone || 'info');
    el.innerHTML = icon(tone === 'danger' ? 'ban' : tone === 'success' ? 'check' : tone === 'warning' ? 'warning' : 'info') + '<span>' + esc(msg) + '</span>';
    host.appendChild(el);
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
    }, tone === 'danger' ? 7000 : 4800);
  }

  function closeModal() {
    var host = rootEl && rootEl.querySelector('#rhc-modal-root');
    if (host) host.innerHTML = '';
    if (lastFocus && lastFocus.focus && document.contains(lastFocus)) lastFocus.focus();
    lastFocus = null;
  }
  /** opts: { title, body, confirm, cancel, tone, wide, onConfirm(data) -> true | mensagem de erro } */
  function modal(opts) {
    var host = rootEl.querySelector('#rhc-modal-root');
    lastFocus = document.activeElement;
    host.innerHTML =
      '<div class="rhc-modal-backdrop" data-act="ui.modal.backdrop">' +
      '<div class="rhc-modal' + (opts.wide ? ' rhc-modal-wide' : '') + '" role="dialog" aria-modal="true" aria-labelledby="rhc-modal-title">' +
      '<form novalidate data-modal-form>' +
      '<header><h3 id="rhc-modal-title">' + esc(opts.title) + '</h3><button type="button" class="rhc-iconbtn" data-act="ui.modal.close" aria-label="Fechar">' + icon('x') + '</button></header>' +
      '<div class="rhc-modal-body">' + opts.body + '<p class="rhc-error rhc-modal-error" role="alert" hidden></p></div>' +
      '<footer>' +
      (opts.cancel === false ? '' : '<button type="button" class="rhc-btn rhc-btn-ghost" data-act="ui.modal.close">' + esc(opts.cancel || 'Cancelar') + '</button>') +
      '<button type="submit" class="rhc-btn ' + (opts.tone === 'danger' ? 'rhc-btn-danger' : 'rhc-btn-primary') + '">' + esc(opts.confirm || 'Confirmar') + '</button>' +
      '</footer></form></div></div>';
    var form = host.querySelector('form');
    var err = host.querySelector('.rhc-modal-error');
    form.addEventListener('submit', function (ev) {
      ev.preventDefault();
      var r = opts.onConfirm ? opts.onConfirm(formData(form)) : true;
      if (r === true) {
        closeModal();
      } else {
        err.textContent = r || 'Não foi possível concluir.';
        err.hidden = false;
      }
    });
    var first = form.querySelector('input:not([type=hidden]), select, textarea') || form.querySelector('button[type=submit]');
    if (first) first.focus();
  }

  // ---------------------------------------------------------------- eventos
  function on(name, fn) {
    handlers[name] = fn;
  }
  function mount(root) {
    rootEl = root;
    root.addEventListener('click', function (ev) {
      var el = ev.target.closest && ev.target.closest('[data-act]');
      if (!el || !root.contains(el)) return;
      var fn = handlers[el.getAttribute('data-act')];
      if (fn) {
        if (el.tagName === 'A') ev.preventDefault();
        fn(el, ev);
      }
    });
    root.addEventListener('change', function (ev) {
      var el = ev.target.closest && ev.target.closest('[data-change]');
      if (el && handlers[el.getAttribute('data-change')]) handlers[el.getAttribute('data-change')](el, ev);
    });
    root.addEventListener('input', function (ev) {
      var el = ev.target.closest && ev.target.closest('[data-input]');
      if (el && handlers[el.getAttribute('data-input')]) handlers[el.getAttribute('data-input')](el, ev);
    });
    root.addEventListener('submit', function (ev) {
      var form = ev.target.closest && ev.target.closest('form[data-submit]');
      if (form && handlers[form.getAttribute('data-submit')]) {
        ev.preventDefault();
        handlers[form.getAttribute('data-submit')](form, ev);
      }
    });
    root.addEventListener('keydown', function (ev) {
      if (ev.key === 'Escape' && root.querySelector('.rhc-modal')) {
        closeModal();
        return;
      }
      var el = ev.target.closest && ev.target.closest('[data-key]');
      if (el && handlers[el.getAttribute('data-key')]) handlers[el.getAttribute('data-key')](el, ev);
    });
    on('ui.modal.close', function () {
      closeModal();
    });
    on('ui.modal.backdrop', function (el, ev) {
      if (ev.target === el) closeModal();
    });
  }

  // ---------------------------------------------------------------- tons por status
  var LEAVE_TONE = { Rascunho: 'neutral', Pendente: 'warning', Aprovado: 'success', Rejeitado: 'danger', Cancelado: 'neutral', Em_Gozo: 'info', Concluido: 'neutral', Efetivado: 'success' };
  var LEAVE_ICON = { Rascunho: 'edit', Pendente: 'clock', Aprovado: 'check', Rejeitado: 'x', Cancelado: 'ban', Em_Gozo: 'sun', Concluido: 'check', Efetivado: 'award' };
  var PERIOD_TONE = { Em_Aquisicao: 'neutral', Disponivel: 'success', Prazo_Proximo: 'warning', Concluido: 'neutral', Perdido: 'danger' };
  var PERIOD_ICON = { Em_Aquisicao: 'clock', Disponivel: 'check', Prazo_Proximo: 'warning', Concluido: 'check', Perdido: 'ban' };
  function statusBadge(status, label) {
    return badge(label || status, LEAVE_TONE[status] || 'neutral', LEAVE_ICON[status]);
  }
  function periodBadge(status) {
    return badge(RH.leave.PERIOD_STATUS_LABEL[status] || status, PERIOD_TONE[status] || 'neutral', PERIOD_ICON[status]);
  }
  function checkIcon(status) {
    if (status === 'blocking') return '<span class="rhc-check rhc-check-blocking">' + icon('ban') + '</span>';
    if (status === 'warning') return '<span class="rhc-check rhc-check-warning">' + icon('warning') + '</span>';
    return '<span class="rhc-check rhc-check-ok">' + icon('check') + '</span>';
  }

  RH.ui = {
    esc: esc,
    icon: icon,
    badge: badge,
    avatar: avatar,
    card: card,
    empty: empty,
    pageHead: pageHead,
    locked: locked,
    salaryCell: salaryCell,
    kv: kv,
    field: field,
    formData: formData,
    toast: toast,
    modal: modal,
    closeModal: closeModal,
    on: on,
    mount: mount,
    statusBadge: statusBadge,
    periodBadge: periodBadge,
    checkIcon: checkIcon,
    root: function () {
      return rootEl;
    }
  };
  RH.views = RH.views || {};
})(globalThis);
