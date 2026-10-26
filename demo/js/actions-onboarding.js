/* RH Core demo: acoes de admissao e onboarding (OnboardingService, spec 15). Sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) require('./queries.js');
  var RH = (g.RH = g.RH || {});
  RH.actions = RH.actions || {};
  var U = RH.util;
  var Q = RH.q;

  function planById(st, id) {
    return st.onboardingPlans.filter(function (p) { return p.id === id; })[0] || null;
  }
  function progress(plan) {
    var total = plan.tasks.length;
    var done = plan.tasks.filter(function (t) { return t.status === 'Concluida'; }).length;
    return { total: total, done: done, percent: total ? Math.round((done / total) * 100) : 0 };
  }

  /** O5: so o responsavel pela tarefa ou o RH conclui. Plano vira Concluido quando todas estao resolvidas. */
  function setTask(st, actor, planId, taskId, done) {
    var plan = planById(st, planId);
    if (!plan) return { ok: false, error: 'Plano não encontrado.' };
    var task = plan.tasks.filter(function (t) { return t.id === taskId; })[0];
    if (!task) return { ok: false, error: 'Tarefa não encontrada.' };
    if (task.assigned !== actor.empNum && actor.role !== 'hr') return { ok: false, error: 'Somente o responsável pela tarefa ou o RH pode concluí-la.' };
    task.status = done ? 'Concluida' : 'Pendente';
    task.completedAt = done ? st.today : null;
    var open = plan.tasks.some(function (t) { return t.status === 'Pendente'; });
    var emp = Q.emp(st, plan.empNum);
    if (!open) plan.status = 'Concluido';
    else if (plan.status === 'Concluido') plan.status = emp && emp.status === 'Pre_Admissao' ? 'Nao_Iniciado' : 'Em_Andamento';
    return { ok: true, plan: plan };
  }

  /** O4 e O6: ativa o colaborador em pre-admissao (so RH). */
  function activate(st, actor, input) {
    if (actor.role !== 'hr') return { ok: false, error: 'Somente o RH ativa a admissão.' };
    var emp = Q.emp(st, input.empNum);
    if (!emp || emp.status !== 'Pre_Admissao') return { ok: false, error: 'Este colaborador não está em pré-admissão.' };
    var number = (input.number || '').trim().toUpperCase();
    if (!/^VTR-\d{4}$/.test(number)) return { ok: false, error: 'Use a matrícula no formato VTR-0000.' };
    if (st.employees.some(function (e) { return e.num === number; })) return { ok: false, error: 'Esta matrícula já está em uso.' };
    if (!input.hireDate || !/^\d{4}-\d{2}-\d{2}$/.test(input.hireDate)) return { ok: false, error: 'Informe a data de admissão.' };
    var salary = input.salary ? Number(input.salary) : null;
    if (input.salary && !(salary > 0)) return { ok: false, error: 'Informe um salário válido.' };
    var old = emp.num;
    var plan = Q.planOf(st, old);
    emp.num = number;
    emp.status = 'Ativo';
    emp.hire = input.hireDate;
    emp.salary = salary;
    if (plan) {
      // O6: recalcula as datas das tarefas pendentes a partir da nova admissao.
      plan.empNum = number;
      plan.start = input.hireDate;
      plan.status = 'Em_Andamento';
      plan.tasks.forEach(function (t, i) {
        if (t.assigned === old) t.assigned = number;
        if (t.status === 'Pendente') t.due = U.addDays(input.hireDate, st.onboardingTemplates[i] ? st.onboardingTemplates[i].offset : 0);
      });
      var anyOpen = plan.tasks.some(function (t) { return t.status === 'Pendente'; });
      if (!anyOpen) plan.status = 'Concluido';
    }
    st.applications.forEach(function (a) { if (a.employeeNum === old) a.employeeNum = number; });
    st.positionHistory.push({ empNum: number, pos: emp.pos, dept: emp.dept, start: input.hireDate, end: null, salary: salary, reason: 'Admissao', promotionId: null });
    return { ok: true, employee: emp };
  }

  /** Planos que a persona pode ver: RH todos; gestor, os da equipe; colaborador, o proprio. */
  function visiblePlans(st, actor) {
    var idx = Q.index(st);
    return st.onboardingPlans.filter(function (p) {
      if (actor.role === 'hr') return true;
      if (p.empNum === actor.empNum) return true;
      if (actor.role === 'manager') return RH.visibility.isInChainOf(idx, actor.empNum, p.empNum);
      return false;
    });
  }

  RH.actions.onboarding = { planById: planById, progress: progress, setTask: setTask, activate: activate, visiblePlans: visiblePlans };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.actions.onboarding;
})(globalThis);
