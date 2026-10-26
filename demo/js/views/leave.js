/* RH Core demo: ferias CLT (spec 11): saldo por periodo, formulario com motor de regras V1 a V12,
   pedidos com etapas de aprovacao, calendario da equipe e prazos concessivos para o RH. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var V = RH.visibility;
  var A = RH.actions;
  var L = RH.leave;

  var local = {
    persona: null,
    tab: 'mine',
    form: null,
    results: null,
    checkedKey: '',
    showHistory: false,
    cal: { year: 2026, month: 12 },
    calManager: 'VTR-0007',
    onlyUrgent: false
  };

  function nextMonday(iso) {
    var d = iso;
    while (U.dow(d) !== 1) d = U.addDays(d, 1);
    return d;
  }

  function eligiblePeriods(ctx, empNum) {
    return Q.periodsOf(ctx.st, empNum).filter(function (x) {
      return !x.period.historical && !x.period.lost && x.status !== 'Concluido';
    });
  }

  function resetFor(ctx) {
    if (local.persona === ctx.persona) return;
    local.persona = ctx.persona;
    local.tab = 'mine';
    local.results = null;
    local.form = null;
    local.cal = { year: 2026, month: 12 };
    local.calManager = V.PERSONAS[ctx.persona].role === 'manager' ? V.PERSONAS[ctx.persona].empNum : 'VTR-0007';
  }

  function defaultForm(ctx, empNum) {
    var periods = eligiblePeriods(ctx, empNum).filter(function (x) { return x.status !== 'Em_Aquisicao'; });
    var first = periods.length ? periods[0] : null;
    var start = nextMonday(U.addDays(ctx.st.today, 36));
    if (empNum === 'VTR-0015') start = '2026-12-14';
    return { empNum: empNum, periodKey: first ? first.period.key : '', start: start, days: 14, sold: 0, exception: false, requestId: '' };
  }
  function ensureForm(ctx) {
    var me = V.PERSONAS[ctx.persona].empNum;
    if (!local.form || (ctx.persona !== 'rh' && local.form.empNum !== me)) {
      local.form = defaultForm(ctx, ctx.persona === 'rh' && local.form ? local.form.empNum : me);
      local.results = null;
    }
    return local.form;
  }
  function formKey(f) {
    return [f.empNum, f.periodKey, f.start, f.days, f.sold, f.exception].join('|');
  }

  // ---------------------------------------------------------------- pecas
  function periodCard(ctx, item) {
    var p = item.period;
    var b = item.bal;
    var pct = p.entitled ? Math.max(0, Math.min(100, Math.round(((p.entitled - b.balance) / p.entitled) * 100))) : 100;
    var daysLeft = U.diffDays(ctx.st.today, p.concessionDeadline);
    var deadlineTone = item.status === 'Prazo_Proximo' ? ' rhc-warn-text' : '';
    return (
      '<article class="rhc-period' + (item.status === 'Prazo_Proximo' ? ' is-urgent' : '') + (item.status === 'Perdido' ? ' is-lost' : '') + '" aria-label="Período aquisitivo ' + U.fmtBR(p.start) + ' a ' + U.fmtBR(p.end) + '">' +
      '<header><span class="rhc-period-icon">' + UI.icon('calendar') + '</span><div><strong>' + U.fmtBR(p.start) + ' a ' + U.fmtBR(p.end) + '</strong><small>Período aquisitivo</small></div>' + UI.periodBadge(item.status) + '</header>' +
      '<div class="rhc-period-balance"><span class="rhc-big">' + b.balance + '</span><span>dia(s) de saldo<small> de ' + p.entitled + ' de direito' + (p.absences ? ' (' + p.absences + ' faltas injustificadas, art. 130)' : '') + '</small></span></div>' +
      '<div class="rhc-meter" role="img" aria-label="' + pct + '% do direito já utilizado ou reservado"><span style="width:' + pct + '%"></span></div>' +
      '<dl class="rhc-mini"><div><dt>Gozados</dt><dd>' + b.taken + '</dd></div><div><dt>Pendentes</dt><dd>' + b.pending + '</dd></div><div><dt>Abono</dt><dd>' + b.sold + '</dd></div></dl>' +
      (item.status === 'Em_Aquisicao' ? '<p class="rhc-muted rhc-period-foot">Em aquisição até ' + U.fmtBR(p.end) + '. Ainda não é possível solicitar.</p>'
        : item.status === 'Perdido' ? '<p class="rhc-period-foot rhc-bad-text">Direito perdido: mais de 32 faltas injustificadas.</p>'
        : '<p class="rhc-period-foot' + deadlineTone + '">' + UI.icon(item.status === 'Prazo_Proximo' ? 'warning' : 'clock') + 'Prazo concessivo até <strong>' + U.fmtBR(p.concessionDeadline) + '</strong> (' + (daysLeft >= 0 ? daysLeft + ' dias' : 'vencido') + ')</p>') +
      '</article>'
    );
  }

  function stepper(ctx, req) {
    if (!req.steps || !req.steps.length) return '<span class="rhc-muted">Ainda não enviado</span>';
    return '<ol class="rhc-stepper" aria-label="Etapas de aprovação">' + req.steps.map(function (s) {
      var label = s.type === 'HR_Team' ? 'RH' : s.approver ? Q.firstName((Q.emp(ctx.st, s.approver) || {}).name) : 'Gestor';
      var tone = s.skipped ? 'neutral' : s.status === 'Aprovado' ? 'success' : s.status === 'Rejeitado' ? 'danger' : s.status === 'Pendente' ? (req.step === s.order ? 'warning' : 'neutral') : 'neutral';
      var ic = s.skipped ? 'minus' : s.status === 'Aprovado' ? 'check' : s.status === 'Rejeitado' ? 'x' : s.status === 'Pendente' ? 'clock' : 'ban';
      var txt = s.skipped ? 'pulada' : s.status === 'Aprovado' ? 'aprovou' : s.status === 'Rejeitado' ? 'rejeitou' : s.status === 'Pendente' ? (req.step === s.order ? 'aguardando' : 'em seguida') : 'encerrada';
      return '<li class="rhc-step rhc-step-' + tone + '">' + UI.icon(ic) + '<span><strong>' + esc(label) + '</strong> ' + txt + '</span></li>';
    }).join('') + '</ol>';
  }

  function requestRow(ctx, req, showWho) {
    var p = req.periodKey.split('|')[1];
    var who = showWho ? Q.emp(ctx.st, req.empNum) : null;
    var rej = req.steps.filter(function (s) { return s.status === 'Rejeitado' && s.comments; })[0];
    var actions = '';
    var actor = ctx.actor;
    if (req.status === 'Pendente' && req.requestedBy === actor.empNum) {
      actions += '<button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="leave.cancel" data-id="' + req.id + '">' + UI.icon('ban') + 'Cancelar pedido</button>';
    }
    if (req.status === 'Rascunho' && (req.empNum === actor.empNum || actor.role === 'hr')) {
      actions += '<button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="leave.editDraft" data-id="' + req.id + '">' + UI.icon('edit') + 'Abrir no formulário</button>' +
        '<button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="leave.delDraft" data-id="' + req.id + '">' + UI.icon('trash') + 'Excluir</button>';
    }
    return (
      '<article class="rhc-reqrow"><header><div class="rhc-reqrow-id">' + UI.icon('calendar') + '<div><strong>' + esc(req.id) + '</strong><small>' + (who ? esc(who.name) + ' · ' : '') + 'período de ' + U.fmtBR(p) + '</small></div></div>' + UI.statusBadge(req.status, L.REQUEST_STATUS_LABEL[req.status]) + '</header>' +
      '<div class="rhc-reqrow-body"><div class="rhc-reqrow-dates"><strong>' + U.fmtBR(req.start) + ' a ' + U.fmtBR(L.requestEnd(req)) + '</strong><span>' + req.days + ' dia(s) de gozo' + (req.sold ? ' + ' + req.sold + ' de abono' : '') + '</span></div>' + '<div>' + stepper(ctx, req) + '</div></div>' +
      (req.conflict ? '<p class="rhc-note rhc-note-warn">' + UI.icon('warning') + '<span>' + esc(req.conflict) + '</span></p>' : '') +
      (rej ? '<p class="rhc-note rhc-note-bad">' + UI.icon('x') + '<span><strong>Motivo da rejeição:</strong> ' + esc(rej.comments) + '</span></p>' : '') +
      (req.notes ? '<p class="rhc-muted rhc-req-notes">' + esc(req.notes) + '</p>' : '') +
      (actions ? '<footer class="rhc-actions">' + actions + '</footer>' : '') + '</article>'
    );
  }

  function ruleList(results) {
    return '<ul class="rhc-rules" aria-label="Resultado das regras de férias">' + results.map(function (r) {
      return '<li class="rhc-rule rhc-rule-' + r.status + '">' + UI.checkIcon(r.status) + '<div><strong>' + esc(r.label) + '</strong><span>' + esc(r.message) + '</span></div>' +
        UI.badge(r.status === 'ok' ? 'OK' : r.status === 'warning' ? 'Aviso' : 'Bloqueio', r.status === 'ok' ? 'success' : r.status === 'warning' ? 'warning' : 'danger') + '</li>';
    }).join('') + '</ul>';
  }

  function formHtml(ctx) {
    var f = ensureForm(ctx);
    var actor = ctx.actor;
    var periods = eligiblePeriods(ctx, f.empNum);
    var emp = Q.emp(ctx.st, f.empNum);
    var opts = periods.map(function (x) {
      return { value: x.period.key, label: U.fmtBR(x.period.start) + ' a ' + U.fmtBR(x.period.end) + ' · saldo ' + x.bal.balance + ' · ' + L.PERIOD_STATUS_LABEL[x.status] };
    });
    if (!periods.some(function (x) { return x.period.key === f.periodKey; })) f.periodKey = opts.length ? opts[0].value : '';
    var hrPick = '';
    if (actor.role === 'hr') {
      var cands = ctx.st.employees.filter(function (e) { return e.type === 'CLT' && e.status !== 'Desligado' && e.status !== 'Pre_Admissao'; }).sort(function (a, b) { return a.name < b.name ? -1 : 1; });
      hrPick = UI.field({ id: 'lv-emp', name: 'empNum', label: 'Solicitar em nome de', type: 'select', value: f.empNum, options: cands.map(function (e) { return { value: e.num, label: e.name + ' (' + e.num + ')' }; }), attrs: 'data-change="leave.field"', cls: 'rhc-col-2' });
    }
    var checked = local.results && local.checkedKey === formKey(f);
    var summary = checked ? L.summarize(local.results) : null;
    var presets =
      '<div class="rhc-presets" role="group" aria-label="Cenários prontos"><span>Testar um cenário:</span>' +
      '<button type="button" class="rhc-chip" data-act="leave.preset" data-p="ok">Pedido válido</button>' +
      '<button type="button" class="rhc-chip" data-act="leave.preset" data-p="friday">Começar numa sexta</button>' +
      '<button type="button" class="rhc-chip" data-act="leave.preset" data-p="short">Fração de 4 dias</button>' +
      '<button type="button" class="rhc-chip" data-act="leave.preset" data-p="abono">Abono de 11 dias</button>' +
      '<button type="button" class="rhc-chip" data-act="leave.preset" data-p="holiday">Véspera de feriado</button></div>';
    var form =
      '<form class="rhc-form" data-submit="leave.submit" novalidate>' +
      '<div class="rhc-grid-form">' + hrPick +
      UI.field({ id: 'lv-period', name: 'periodKey', label: 'Período aquisitivo', type: 'select', value: f.periodKey, options: opts.length ? opts : [{ value: '', label: 'Nenhum período disponível' }], attrs: 'data-change="leave.field"', cls: 'rhc-col-2' }) +
      UI.field({ id: 'lv-start', name: 'start', label: 'Início das férias', type: 'date', value: f.start, attrs: 'data-change="leave.field"', required: true }) +
      UI.field({ id: 'lv-days', name: 'days', label: 'Dias de gozo', type: 'number', value: f.days, attrs: 'min="1" max="30" step="1" data-change="leave.field"', required: true }) +
      UI.field({ id: 'lv-sold', name: 'sold', label: 'Abono pecuniário (dias vendidos)', type: 'number', value: f.sold, attrs: 'min="0" max="10" step="1" data-change="leave.field"', help: 'Até 1/3 do direito do período (art. 143).' }) +
      (actor.role === 'hr' ? UI.field({ id: 'lv-exc', name: 'exception', label: 'Exceção de antecedência (somente RH)', type: 'checkbox', value: f.exception, attrs: 'data-change="leave.field"' }) : '') +
      '</div>' + presets +
      '<div class="rhc-actions">' +
      '<button type="submit" class="rhc-btn rhc-btn-secondary" data-mode="check">' + UI.icon('shield') + 'Verificar regras</button>' +
      '<button type="button" class="rhc-btn rhc-btn-ghost" data-act="leave.draft">' + UI.icon('edit') + 'Salvar rascunho</button>' +
      '<button type="button" class="rhc-btn rhc-btn-primary" data-act="leave.send"' + (checked && summary.canSubmit ? '' : ' disabled') + '>' + UI.icon('send') + 'Enviar para aprovação</button></div>' +
      (checked ? '' : '<p class="rhc-muted rhc-form-hint">Verifique as regras antes de enviar. O envio só habilita quando não há bloqueios.</p>') +
      '</form>';
    var res = '';
    if (checked) {
      res =
        '<div class="rhc-result" aria-live="polite"><div class="rhc-result-head">' +
        (summary.canSubmit
          ? UI.badge(summary.warnings.length ? 'Pode enviar, com ' + summary.warnings.length + ' aviso(s)' : 'Pode enviar', summary.warnings.length ? 'warning' : 'success', summary.warnings.length ? 'warning' : 'check')
          : UI.badge(summary.blocking.length + ' regra(s) bloqueando o envio', 'danger', 'ban')) +
        '<small>' + esc(emp.name) + ' · ' + f.days + ' dia(s) a partir de ' + U.fmtBR(f.start) + '</small></div>' + ruleList(local.results) + '</div>';
    }
    return form + res;
  }

  function mineHtml(ctx) {
    var me = V.PERSONAS[ctx.persona].empNum;
    var e = Q.emp(ctx.st, me);
    if (!e || e.type !== 'CLT') {
      return UI.empty('info', 'Sem períodos aquisitivos', e ? 'O vínculo de ' + (e.type === 'Estagio' ? 'estágio' : e.type) + ' não gera férias CLT.' : 'Esta persona não tem cadastro de colaborador.');
    }
    var periods = Q.periodsOf(ctx.st, me);
    var active = periods.filter(function (x) { return !x.period.historical; });
    var hist = periods.filter(function (x) { return x.period.historical; });
    var reqs = ctx.st.leaveRequests.filter(function (r) { return r.empNum === me; }).sort(function (a, b) { return a.start < b.start ? 1 : -1; });
    return (
      UI.card('Meus períodos aquisitivos', '<div class="rhc-periods">' + active.map(function (x) { return periodCard(ctx, x); }).join('') + '</div>' +
        (hist.length ? '<p class="rhc-muted rhc-hist-note">' + UI.icon('check') + hist.length + ' período(s) anteriores já quitados (prazo concessivo encerrado).</p>' : ''), { icon: 'calendar', cls: 'rhc-mt0' }) +
      UI.card('Solicitar férias', '<p class="rhc-lead">Escolha as datas e veja, antes de enviar, qual regra da CLT cada escolha respeita ou quebra.</p>' + formHtml(ctx), { icon: 'send' }) +
      UI.card('Meus pedidos', reqs.length ? '<div class="rhc-reqlist">' + reqs.map(function (r) { return requestRow(ctx, r, false); }).join('') + '</div>' : UI.empty('calendar', 'Nenhum pedido ainda', 'Quando você enviar um pedido, ele aparece aqui com as etapas de aprovação.'), { icon: 'list' })
    );
  }

  // ---------------------------------------------------------------- calendario da equipe
  function calendarHtml(ctx) {
    var st = ctx.st;
    var role = V.PERSONAS[ctx.persona].role;
    var mgrNum = role === 'manager' ? V.PERSONAS[ctx.persona].empNum : local.calManager;
    var mgr = Q.emp(st, mgrNum);
    var team = Q.directReports(st, mgrNum).filter(function (e) { return e.status !== 'Desligado'; });
    var y = local.cal.year;
    var m = local.cal.month;
    var n = U.daysInMonth(y, m);
    var days = [];
    for (var d = 1; d <= n; d++) days.push(y + '-' + U.pad(m, 2) + '-' + U.pad(d, 2));
    var wk = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    var cover = days.map(function () { return 0; });
    var absences = [];
    var rows = team.map(function (e) {
      var hs = Q.holidaySetFor(st, e);
      var reqs = st.leaveRequests.filter(function (r) { return r.empNum === e.num && ['Pendente', 'Aprovado', 'Em_Gozo', 'Concluido'].indexOf(r.status) >= 0; });
      var cells = days.map(function (iso, i) {
        var rest = st.settings.weeklyRestDays.indexOf(U.dowCode(iso)) >= 0;
        var hol = hs[iso];
        var hit = reqs.filter(function (r) { return iso >= r.start && iso <= L.requestEnd(r); })[0];
        var cls = 'rhc-cal-cell';
        var title = '';
        if (hit) {
          cls += hit.status === 'Pendente' ? ' is-pending' : ' is-leave';
          title = e.name + ': férias ' + L.REQUEST_STATUS_LABEL[hit.status].toLowerCase();
          cover[i]++;
        } else if (hol) {
          cls += ' is-holiday';
          title = hol;
        } else if (rest) {
          cls += ' is-rest';
          title = 'Descanso semanal';
        }
        return '<td class="' + cls + '" title="' + esc(title) + '"></td>';
      }).join('');
      reqs.forEach(function (r) {
        var s = r.start > days[0] ? r.start : days[0];
        var en = L.requestEnd(r) < days[n - 1] ? L.requestEnd(r) : days[n - 1];
        if (s <= en) absences.push({ name: e.name, r: r, s: s, en: en });
      });
      return '<tr><th scope="row" class="rhc-cal-name">' + UI.avatar(e.name) + '<span>' + esc(e.name) + '</span></th>' + cells + '</tr>';
    }).join('');
    var coverRow = '<tr class="rhc-cal-cover"><th scope="row">Ausentes no dia</th>' + cover.map(function (c) {
      return '<td class="' + (c >= 2 ? 'is-conflict' : '') + '" title="' + c + ' pessoa(s) ausente(s)">' + (c ? c : '') + '</td>';
    }).join('') + '</tr>';
    var head = '<tr><th scope="col" class="rhc-cal-corner">Equipe de ' + esc(Q.firstName(mgr.name)) + '</th>' + days.map(function (iso) {
      var rest = st.settings.weeklyRestDays.indexOf(U.dowCode(iso)) >= 0;
      return '<th scope="col" class="rhc-cal-day' + (rest ? ' is-rest' : '') + '"><span>' + wk[U.dow(iso)] + '</span>' + parseInt(iso.slice(8), 10) + '</th>';
    }).join('') + '</tr>';
    var mgrPick = '';
    if (role === 'hr') {
      var mgrs = st.employees.filter(function (e) { return Q.directReports(st, e.num).length > 0; });
      mgrPick = UI.field({ id: 'cal-mgr', label: 'Equipe de', type: 'select', value: mgrNum, options: mgrs.map(function (e) { return { value: e.num, label: e.name + ' (' + Q.deptName(st, e.dept) + ')' }; }), attrs: 'data-change="leave.calMgr"', cls: 'rhc-inline-field' });
    }
    var list = absences.length
      ? '<ul class="rhc-abslist">' + absences.map(function (a) {
          return '<li>' + UI.avatar(a.name) + '<span><strong>' + esc(a.name) + '</strong> · ' + U.fmtBR(a.r.start) + ' a ' + U.fmtBR(L.requestEnd(a.r)) + '</span>' + UI.statusBadge(a.r.status, L.REQUEST_STATUS_LABEL[a.r.status]) + '</li>';
        }).join('') + '</ul>'
      : UI.empty('calendar', 'Nenhuma ausência neste mês', 'Ninguém da equipe direta tem férias registradas no período.');
    return (
      '<div class="rhc-toolbar"><div class="rhc-monthnav"><button type="button" class="rhc-iconbtn" data-act="leave.calPrev" aria-label="Mês anterior">' + UI.icon('chevronLeft') + '</button><strong aria-live="polite">' + esc(U.monthLabel(y, m)) + '</strong><button type="button" class="rhc-iconbtn" data-act="leave.calNext" aria-label="Próximo mês">' + UI.icon('chevronRight') + '</button></div>' + mgrPick + '</div>' +
      '<div class="rhc-cal-wrap"><table class="rhc-cal"><caption class="rhc-sr">Calendário de férias da equipe em ' + esc(U.monthLabel(y, m)) + '</caption><thead>' + head + '</thead><tbody>' + rows + coverRow + '</tbody></table></div>' +
      '<div class="rhc-legend" aria-label="Legenda"><span><i class="lg lg-leave"></i>Férias aprovadas ou em gozo</span><span><i class="lg lg-pending"></i>Pendente de aprovação</span><span><i class="lg lg-holiday"></i>Feriado</span><span><i class="lg lg-rest"></i>Descanso semanal</span><span><i class="lg lg-conflict"></i>Dois ou mais ausentes</span></div>' +
      '<h4 class="rhc-subtitle">Ausências no mês</h4>' + list
    );
  }

  // ---------------------------------------------------------------- prazos (RH)
  function deadlinesHtml(ctx) {
    var st = ctx.st;
    var rows = [];
    st.employees.forEach(function (e) {
      if (e.type !== 'CLT' || e.status === 'Desligado' || e.status === 'Pre_Admissao') return;
      Q.periodsOf(st, e.num).forEach(function (x) {
        if (x.period.historical) return;
        if (x.status === 'Disponivel' || x.status === 'Prazo_Proximo' || x.status === 'Perdido') rows.push({ e: e, x: x });
      });
    });
    rows.sort(function (a, b) {
      return a.x.period.concessionDeadline < b.x.period.concessionDeadline ? -1 : 1;
    });
    var urgent = rows.filter(function (r) { return r.x.status === 'Prazo_Proximo'; });
    var shown = local.onlyUrgent ? urgent : rows;
    var body = shown.map(function (r) {
      var left = U.diffDays(st.today, r.x.period.concessionDeadline);
      return (
        '<tr><td data-label="Colaborador"><strong>' + esc(r.e.name) + '</strong><small class="rhc-cellsub">' + esc(Q.deptName(st, r.e.dept)) + '</small></td>' +
        '<td data-label="Período">' + U.fmtBR(r.x.period.start) + ' a ' + U.fmtBR(r.x.period.end) + '</td>' +
        '<td data-label="Direito">' + r.x.period.entitled + ' d' + (r.x.period.absences ? ' <small class="rhc-muted">(' + r.x.period.absences + ' faltas)</small>' : '') + '</td>' +
        '<td data-label="Saldo"><strong>' + r.x.bal.balance + '</strong> d</td>' +
        '<td data-label="Prazo concessivo">' + U.fmtBR(r.x.period.concessionDeadline) + '</td>' +
        '<td data-label="Restam">' + (r.x.status === 'Perdido' ? '-' : left + ' dias') + '</td>' +
        '<td data-label="Status">' + UI.periodBadge(r.x.status) + '</td></tr>'
      );
    }).join('');
    return (
      '<div class="rhc-kpis"><div class="rhc-kpi">' + UI.icon('warning') + '<div><strong>' + urgent.length + '</strong><span>com prazo concessivo vencendo em até ' + st.settings.concessionWarningDays + ' dias</span></div></div>' +
      '<div class="rhc-kpi">' + UI.icon('calendar') + '<div><strong>' + rows.filter(function (r) { return r.x.status !== 'Perdido'; }).length + '</strong><span>períodos com saldo a tirar</span></div></div>' +
      '<div class="rhc-kpi">' + UI.icon('ban') + '<div><strong>' + rows.filter(function (r) { return r.x.status === 'Perdido'; }).length + '</strong><span>período perdido por faltas (art. 130)</span></div></div></div>' +
      '<div class="rhc-toolbar"><label class="rhc-inline-check"><input type="checkbox" data-change="leave.urgent"' + (local.onlyUrgent ? ' checked' : '') + '> Mostrar só prazo próximo</label></div>' +
      '<div class="rhc-tablewrap"><table class="rhc-table rhc-table-stack"><caption class="rhc-sr">Períodos aquisitivos com saldo</caption><thead><tr><th scope="col">Colaborador</th><th scope="col">Período</th><th scope="col">Direito</th><th scope="col">Saldo</th><th scope="col">Prazo concessivo</th><th scope="col">Restam</th><th scope="col">Status</th></tr></thead><tbody>' + body + '</tbody></table></div>'
    );
  }

  RH.views.leave = {
    render: function (ctx) {
      resetFor(ctx);
      var role = V.PERSONAS[ctx.persona].role;
      var tabs = [['mine', 'Minhas férias', 'calendar']];
      if (role === 'manager' || role === 'hr') tabs.push(['team', 'Calendário da equipe', 'users']);
      if (role === 'hr') tabs.push(['deadlines', 'Prazos concessivos', 'warning']);
      if (!tabs.some(function (t) { return t[0] === local.tab; })) local.tab = 'mine';
      var nav = '<div class="rhc-tabs" role="tablist" aria-label="Seções de férias">' + tabs.map(function (t) {
        return '<button type="button" role="tab" class="rhc-tab' + (local.tab === t[0] ? ' is-active' : '') + '" aria-selected="' + (local.tab === t[0]) + '" data-act="leave.tab" data-id="' + t[0] + '">' + UI.icon(t[2]) + t[1] + '</button>';
      }).join('') + '</div>';
      var body = local.tab === 'mine' ? mineHtml(ctx) : local.tab === 'team' ? UI.card('Calendário da equipe', calendarHtml(ctx), { icon: 'users', cls: 'rhc-mt0' }) : UI.card('Prazos concessivos', deadlinesHtml(ctx), { icon: 'warning', cls: 'rhc-mt0' });
      return UI.pageHead('Férias', 'Regras da CLT (arts. 130, 134, 135, 137 e 143) aplicadas na hora, com a explicação de cada regra.') + nav + '<div role="tabpanel">' + body + '</div>';
    }
  };

  // ---------------------------------------------------------------- eventos
  function readForm() {
    var f = local.form;
    var root = UI.root();
    function val(id) {
      var el = root.querySelector('#' + id);
      return el ? el : null;
    }
    var emp = val('lv-emp');
    var period = val('lv-period');
    var start = val('lv-start');
    var days = val('lv-days');
    var sold = val('lv-sold');
    var exc = val('lv-exc');
    if (emp && emp.value !== f.empNum) {
      f.empNum = emp.value;
      f.periodKey = '';
    } else if (period) f.periodKey = period.value;
    if (start) f.start = start.value;
    if (days) f.days = Number(days.value);
    if (sold) f.sold = Number(sold.value || 0);
    if (exc) f.exception = exc.checked;
    return f;
  }
  function input(f) {
    return { empNum: f.empNum, periodKey: f.periodKey, start: f.start, days: f.days, sold: f.sold, allowNoticeException: f.exception, requestId: f.requestId };
  }
  function evaluateNow(ctx, noRead) {
    var f = noRead ? local.form : readForm();
    var ev = A.leave.evaluate(ctx.st, ctx.actor, input(f));
    if (!ev.ok) {
      local.results = null;
      UI.toast(ev.error, 'danger');
      return null;
    }
    local.results = ev.results;
    local.checkedKey = formKey(f);
    return ev;
  }

  UI.on('leave.tab', function (el) {
    local.tab = el.getAttribute('data-id');
    RH.app.render();
  });
  UI.on('leave.field', function () {
    readForm();
    local.results = null;
    RH.app.render();
  });
  UI.on('leave.preset', function (el) {
    var f = ensureForm(RH.app.ctx());
    var p = el.getAttribute('data-p');
    f.sold = 0;
    f.days = 14;
    f.start = f.empNum === 'VTR-0015' ? '2026-12-14' : nextMonday(U.addDays(RH.store.state.today, 36));
    if (p === 'friday') f.start = '2026-11-27';
    if (p === 'short') f.days = 4;
    if (p === 'abono') f.sold = 11;
    if (p === 'holiday') f.start = '2026-12-24';
    local.results = null;
    var ctx = RH.app.ctx();
    local.form = f;
    evaluateNow(ctx, true);
    RH.app.render();
  });
  UI.on('leave.submit', function () {
    evaluateNow(RH.app.ctx());
    RH.app.render();
  });
  UI.on('leave.draft', function () {
    var f = readForm();
    var r = RH.store.act(function (st, actor) { return A.leave.submit(st, actor, input(f), true); });
    if (!r.ok) return UI.toast(r.error, 'danger');
    local.results = null;
    f.requestId = '';
    UI.toast('Rascunho ' + r.request.id + ' salvo. Ele não segue para aprovação até você enviar.', 'info');
  });
  UI.on('leave.send', function () {
    var f = readForm();
    if (local.checkedKey !== formKey(f)) return UI.toast('Verifique as regras novamente: os dados mudaram.', 'warning');
    var r = RH.store.act(function (st, actor) { return A.leave.submit(st, actor, input(f), false); });
    if (!r.ok) {
      local.results = r.results || null;
      return UI.toast(r.error, 'danger');
    }
    local.results = null;
    f.requestId = '';
    var ctx = RH.app.ctx();
    var step = RH.approval.currentStepOf(r.request);
    var who = step ? (step.type === 'HR_Team' ? 'a equipe de RH' : (Q.emp(ctx.st, step.approver) || {}).name) : '';
    UI.toast('Pedido ' + r.request.id + ' enviado. Aguardando ' + who + '.', 'success');
  });
  UI.on('leave.cancel', function (el) {
    var id = el.getAttribute('data-id');
    var r = RH.store.act(function (st, actor) { return A.approvals.cancel(st, actor, 'Leave', id); });
    UI.toast(r.ok ? 'Pedido ' + id + ' cancelado.' : r.error, r.ok ? 'info' : 'danger');
  });
  UI.on('leave.delDraft', function (el) {
    var id = el.getAttribute('data-id');
    var r = RH.store.act(function (st, actor) { return A.leave.deleteDraft(st, actor, id); });
    UI.toast(r.ok ? 'Rascunho excluído.' : r.error, r.ok ? 'info' : 'danger');
  });
  UI.on('leave.editDraft', function (el) {
    var id = el.getAttribute('data-id');
    var ctx = RH.app.ctx();
    var r = ctx.st.leaveRequests.filter(function (x) { return x.id === id; })[0];
    if (!r) return;
    local.form = { empNum: r.empNum, periodKey: r.periodKey, start: r.start, days: r.days, sold: r.sold, exception: false, requestId: r.id };
    local.results = null;
    evaluateNow(ctx, true);
    RH.app.render();
    var f = UI.root().querySelector('#lv-start');
    if (f) f.scrollIntoView({ block: 'center' });
  });
  UI.on('leave.calPrev', function () {
    local.cal.month--;
    if (local.cal.month < 1) {
      local.cal.month = 12;
      local.cal.year--;
    }
    RH.app.render();
  });
  UI.on('leave.calNext', function () {
    local.cal.month++;
    if (local.cal.month > 12) {
      local.cal.month = 1;
      local.cal.year++;
    }
    RH.app.render();
  });
  UI.on('leave.calMgr', function (el) {
    local.calManager = el.value;
    RH.app.render();
  });
  UI.on('leave.urgent', function (el) {
    local.onlyUrgent = el.checked;
    RH.app.render();
  });
  RH.views.leave.reset = function () {
    local.persona = null;
    local.form = null;
    local.results = null;
  };
  RH.views.leave.openTab = function (tab) {
    local.tab = tab;
  };
})(globalThis);
