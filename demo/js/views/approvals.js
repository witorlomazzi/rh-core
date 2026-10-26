/* RH Core demo: caixa de aprovacoes (spec 10, coreApprovalInbox) para ferias e promocoes. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var V = RH.visibility;
  var A = RH.actions;

  function subjectOf(ctx, item) {
    return Q.emp(ctx.st, item.req.empNum);
  }

  function itemTitle(ctx, item) {
    var e = subjectOf(ctx, item);
    var r = item.req;
    if (item.kind === 'Leave') {
      return 'Férias de ' + e.name + ': ' + r.days + ' dia(s), ' + U.fmtBR(r.start) + ' a ' + U.fmtBR(RH.leave.requestEnd(r));
    }
    return 'Promoção de ' + e.name + ': ' + Q.posName(ctx.st, r.curPos) + ' para ' + Q.posName(ctx.st, r.newPos);
  }

  function stepLabel(ctx, step) {
    if (step.type === 'HR_Team') return 'Etapa do RH';
    var who = step.approver ? Q.emp(ctx.st, step.approver) : null;
    return (RH.approval.STEP_LABEL[step.type] || step.type) + (who ? ': ' + who.name : '');
  }

  function visible(ctx, item) {
    var idx = Q.index(ctx.st);
    if (ctx.actor.role === 'hr') return true;
    return V.canSeeDetail(ctx.persona, idx, item.req.empNum) || item.canDecide;
  }

  function itemCard(ctx, item) {
    var r = item.req;
    var e = subjectOf(ctx, item);
    var isLeave = item.kind === 'Leave';
    var requester = Q.emp(ctx.st, r.requestedBy);
    var actor = ctx.actor;
    var canSal = V.canSeeSalary(ctx.persona);
    var extra = '';
    if (isLeave && r.conflict) extra += '<p class="rhc-note rhc-note-warn">' + UI.icon('warning') + '<span>' + esc(r.conflict) + '</span></p>';
    if (!isLeave) {
      extra += '<p class="rhc-note rhc-note-info">' + UI.icon('doc') + '<span><strong>Justificativa:</strong> ' + esc(r.justification) + '</span></p>';
      extra += '<div class="rhc-inline">' + UI.kv('Efetivação', U.fmtBR(r.effective)) + UI.kv('Salário atual', UI.salaryCell(r.curSalary, canSal)) + UI.kv('Salário proposto', UI.salaryCell(r.proposedSalary, canSal)) + '</div>';
    }
    var buttons = '';
    if (item.canDecide) {
      var hrPromo = !isLeave && item.step.type === 'HR_Team';
      if (hrPromo) {
        buttons += '<button type="button" class="rhc-btn rhc-btn-primary" data-act="nav.go" data-view="promotions">' + UI.icon('trendUp') + 'Revisar faixa e salário</button>';
      } else {
        buttons += '<button type="button" class="rhc-btn rhc-btn-primary" data-act="appr.approve" data-kind="' + item.kind + '" data-id="' + r.id + '">' + UI.icon('check') + 'Aprovar</button>';
      }
      buttons += '<button type="button" class="rhc-btn rhc-btn-danger-ghost" data-act="appr.reject" data-kind="' + item.kind + '" data-id="' + r.id + '">' + UI.icon('x') + 'Rejeitar</button>';
    } else if (item.step.type !== 'HR_Team') {
      var who = item.step.approver ? Q.emp(ctx.st, item.step.approver) : null;
      buttons += '<span class="rhc-muted">Aguardando ' + esc(who ? who.name : 'aprovador') + '.</span>' +
        '<button type="button" class="rhc-btn rhc-btn-ghost rhc-btn-sm" data-act="appr.simulate" data-kind="' + item.kind + '" data-id="' + r.id + '" title="Atalho de demonstração: esta pessoa não é uma das cinco personas.">' + UI.icon('play') + 'Simular aprovação de ' + esc(who ? Q.firstName(who.name) : 'aprovador') + '</button>';
    } else {
      buttons += '<span class="rhc-muted">Aguardando a equipe de RH.</span>';
    }
    return (
      '<article class="rhc-inbox-item' + (item.canDecide ? ' is-mine' : '') + '"><header>' + UI.avatar(e.name) +
      '<div><strong>' + esc(itemTitle(ctx, item)) + '</strong><small>' + esc(item.req.id) + ' · pedido por ' + esc(requester ? requester.name : '—') + ' em ' + U.fmtBR(r.createdAt) + '</small></div>' +
      UI.badge(isLeave ? 'Férias' : 'Promoção', isLeave ? 'info' : 'neutral', isLeave ? 'calendar' : 'trendUp') + '</header>' +
      '<p class="rhc-inbox-step">' + UI.icon('clock') + '<span>' + esc(stepLabel(ctx, item.step)) + '</span></p>' + extra +
      '<footer class="rhc-actions">' + buttons + '</footer></article>'
    );
  }

  function historyHtml(ctx) {
    var rows = [];
    function scan(kind, list) {
      list.forEach(function (r) {
        r.steps.forEach(function (s) {
          var mine = s.decidedBy && (s.decidedBy === ctx.actor.empNum || (ctx.actor.role === 'hr' && s.type === 'HR_Team'));
          if (mine && (s.status === 'Aprovado' || s.status === 'Rejeitado')) rows.push({ kind: kind, r: r, s: s });
        });
      });
    }
    scan('Leave', ctx.st.leaveRequests);
    scan('Promotion', ctx.st.promotions);
    rows.sort(function (a, b) { return (a.s.decisionDate || '') < (b.s.decisionDate || '') ? 1 : -1; });
    if (!rows.length) return UI.empty('clock', 'Sem decisões registradas', 'As decisões que você tomar aparecem aqui.');
    return '<ul class="rhc-abslist">' + rows.slice(0, 8).map(function (x) {
      var e = Q.emp(ctx.st, x.r.empNum);
      return '<li>' + UI.avatar(e.name) + '<span><strong>' + esc(x.r.id) + '</strong> · ' + esc(e.name) + (x.s.comments ? ' · ' + esc(x.s.comments) : '') + '</span>' + UI.badge(x.s.status === 'Aprovado' ? 'Aprovou' : 'Rejeitou', x.s.status === 'Aprovado' ? 'success' : 'danger', x.s.status === 'Aprovado' ? 'check' : 'x') + '</li>';
    }).join('') + '</ul>';
  }

  RH.views.approvals = {
    render: function (ctx) {
      var all = Q.inbox(ctx.st, ctx.actor).filter(function (i) { return visible(ctx, i); });
      var mine = all.filter(function (i) { return i.canDecide; });
      var others = all.filter(function (i) { return !i.canDecide; });
      var head = UI.pageHead('Aprovações', 'Fluxo em duas etapas: férias passam pelo gestor direto e depois pelo RH; promoções, pelo gestor de segundo nível e depois pelo RH.');
      var sec1 = UI.card('Aguardando a sua decisão (' + mine.length + ')', mine.length ? '<div class="rhc-inbox">' + mine.map(function (i) { return itemCard(ctx, i); }).join('') + '</div>' : UI.empty('check', 'Nada pendente para você', 'Quando um pedido chegar à sua etapa, ele aparece aqui. Experimente enviar um pedido de férias como Colaborador.'), { icon: 'inbox', cls: 'rhc-mt0' });
      var sec2 = UI.card('Em andamento com outros aprovadores (' + others.length + ')', others.length ? '<div class="rhc-inbox">' + others.map(function (i) { return itemCard(ctx, i); }).join('') + '</div>' : UI.empty('clock', 'Nenhum pedido aguardando outros', ''), { icon: 'clock' });
      var sec3 = UI.card('Suas decisões recentes', historyHtml(ctx), { icon: 'list' });
      return head + sec1 + sec2 + sec3;
    }
  };

  function decideAndToast(kind, id, decision, comment, simulate) {
    var r = RH.store.act(function (st, actor) {
      return simulate ? A.approvals.simulateAs(st, kind, id, decision, comment) : A.approvals.decide(st, actor, kind, id, decision, comment);
    });
    if (!r.ok) {
      UI.toast(r.error, 'danger');
      return r.error;
    }
    var msg = r.outcome === 'advanced' ? 'Etapa aprovada. A solicitação segue para a próxima etapa.' : r.outcome === 'approved' ? 'Solicitação aprovada.' : 'Solicitação rejeitada. O solicitante foi avisado.';
    UI.toast(msg, r.outcome === 'rejected' ? 'warning' : 'success');
    return true;
  }
  UI.on('appr.approve', function (el) {
    decideAndToast(el.getAttribute('data-kind'), el.getAttribute('data-id'), 'Aprovado', '', false);
  });
  UI.on('appr.simulate', function (el) {
    decideAndToast(el.getAttribute('data-kind'), el.getAttribute('data-id'), 'Aprovado', '', true);
  });
  UI.on('appr.reject', function (el) {
    var kind = el.getAttribute('data-kind');
    var id = el.getAttribute('data-id');
    UI.modal({
      title: 'Rejeitar ' + id,
      body: UI.field({ id: 'rej-comment', name: 'comment', label: 'Comentário (obrigatório)', type: 'textarea', rows: 4, required: true, help: 'O solicitante vê este texto. Explique o motivo e, se possível, uma alternativa.' }),
      confirm: 'Rejeitar solicitação',
      tone: 'danger',
      onConfirm: function (data) {
        return decideAndToast(kind, id, 'Rejeitado', data.comment, false);
      }
    });
  });
  UI.on('nav.go', function (el) {
    RH.store.setView(el.getAttribute('data-view'));
  });
})(globalThis);
