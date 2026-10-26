/* RH Core demo: Meu RH, inicio do colaborador e do gestor (spec 17). Monta a experiencia sem recriar regras. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var V = RH.visibility;
  var A = RH.actions;

  function balanceCard(ctx, me) {
    var periods = Q.periodsOf(ctx.st, me.num).filter(function (x) { return x.status === 'Disponivel' || x.status === 'Prazo_Proximo'; });
    if (!periods.length) return UI.card('Saldo de férias', UI.empty('calendar', 'Sem saldo disponível', me.type === 'CLT' ? 'Não há período adquirido com saldo no momento.' : 'Este vínculo não gera férias CLT.'), { icon: 'calendar', cls: 'rhc-tile' });
    var total = periods.reduce(function (a, x) { return a + x.bal.balance; }, 0);
    var first = periods.slice().sort(function (a, b) { return a.period.concessionDeadline < b.period.concessionDeadline ? -1 : 1; })[0];
    return UI.card('Saldo de férias', '<div class="rhc-period-balance"><span class="rhc-big">' + total + '</span><span>dia(s) a tirar<small> em ' + periods.length + ' período(s)</small></span></div>' +
      '<p class="rhc-period-foot' + (first.status === 'Prazo_Proximo' ? ' rhc-warn-text' : '') + '">' + UI.icon(first.status === 'Prazo_Proximo' ? 'warning' : 'clock') + 'Prazo concessivo mais próximo: <strong>' + U.fmtBR(first.period.concessionDeadline) + '</strong></p>' +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-primary rhc-btn-sm" data-act="nav.go" data-view="leave">' + UI.icon('send') + 'Solicitar férias</button></div>', { icon: 'calendar', cls: 'rhc-tile' });
  }

  function nextLeaveCard(ctx, me) {
    var reqs = ctx.st.leaveRequests.filter(function (r) { return r.empNum === me.num && ['Pendente', 'Aprovado', 'Em_Gozo'].indexOf(r.status) >= 0; }).sort(function (a, b) { return a.start < b.start ? -1 : 1; });
    var body = reqs.length
      ? '<ul class="rhc-abslist">' + reqs.slice(0, 3).map(function (r) { return '<li>' + UI.icon('sun') + '<span><strong>' + U.fmtBR(r.start) + ' a ' + U.fmtBR(RH.leave.requestEnd(r)) + '</strong> · ' + r.days + ' dia(s)</span>' + UI.statusBadge(r.status, RH.leave.REQUEST_STATUS_LABEL[r.status]) + '</li>'; }).join('') + '</ul>'
      : UI.empty('sun', 'Nenhuma férias marcada', 'Planeje com antecedência: o aviso mínimo é de 30 dias.');
    return UI.card('Próximas férias', body, { icon: 'sun', cls: 'rhc-tile' });
  }

  function approvalsCard(ctx) {
    var mine = Q.inbox(ctx.st, ctx.actor).filter(function (i) { return i.canDecide; });
    return UI.card('Pendências de aprovação', '<div class="rhc-period-balance"><span class="rhc-big">' + mine.length + '</span><span>' + (mine.length === 1 ? 'solicitação aguarda' : 'solicitações aguardam') + ' a sua decisão</span></div>' +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="nav.go" data-view="approvals">' + UI.icon('inbox') + 'Abrir caixa de aprovações</button></div>', { icon: 'inbox', cls: 'rhc-tile' });
  }

  function cycleCard(ctx, me) {
    var st = ctx.st;
    var self = st.selfAssessments[me.num];
    var rv = st.reviews[me.num];
    var lines = '<p class="rhc-muted">Fase atual do ciclo: <strong>' + esc(RH.performance.PHASE_LABEL[st.cycle.status]) + '</strong></p><ul class="rhc-abslist">' +
      '<li>' + UI.icon('edit') + '<span>Autoavaliação</span>' + (self ? (self.submitted ? UI.badge('Enviada', 'success', 'check') : UI.badge('Pendente até ' + U.fmtShort(st.cycle.selfDue), 'warning', 'clock')) : UI.badge('Fora do ciclo', 'neutral')) + '</li>' +
      '<li>' + UI.icon('star') + '<span>Resultado do gestor</span>' + (rv && rv.status === 'Liberada' ? UI.badge('Liberado', 'success', 'check') : UI.badge('Aguardando liberação', 'neutral', 'lock')) + '</li></ul>' +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="nav.go" data-view="performance">' + UI.icon('star') + 'Abrir desempenho</button></div>';
    return UI.card('Ciclo de avaliação', lines, { icon: 'star', cls: 'rhc-tile' });
  }

  function onboardingCard(ctx) {
    var plans = A.onboarding.visiblePlans(ctx.st, ctx.actor);
    if (!plans.length) return '';
    var pl = plans[0];
    var e = Q.emp(ctx.st, pl.empNum);
    var p = A.onboarding.progress(pl);
    return UI.card('Onboarding em andamento', '<p><strong>' + esc(e.name) + '</strong> · ' + esc(Q.posName(ctx.st, e.pos)) + '</p><div class="rhc-progress" role="img" aria-label="' + p.percent + '%"><span style="width:' + p.percent + '%"></span></div><small class="rhc-muted">' + p.done + ' de ' + p.total + ' tarefas</small>' +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="nav.go" data-view="onboarding">' + UI.icon('clipboard') + 'Abrir checklist</button></div>', { icon: 'clipboard', cls: 'rhc-tile' });
  }

  function teamCard(ctx, me) {
    var st = ctx.st;
    var team = Q.directReports(st, me.num).filter(function (e) { return e.status !== 'Desligado'; });
    var rows = team.map(function (e) {
      var ps = Q.periodsOf(st, e.num).filter(function (x) { return x.status === 'Disponivel' || x.status === 'Prazo_Proximo'; });
      var bal = ps.reduce(function (a, x) { return a + x.bal.balance; }, 0);
      var urgent = ps.some(function (x) { return x.status === 'Prazo_Proximo'; });
      var next = st.leaveRequests.filter(function (r) { return r.empNum === e.num && ['Pendente', 'Aprovado', 'Em_Gozo'].indexOf(r.status) >= 0; }).sort(function (a, b) { return a.start < b.start ? -1 : 1; })[0];
      return (
        '<tr><td data-label="Pessoa"><div class="rhc-person">' + UI.avatar(e.name) + '<div><strong>' + esc(e.name) + '</strong><small>' + esc(Q.posName(st, e.pos)) + '</small></div></div></td>' +
        '<td data-label="Status">' + (e.status === 'Ferias' ? UI.badge('Em férias', 'info', 'sun') : e.type === 'Estagio' ? UI.badge('Estágio', 'neutral') : UI.badge('Ativo', 'success', 'check')) + '</td>' +
        '<td data-label="Saldo">' + (e.type === 'CLT' ? bal + ' d' : '-') + (urgent ? ' ' + UI.badge('Prazo próximo', 'warning', 'warning') : '') + '</td>' +
        '<td data-label="Próximas férias">' + (next ? U.fmtShort(next.start) + ' a ' + U.fmtShort(RH.leave.requestEnd(next)) + ' ' + UI.statusBadge(next.status, RH.leave.REQUEST_STATUS_LABEL[next.status]) : '<span class="rhc-muted">-</span>') + '</td></tr>'
      );
    }).join('');
    return UI.card('Minha equipe (' + team.length + ')', '<div class="rhc-tablewrap"><table class="rhc-table rhc-table-stack"><caption class="rhc-sr">Equipe direta</caption><thead><tr><th scope="col">Pessoa</th><th scope="col">Status</th><th scope="col">Saldo</th><th scope="col">Próximas férias</th></tr></thead><tbody>' + rows + '</tbody></table></div>' +
      '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="home.calendar">' + UI.icon('calendar') + 'Calendário da equipe</button><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="nav.go" data-view="promotions">' + UI.icon('trendUp') + 'Solicitar promoção</button></div>', { icon: 'team' });
  }

  RH.views.home = {
    render: function (ctx) {
      var p = V.PERSONAS[ctx.persona];
      var me = Q.emp(ctx.st, p.empNum);
      if (!me) return UI.empty('info', 'Seu usuário ainda não está vinculado a um colaborador', 'Fale com o RH.');
      var mgr = me.mgr ? Q.emp(ctx.st, me.mgr) : null;
      var head =
        '<section class="rhc-hero" aria-label="Resumo do colaborador">' + UI.avatar(me.name) +
        '<div><p class="rhc-eyebrow">Meu RH</p><h2 tabindex="-1" id="rhc-page-title">Olá, ' + esc(Q.firstName(me.name)) + '</h2><p>' + esc(Q.posName(ctx.st, me.pos)) + ' · ' + esc(Q.deptName(ctx.st, me.dept)) + '</p></div>' +
        '<dl class="rhc-hero-facts"><div><dt>Gestor</dt><dd>' + esc(mgr ? mgr.name : '-') + '</dd></div><div><dt>Tempo de casa</dt><dd>' + esc(U.tenureText(me.hire, ctx.st.today)) + '</dd></div><div><dt>Matrícula</dt><dd>' + esc(me.num) + '</dd></div><div><dt>Salário</dt><dd>' + UI.salaryCell(me.salary, V.canSeeSalary(ctx.persona)) + '</dd></div></dl></section>';
      var tiles = '<div class="rhc-tiles">' + balanceCard(ctx, me) + nextLeaveCard(ctx, me) + (p.role === 'manager' ? approvalsCard(ctx) : '') + cycleCard(ctx, me) + onboardingCard(ctx) + '</div>';
      var note = p.role === 'employee'
        ? '<p class="rhc-note rhc-note-info">' + UI.icon('shield') + '<span>Como colaborador, você vê só os seus dados. Até o seu salário aparece mascarado: o campo é protegido por FLS e só o RH o lê.</span></p>'
        : '';
      return head + note + tiles + (p.role === 'manager' ? teamCard(ctx, me) : '');
    }
  };
  UI.on('home.calendar', function () {
    RH.views.leave.openTab('team');
    RH.store.setView('leave');
  });
})(globalThis);
