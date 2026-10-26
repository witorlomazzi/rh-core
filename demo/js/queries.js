/* RH Core demo: consultas sobre o estado (equivalente aos Selectors do produto). Sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) {
    require('./util.js');
    require('./rules-leave.js');
    require('./rules-visibility.js');
    require('./rules-approval.js');
  }
  var RH = (g.RH = g.RH || {});
  var U = RH.util;
  var V = RH.visibility;
  var L = RH.leave;

  function index(st) {
    return V.buildIndex(st.employees);
  }
  function emp(st, num) {
    return st.employees.filter(function (e) { return e.num === num; })[0] || null;
  }
  function deptName(st, code) {
    var d = st.departments.filter(function (x) { return x.code === code; })[0];
    return d ? d.name : code;
  }
  function posName(st, code) {
    return st.positions[code] ? st.positions[code].name : code;
  }
  function firstName(name) {
    return String(name || '').split(' ')[0];
  }
  function directReports(st, num) {
    return st.employees.filter(function (e) { return e.mgr === num && e.status !== 'Pre_Admissao'; });
  }
  function leaveRequestsOf(st, empNum) {
    return st.leaveRequests.filter(function (r) { return r.empNum === empNum; });
  }
  function periodsOf(st, empNum) {
    var e = emp(st, empNum);
    if (!e) return [];
    var ps = L.buildPeriods(e, { today: st.today, settings: st.settings, absenceRules: st.absenceRules, requests: st.leaveRequests });
    return ps
      .map(function (p) {
        var bal = L.balanceOf(p, st.leaveRequests);
        return { period: p, bal: bal, status: L.periodStatus(p, bal, st.today, st.settings) };
      })
      .reverse();
  }
  function holidaySetFor(st, e) {
    return L.holidayDates(st.holidays, e.location);
  }
  /** Colegas de mesmo gestor direto com ferias vivas (pendentes ou aprovadas). */
  function teamLeaves(st, e, excludeId) {
    var mates = st.employees.filter(function (x) { return x.mgr === e.mgr && x.num !== e.num; }).map(function (x) { return x.num; });
    return st.leaveRequests
      .filter(function (r) {
        return r.id !== excludeId && mates.indexOf(r.empNum) >= 0 && ['Pendente', 'Aprovado', 'Em_Gozo'].indexOf(r.status) >= 0;
      })
      .map(function (r) {
        return { name: emp(st, r.empNum).name, start: r.start, end: L.requestEnd(r), status: r.status };
      });
  }
  function jobById(st, id) {
    return st.jobs.filter(function (j) { return j.id === id; })[0] || null;
  }
  function candidateById(st, id) {
    return st.candidates.filter(function (c) { return c.id === id; })[0] || null;
  }
  function appById(st, id) {
    return st.applications.filter(function (a) { return a.id === id; })[0] || null;
  }
  function planOf(st, empNum) {
    return st.onboardingPlans.filter(function (p) { return p.empNum === empNum; })[0] || null;
  }

  /** Itens da caixa de aprovacoes do ator: etapas atuais em que ele pode decidir. */
  function inbox(st, actor) {
    var items = [];
    function scan(kind, list) {
      list.forEach(function (r) {
        if (r.status !== 'Pendente') return;
        var step = RH.approval.currentStepOf(r);
        if (!step) return;
        var can = RH.approval.canDecide(r, actor);
        items.push({ kind: kind, req: r, step: step, canDecide: can });
      });
    }
    scan('Leave', st.leaveRequests);
    scan('Promotion', st.promotions);
    return items;
  }

  RH.q = {
    index: index,
    emp: emp,
    deptName: deptName,
    posName: posName,
    firstName: firstName,
    directReports: directReports,
    leaveRequestsOf: leaveRequestsOf,
    periodsOf: periodsOf,
    holidaySetFor: holidaySetFor,
    teamLeaves: teamLeaves,
    jobById: jobById,
    candidateById: candidateById,
    appById: appById,
    planOf: planOf,
    inbox: inbox
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.q;
})(globalThis);
