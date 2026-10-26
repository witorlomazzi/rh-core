/* RH Core demo: admissao e onboarding (spec 15): checklist por responsavel, ativacao pelo RH e visao geral. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var A = RH.actions;

  var local = { planId: null };

  var ROLE_ICON = { RH: 'shield', Gestor: 'team', TI: 'key', Colaborador: 'person' };
  var ROLE_ORDER = ['Colaborador', 'RH', 'TI', 'Gestor'];

  function progressBar(p) {
    return '<div class="rhc-progress" role="img" aria-label="' + p.percent + '% concluído"><span style="width:' + p.percent + '%"></span></div><small class="rhc-muted">' + p.done + ' de ' + p.total + ' tarefas concluídas (' + p.percent + '%)</small>';
  }

  function checklist(ctx, plan) {
    var st = ctx.st;
    var emp = Q.emp(st, plan.empNum);
    var p = A.onboarding.progress(plan);
    var groups = ROLE_ORDER.map(function (role) {
      var tasks = plan.tasks.filter(function (t) { return t.role === role; });
      if (!tasks.length) return '';
      return (
        '<section class="rhc-taskgroup"><h5>' + UI.icon(ROLE_ICON[role]) + 'Responsável: ' + esc(role) + '</h5><ul class="rhc-tasks">' + tasks.map(function (t) {
          var late = t.status === 'Pendente' && t.due < st.today;
          var who = Q.emp(st, t.assigned);
          var mine = t.assigned === ctx.actor.empNum || ctx.actor.role === 'hr';
          return (
            '<li class="rhc-task' + (t.status === 'Concluida' ? ' is-done' : '') + (late ? ' is-late' : '') + '">' +
            '<label><input type="checkbox" data-change="onb.toggle" data-plan="' + plan.id + '" data-task="' + t.id + '"' + (t.status === 'Concluida' ? ' checked' : '') + '><span class="rhc-task-box" aria-hidden="true">' + UI.icon('check') + '</span>' +
            '<span class="rhc-task-text"><strong>' + esc(t.title) + '</strong><small>' + esc(t.description) + '</small></span></label>' +
            '<div class="rhc-task-meta">' + UI.badge('Prazo ' + U.fmtBR(t.due), late ? 'danger' : 'neutral', late ? 'warning' : 'calendar') + '<small class="rhc-muted">' + (who ? esc(who.name) : esc(t.assigned)) + (mine ? '' : ' · ' + 'somente o responsável ou o RH conclui') + '</small></div></li>'
          );
        }).join('') + '</ul></section>'
      );
    }).join('');
    return (
      '<div class="rhc-planhead">' + UI.avatar(emp.name) + '<div><h4>' + esc(emp.name) + '</h4><p>' + esc(Q.posName(st, emp.pos)) + ' · ' + esc(Q.deptName(st, emp.dept)) + ' · admissão prevista em ' + U.fmtBR(plan.start) + '</p></div>' +
      UI.badge(emp.status === 'Pre_Admissao' ? 'Pré-admissão' : plan.status === 'Concluido' ? 'Plano concluído' : 'Em andamento', emp.status === 'Pre_Admissao' ? 'warning' : 'success', emp.status === 'Pre_Admissao' ? 'clock' : 'check') + '</div>' +
      progressBar(p) + groups
    );
  }

  function overview(ctx, plans) {
    var st = ctx.st;
    return '<div class="rhc-tablewrap"><table class="rhc-table rhc-table-stack"><caption class="rhc-sr">Planos de onboarding</caption><thead><tr><th scope="col">Colaborador</th><th scope="col">Gestor</th><th scope="col">Admissão</th><th scope="col">Progresso</th><th scope="col">Atrasos</th><th scope="col"><span class="rhc-sr">Ações</span></th></tr></thead><tbody>' + plans.map(function (pl) {
      var e = Q.emp(st, pl.empNum);
      var mg = e.mgr ? Q.emp(st, e.mgr) : null;
      var prog = A.onboarding.progress(pl);
      var late = pl.tasks.filter(function (t) { return t.status === 'Pendente' && t.due < st.today; }).length;
      return (
        '<tr><td data-label="Colaborador"><div class="rhc-person">' + UI.avatar(e.name) + '<div><strong>' + esc(e.name) + '</strong><small>' + esc(e.num) + (e.status === 'Pre_Admissao' ? ' · pré-admissão' : '') + '</small></div></div></td>' +
        '<td data-label="Gestor">' + esc(mg ? mg.name : '—') + '</td><td data-label="Admissão">' + U.fmtBR(pl.start) + '</td>' +
        '<td data-label="Progresso"><div class="rhc-progress rhc-progress-sm" role="img" aria-label="' + prog.percent + '%"><span style="width:' + prog.percent + '%"></span></div><small>' + prog.done + '/' + prog.total + '</small></td>' +
        '<td data-label="Atrasos">' + (late ? UI.badge(late + ' atrasada(s)', 'danger', 'warning') : UI.badge('Em dia', 'success', 'check')) + '</td>' +
        '<td><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="onb.open" data-plan="' + pl.id + '">' + UI.icon('clipboard') + 'Abrir plano</button></td></tr>'
      );
    }).join('') + '</tbody></table></div>';
  }

  function activationCard(ctx, plan) {
    var e = Q.emp(ctx.st, plan.empNum);
    if (ctx.actor.role !== 'hr' || !e || e.status !== 'Pre_Admissao') return '';
    return UI.card('Ativar admissão', '<p class="rhc-lead">Complete os dados de admissão de <strong>' + esc(e.name) + '</strong>. Ao ativar, o colaborador passa a Ativo, o histórico de admissão é criado e as datas das tarefas pendentes são recalculadas a partir da nova data.</p>' +
      '<form class="rhc-form" data-submit="onb.activate" data-emp="' + esc(e.num) + '" novalidate><div class="rhc-grid-form">' +
      UI.field({ id: 'ac-num', name: 'number', label: 'Matrícula definitiva', value: nextNumber(ctx.st), required: true, help: 'Formato VTR-0000. Precisa ser única.' }) +
      UI.field({ id: 'ac-date', name: 'hireDate', label: 'Data de admissão', type: 'date', value: e.hire, required: true }) +
      UI.field({ id: 'ac-sal', name: 'salary', label: 'Salário inicial (R$, somente RH)', type: 'number', value: ctx.st.positions[e.pos].band.mid, attrs: 'min="0" step="50"' }) +
      '</div><div class="rhc-actions"><button type="submit" class="rhc-btn rhc-btn-primary">' + UI.icon('userPlus') + 'Ativar colaborador</button></div></form>', { icon: 'userPlus' });
  }
  function nextNumber(st) {
    var max = 0;
    st.employees.forEach(function (e) {
      var m = /^VTR-(\d{4})$/.exec(e.num);
      if (m) max = Math.max(max, parseInt(m[1], 10));
    });
    return 'VTR-' + U.pad(max + 1, 4);
  }

  RH.views.onboarding = {
    render: function (ctx) {
      var plans = A.onboarding.visiblePlans(ctx.st, ctx.actor);
      var head = UI.pageHead('Admissão e onboarding', 'Quando uma candidatura vira Contratado, o colaborador é criado em pré-admissão com um plano de 8 tarefas.');
      if (!plans.length) {
        return head + UI.card('Meu onboarding', UI.empty('clipboard', 'Nenhum plano de onboarding ativo', ctx.actor.role === 'manager' ? 'Quando alguém da sua equipe for contratado, o plano aparece aqui com as tarefas do gestor.' : 'Você não tem um plano em andamento. Novos colaboradores recebem o plano ao serem contratados; troque para o Gestor ou o RH para ver um exemplo.'), { icon: 'clipboard', cls: 'rhc-mt0' });
      }
      if (!plans.some(function (p) { return p.id === local.planId; })) local.planId = plans[0].id;
      var plan = plans.filter(function (p) { return p.id === local.planId; })[0];
      var parts = head;
      if (ctx.actor.role === 'hr') parts += UI.card('Planos em andamento', overview(ctx, plans), { icon: 'list', cls: 'rhc-mt0' });
      parts += activationCard(ctx, plan);
      parts += UI.card('Checklist de onboarding', checklist(ctx, plan), { icon: 'clipboard', cls: ctx.actor.role === 'hr' ? '' : 'rhc-mt0' });
      return parts;
    },
    reset: function () {
      local.planId = null;
    }
  };

  UI.on('onb.open', function (el) {
    local.planId = el.getAttribute('data-plan');
    RH.app.render();
  });
  UI.on('onb.toggle', function (el) {
    var r = RH.store.act(function (st, actor) { return A.onboarding.setTask(st, actor, el.getAttribute('data-plan'), el.getAttribute('data-task'), el.checked); });
    if (!r.ok) UI.toast(r.error, 'danger');
    else UI.toast(el.checked ? 'Tarefa concluída.' : 'Tarefa reaberta.', 'success');
  });
  UI.on('onb.activate', function (form) {
    var d = UI.formData(form);
    var num = form.getAttribute('data-emp');
    var r = RH.store.act(function (st, actor) { return A.onboarding.activate(st, actor, { empNum: num, number: d.number, hireDate: d.hireDate, salary: d.salary }); });
    if (r.ok) {
      local.planId = RH.store.state.onboardingPlans[0].id;
      UI.toast(r.employee.name + ' ativado como ' + r.employee.num + '. Já aparece no organograma, sob o gestor da vaga.', 'success');
    } else UI.toast(r.error, 'danger');
  });
})(globalThis);
