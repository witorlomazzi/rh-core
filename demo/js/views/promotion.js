/* RH Core demo: promocoes e historico de cargo (spec 12). O gestor solicita sem ver salario; o RH revisa a faixa. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var V = RH.visibility;
  var A = RH.actions;
  var P = RH.promotion;

  var local = { persona: null, form: null, tlEmp: null };

  function resetFor(ctx) {
    if (local.persona === ctx.persona) return;
    local.persona = ctx.persona;
    local.form = null;
    local.tlEmp = null;
  }

  function stepper(ctx, req) {
    return '<ol class="rhc-stepper" aria-label="Etapas de aprovação">' + req.steps.map(function (s) {
      var label = s.type === 'HR_Team' ? 'RH' : (Q.emp(ctx.st, s.approver) || { name: 'Gestor' }).name.split(' ')[0];
      var tone = s.skipped ? 'neutral' : s.status === 'Aprovado' ? 'success' : s.status === 'Rejeitado' ? 'danger' : s.status === 'Pendente' && req.step === s.order ? 'warning' : 'neutral';
      var ic = s.skipped ? 'minus' : s.status === 'Aprovado' ? 'check' : s.status === 'Rejeitado' ? 'x' : s.status === 'Pendente' ? 'clock' : 'ban';
      var txt = s.skipped ? 'pulada' : s.status === 'Aprovado' ? 'aprovou' : s.status === 'Rejeitado' ? 'rejeitou' : s.status === 'Pendente' ? (req.step === s.order ? 'aguardando' : 'em seguida') : 'encerrada';
      return '<li class="rhc-step rhc-step-' + tone + '">' + UI.icon(ic) + '<span><strong>' + esc(label) + '</strong> ' + txt + '</span></li>';
    }).join('') + '</ol>';
  }

  function bandBar(pos, salary) {
    var b = pos.band;
    var span = b.max - b.min;
    var pct = salary ? Math.max(-6, Math.min(106, ((salary - b.min) / span) * 100)) : null;
    var chk = P.bandCheck(salary, pos);
    return (
      '<div class="rhc-band" role="img" aria-label="Faixa do cargo ' + esc(pos.name) + ': de ' + esc(U.brl(b.min)) + ' a ' + esc(U.brl(b.max)) + '"><span class="rhc-band-fill"></span>' +
      (pct !== null ? '<i class="rhc-band-mark ' + (chk.status === 'within' ? 'is-in' : 'is-out') + '" style="left:' + pct + '%"></i>' : '') + '</div>' +
      '<div class="rhc-band-labels"><span>' + esc(U.brl(b.min)) + '</span><span>' + esc(U.brl(b.mid)) + '</span><span>' + esc(U.brl(b.max)) + '</span></div>'
    );
  }
  function bandIndicator(pos, salary, current) {
    if (!salary) return UI.badge('Informe o salário proposto', 'neutral', 'info');
    var chk = P.bandCheck(salary, pos);
    var inc = P.increasePercent(current, salary);
    var incTxt = inc === null ? '' : (inc >= 0 ? '+' : '') + String(inc).replace('.', ',') + '% sobre o atual';
    var b = chk.status === 'within' ? UI.badge('Dentro da faixa', 'success', 'check') : chk.status === 'below' ? UI.badge('Abaixo da faixa: exige justificativa', 'warning', 'warning') : UI.badge('Acima da faixa: exige justificativa', 'warning', 'warning');
    return b + ' <span class="rhc-muted">' + incTxt + '</span>';
  }

  function requestCard(ctx, r, hrMode) {
    var e = Q.emp(ctx.st, r.empNum);
    var canSal = V.canSeeSalary(ctx.persona);
    var cur = ctx.st.positions[r.curPos];
    var nw = ctx.st.positions[r.newPos];
    var step = RH.approval.currentStepOf(r);
    var body =
      '<div class="rhc-promo-flow"><div><small>Cargo atual</small><strong>' + esc(cur.name) + '</strong></div>' + UI.icon('arrowRight') + '<div><small>Cargo proposto</small><strong>' + esc(nw.name) + '</strong></div></div>' +
      '<dl class="rhc-kvlist rhc-kvlist-inline">' + UI.kv('Efetivação', U.fmtBR(r.effective)) + UI.kv('Salário atual (snapshot)', UI.salaryCell(r.curSalary, canSal)) + UI.kv('Salário proposto', UI.salaryCell(r.proposedSalary, canSal)) +
      (canSal && r.proposedSalary ? UI.kv('Aumento', (P.increasePercent(r.curSalary, r.proposedSalary) + '%').replace('.', ',')) : '') + '</dl>' +
      (r.outOfTrail ? '<p class="rhc-note rhc-note-warn">' + UI.icon('warning') + '<span>Promoção fora da trilha prevista.</span></p>' : '') +
      '<p class="rhc-note rhc-note-info">' + UI.icon('doc') + '<span><strong>Justificativa:</strong> ' + esc(r.justification) + '</span></p>' + stepper(ctx, r);
    var hr = '';
    var actor = ctx.actor;
    if (hrMode && r.status === 'Pendente' && step) {
      if (step.type === 'HR_Team' && actor.role === 'hr') {
        hr =
          '<div class="rhc-hr-review"><h5 class="rhc-subtitle">' + UI.icon('shield') + ' Revisão do RH</h5><p class="rhc-muted">Faixa do cargo proposto (campo restrito ao RH).</p>' + bandBar(nw, r.proposedSalary) +
          '<form class="rhc-form rhc-inline-form" data-submit="promo.saveSalary" data-id="' + r.id + '">' +
          UI.field({ id: 'sal-' + r.id, name: 'salary', label: 'Salário proposto (R$)', type: 'number', value: r.proposedSalary || '', attrs: 'min="0" step="50" data-input="promo.salaryInput" data-id="' + r.id + '"' }) +
          '<button type="submit" class="rhc-btn rhc-btn-secondary">' + UI.icon('check') + 'Salvar valor</button></form>' +
          '<p class="rhc-band-ind" id="ind-' + r.id + '">' + bandIndicator(nw, r.proposedSalary, r.curSalary) + '</p>' +
          '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-primary" data-act="promo.hrApprove" data-id="' + r.id + '">' + UI.icon('check') + 'Aprovar promoção</button>' +
          '<button type="button" class="rhc-btn rhc-btn-danger-ghost" data-act="appr.reject" data-kind="Promotion" data-id="' + r.id + '">' + UI.icon('x') + 'Rejeitar</button></div></div>';
      } else if (step.type !== 'HR_Team') {
        var who = Q.emp(ctx.st, step.approver);
        hr = '<div class="rhc-actions"><span class="rhc-muted">Etapa 1 com ' + esc(who ? who.name : 'o gestor de segundo nível') + ' (gestor de segundo nível).</span><button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="appr.simulate" data-kind="Promotion" data-id="' + r.id + '">' + UI.icon('play') + 'Simular aprovação de ' + esc(who ? Q.firstName(who.name) : 'aprovador') + '</button></div>';
      }
    } else if (hrMode && r.status === 'Aprovado') {
      hr = '<div class="rhc-actions"><span class="rhc-muted">Aprovada. Efetiva em ' + U.fmtBR(r.effective) + ' pela rotina diária.</span>' +
        (actor.role === 'hr' ? '<button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="promo.effectivate" data-id="' + r.id + '">' + UI.icon('play') + 'Rodar a efetivação agora</button>' : '') + '</div>';
    } else if (!hrMode && r.status === 'Pendente' && step && step.type !== 'HR_Team') {
      var w2 = Q.emp(ctx.st, step.approver);
      hr = '<div class="rhc-actions"><span class="rhc-muted">Aguardando ' + esc(w2 ? w2.name : 'aprovador') + '.</span><button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="appr.simulate" data-kind="Promotion" data-id="' + r.id + '" title="Atalho de demonstração">' + UI.icon('play') + 'Simular aprovação de ' + esc(w2 ? Q.firstName(w2.name) : 'aprovador') + '</button></div>';
    }
    return (
      '<article class="rhc-promo"><header>' + UI.avatar(e.name) + '<div><strong>' + esc(e.name) + '</strong><small>' + esc(r.id) + ' · pedido de ' + esc((Q.emp(ctx.st, r.requestedBy) || { name: '—' }).name) + ' em ' + U.fmtBR(r.createdAt) + '</small></div>' + UI.statusBadge(r.status, P.STATUS_LABEL[r.status]) + '</header>' + body + hr + '</article>'
    );
  }

  function formHtml(ctx) {
    var st = ctx.st;
    var idx = Q.index(st);
    var team = V.subtree(idx, ctx.actor.empNum).map(function (n) { return idx.byNum[n]; }).filter(function (e) { return e.status === 'Ativo' || e.status === 'Ferias'; });
    if (!team.length) return UI.empty('team', 'Sem equipe', 'Você não tem subordinados para promover.');
    if (!local.form) {
      local.form = { subjectNum: team[0].num, proposedPos: '', effective: '2026-12-01', justification: '', error: '', warnings: [] };
      local.form.proposedPos = st.positions[team[0].pos].next || '';
    }
    var f = local.form;
    var subject = Q.emp(st, f.subjectNum) || team[0];
    var cur = st.positions[subject.pos];
    var posOpts = Object.keys(st.positions).map(function (k) {
      var p = st.positions[k];
      var tag = cur.next === k ? ' (próximo da trilha)' : k === subject.pos ? ' (cargo atual)' : '';
      return { value: k, label: p.name + tag, disabled: k === subject.pos };
    });
    var nextName = cur.next ? st.positions[cur.next].name : 'fim da trilha';
    return (
      '<form class="rhc-form" data-submit="promo.create" novalidate>' +
      '<div class="rhc-grid-form">' +
      UI.field({ id: 'pm-emp', name: 'subjectNum', label: 'Colaborador', type: 'select', value: f.subjectNum, options: team.map(function (e) { return { value: e.num, label: e.name + ' · ' + Q.posName(st, e.pos) }; }), attrs: 'data-change="promo.field"', cls: 'rhc-col-2' }) +
      UI.field({ id: 'pm-pos', name: 'proposedPos', label: 'Cargo proposto', type: 'select', value: f.proposedPos, options: posOpts, attrs: 'data-change="promo.field"' }) +
      UI.field({ id: 'pm-date', name: 'effective', label: 'Data de efetivação', type: 'date', value: f.effective, attrs: 'data-change="promo.field"', required: true }) +
      UI.field({ id: 'pm-just', name: 'justification', label: 'Justificativa', type: 'textarea', rows: 3, value: f.justification, required: true, cls: 'rhc-col-2', attrs: 'data-change="promo.field"' }) +
      '</div>' +
      '<div class="rhc-trail" aria-label="Trilha de carreira"><span>' + UI.icon('flag') + 'Cargo atual: <strong>' + esc(cur.name) + '</strong></span><span>' + UI.icon('arrowRight') + 'Próximo da trilha: <strong>' + esc(nextName) + '</strong></span><span>' + UI.salaryCell(subject.salary, false) + ' <small class="rhc-muted">você não vê nem informa salário</small></span></div>' +
      (f.error ? '<p class="rhc-error" role="alert">' + esc(f.error) + '</p>' : '') +
      (f.warnings.length ? '<p class="rhc-note rhc-note-warn">' + UI.icon('warning') + '<span>' + esc(f.warnings.join(' ')) + '</span></p>' : '') +
      '<div class="rhc-actions"><button type="submit" class="rhc-btn rhc-btn-primary">' + UI.icon('send') + 'Solicitar promoção</button></div></form>'
    );
  }

  function timelineCard(ctx) {
    var st = ctx.st;
    var idx = Q.index(st);
    var people = st.employees.filter(function (e) {
      return e.status !== 'Pre_Admissao' && V.canSeeDetail(ctx.persona, idx, e.num);
    });
    if (!people.length) return '';
    if (!local.tlEmp || !people.some(function (p) { return p.num === local.tlEmp; })) local.tlEmp = (people.filter(function (p) { return p.num === 'VTR-0015'; })[0] || people[0]).num;
    var canSal = V.canSeeSalary(ctx.persona);
    var hist = st.positionHistory.filter(function (h) { return h.empNum === local.tlEmp; }).sort(function (a, b) { return a.start < b.start ? 1 : -1; });
    var reasons = { Admissao: 'Admissão', Promocao: 'Promoção', Merito: 'Mérito', Transferencia: 'Transferência' };
    return UI.card('Linha do tempo de cargos', UI.field({ id: 'tl-emp', label: 'Colaborador', type: 'select', value: local.tlEmp, options: people.map(function (p) { return { value: p.num, label: p.name }; }), attrs: 'data-change="promo.timeline"', cls: 'rhc-inline-field' }) +
      '<ol class="rhc-timeline rhc-timeline-lg">' + hist.map(function (h) {
        return '<li><span class="rhc-timeline-dot"></span><div><strong>' + esc(Q.posName(st, h.pos)) + '</strong><small>' + esc(Q.deptName(st, h.dept)) + ' · ' + U.fmtBR(h.start) + ' a ' + (h.end ? U.fmtBR(h.end) : 'hoje') + '</small>' +
          UI.badge(reasons[h.reason] || h.reason, h.reason === 'Promocao' ? 'success' : 'neutral') + '<span class="rhc-timeline-sal">' + (h.salary ? UI.salaryCell(h.salary, canSal) : '') + '</span></div></li>';
      }).join('') + '</ol>' + (canSal ? '' : '<p class="rhc-note">' + UI.icon('lock') + '<span>Valores de salário do histórico só aparecem para o RH.</span></p>'), { icon: 'clock' });
  }

  RH.views.promotions = {
    render: function (ctx) {
      resetFor(ctx);
      var role = ctx.actor.role;
      var st = ctx.st;
      var idx = Q.index(st);
      var reqs = st.promotions.filter(function (r) {
        if (role === 'hr') return true;
        return r.requestedBy === ctx.actor.empNum || V.canSeeDetail(ctx.persona, idx, r.empNum) && RH.approval.canDecide(r, ctx.actor);
      }).sort(function (a, b) { return a.id < b.id ? 1 : -1; });
      var head = UI.pageHead('Promoções', role === 'hr' ? 'Revise a faixa salarial, informe o salário e dê a aprovação final.' : 'Solicite a promoção de alguém da sua equipe. O salário não é exibido nem informado por você.');
      var parts = '';
      if (role === 'manager' || role === 'hr') parts += UI.card('Solicitar promoção', formHtml(ctx), { icon: 'send', cls: 'rhc-mt0' });
      var pend = reqs.filter(function (r) { return r.status === 'Pendente'; });
      var rest = reqs.filter(function (r) { return r.status !== 'Pendente'; });
      parts += UI.card(role === 'hr' ? 'Solicitações em andamento (' + pend.length + ')' : 'Minhas solicitações em andamento (' + pend.length + ')',
        pend.length ? '<div class="rhc-promos">' + pend.map(function (r) { return requestCard(ctx, r, true); }).join('') + '</div>' : UI.empty('trendUp', 'Nenhuma solicitação pendente', 'Crie uma solicitação acima.'), { icon: 'trendUp' });
      parts += UI.card('Solicitações concluídas (' + rest.length + ')', rest.length ? '<div class="rhc-promos">' + rest.map(function (r) { return requestCard(ctx, r, true); }).join('') + '</div>' : UI.empty('check', 'Nada concluído ainda', ''), { icon: 'check' });
      parts += timelineCard(ctx);
      return head + parts;
    }
  };

  function readForm() {
    var root = UI.root();
    var f = local.form;
    if (!f) return;
    var q = function (id) { return root.querySelector('#' + id); };
    if (q('pm-emp') && q('pm-emp').value !== f.subjectNum) {
      f.subjectNum = q('pm-emp').value;
      var e = Q.emp(RH.store.state, f.subjectNum);
      f.proposedPos = RH.store.state.positions[e.pos].next || '';
    } else if (q('pm-pos')) f.proposedPos = q('pm-pos').value;
    if (q('pm-date')) f.effective = q('pm-date').value;
    if (q('pm-just')) f.justification = q('pm-just').value;
  }
  UI.on('promo.field', function () {
    readForm();
    local.form.error = '';
    local.form.warnings = [];
    RH.app.render();
  });
  UI.on('promo.timeline', function (el) {
    local.tlEmp = el.value;
    RH.app.render();
  });
  UI.on('promo.create', function () {
    readForm();
    var f = local.form;
    var r = RH.store.act(function (st, actor) {
      return A.promotion.create(st, actor, { subjectNum: f.subjectNum, proposedPos: f.proposedPos, effective: f.effective, justification: f.justification });
    });
    if (!r.ok) {
      f.error = r.error;
      f.warnings = r.warnings || [];
      RH.app.render();
      return;
    }
    local.form = null;
    UI.toast('Solicitação ' + r.request.id + ' criada.' + (r.warnings.length ? ' Aviso: ' + r.warnings[0] : ''), r.warnings.length ? 'warning' : 'success');
  });
  UI.on('promo.salaryInput', function (el) {
    var id = el.getAttribute('data-id');
    var st = RH.store.state;
    var r = A.promotion.find(st, id);
    var ind = document.getElementById('ind-' + id);
    if (!r || !ind) return;
    var v = Number(el.value);
    ind.innerHTML = bandIndicator(st.positions[r.newPos], v > 0 ? v : null, r.curSalary);
    var bar = ind.parentNode.querySelector('.rhc-band');
    if (bar) {
      var b = st.positions[r.newPos].band;
      var mark = bar.querySelector('.rhc-band-mark');
      if (!mark) {
        mark = document.createElement('i');
        bar.appendChild(mark);
      }
      mark.className = 'rhc-band-mark ' + (v >= b.min && v <= b.max ? 'is-in' : 'is-out');
      mark.style.left = Math.max(-6, Math.min(106, ((v - b.min) / (b.max - b.min)) * 100)) + '%';
    }
  });
  UI.on('promo.saveSalary', function (form) {
    var id = form.getAttribute('data-id');
    var v = form.querySelector('input[name=salary]').value;
    var r = RH.store.act(function (st, actor) { return A.promotion.setProposedSalary(st, actor, id, v); });
    UI.toast(r.ok ? 'Salário proposto salvo.' : r.error, r.ok ? 'success' : 'danger');
  });
  UI.on('promo.hrApprove', function (el) {
    var id = el.getAttribute('data-id');
    var root = UI.root();
    var inp = root.querySelector('#sal-' + id);
    var st0 = RH.store.state;
    var r0 = A.promotion.find(st0, id);
    var typed = inp ? Number(inp.value) : 0;
    if (typed > 0 && (!r0.proposedSalary || typed !== r0.proposedSalary)) {
      RH.store.act(function (st, actor) { return A.promotion.setProposedSalary(st, actor, id, typed); });
    }
    var cur = A.promotion.find(RH.store.state, id);
    var bc = P.bandCheck(cur.proposedSalary, RH.store.state.positions[cur.newPos]);
    function go(comment) {
      var r = RH.store.act(function (st, actor) { return A.approvals.decide(st, actor, 'Promotion', id, 'Aprovado', comment); });
      if (!r.ok) {
        UI.toast(r.error, 'danger');
        return r.error;
      }
      var fin = A.promotion.find(RH.store.state, id);
      UI.toast(fin.status === 'Efetivado' ? 'Promoção aprovada e efetivada: o cargo do colaborador foi atualizado.' : 'Promoção aprovada. Será efetivada em ' + U.fmtBR(fin.effective) + '.', 'success');
      return true;
    }
    if (cur.proposedSalary && bc.status !== 'within') {
      UI.modal({
        title: 'Salário fora da faixa do cargo',
        body: '<p>O valor proposto está ' + (bc.status === 'below' ? 'abaixo' : 'acima') + ' da faixa. Registre a justificativa da exceção para aprovar.</p>' + UI.field({ id: 'hr-just', name: 'comment', label: 'Justificativa da exceção', type: 'textarea', rows: 3, required: true }),
        confirm: 'Aprovar com justificativa',
        onConfirm: function (d) { return go(d.comment); }
      });
      return;
    }
    go('');
  });
  UI.on('promo.effectivate', function (el) {
    var id = el.getAttribute('data-id');
    var r = RH.store.act(function (st) { return A.promotion.effectivate(st, id); });
    UI.toast(r.ok ? 'Promoção efetivada. Histórico de cargo atualizado.' : r.error, r.ok ? 'success' : 'danger');
  });
  RH.views.promotions.reset = function () {
    local.persona = null;
    local.form = null;
  };
})(globalThis);
