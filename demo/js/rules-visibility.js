/* RH Core demo: personas, visibilidade (sharing por cadeia de gestores) e FLS de salario (spec 02).
   Puro, sem DOM. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) require('./util.js');
  var RH = (g.RH = g.RH || {});

  var PERSONAS = {
    colaborador: { key: 'colaborador', label: 'Colaborador', role: 'employee', empNum: 'VTR-0015', icon: 'person', desc: 'Carolina Fontes, analista de vendas' },
    gestor: { key: 'gestor', label: 'Gestor', role: 'manager', empNum: 'VTR-0007', icon: 'team', desc: 'Patrícia Lemos, coordenadora' },
    rh: { key: 'rh', label: 'RH', role: 'hr', empNum: 'VTR-0031', icon: 'shield', desc: 'Cláudia Rezende, analista de RH' },
    recrutador: { key: 'recrutador', label: 'Recrutador', role: 'recruiter', empNum: 'VTR-0032', icon: 'briefcase', desc: 'Marcelo Ibrahim, recrutamento' },
    candidato: { key: 'candidato', label: 'Candidato', role: 'candidate', empNum: null, icon: 'globe', desc: 'Visitante do portal, sem login' }
  };
  var PERSONA_ORDER = ['colaborador', 'gestor', 'rh', 'recrutador', 'candidato'];

  var NAV = {
    colaborador: ['home', 'org', 'leave', 'performance', 'onboarding'],
    gestor: ['home', 'org', 'leave', 'approvals', 'promotions', 'recruiting', 'performance', 'onboarding'],
    rh: ['dashboard', 'org', 'leave', 'approvals', 'promotions', 'recruiting', 'performance', 'onboarding', 'portal'],
    recrutador: ['recruiting', 'dashboard', 'org', 'portal'],
    candidato: ['portal']
  };
  var DEFAULT_VIEW = { colaborador: 'home', gestor: 'home', rh: 'dashboard', recrutador: 'recruiting', candidato: 'portal' };
  var VIEW_META = {
    home: { label: 'Meu RH', icon: 'home' },
    dashboard: { label: 'Painel', icon: 'chart' },
    org: { label: 'Organograma', icon: 'org' },
    leave: { label: 'Férias', icon: 'calendar' },
    approvals: { label: 'Aprovações', icon: 'inbox' },
    promotions: { label: 'Promoções', icon: 'trendUp' },
    recruiting: { label: 'Recrutamento', icon: 'briefcase' },
    performance: { label: 'Desempenho', icon: 'star' },
    onboarding: { label: 'Onboarding', icon: 'clipboard' },
    portal: { label: 'Portal de vagas', icon: 'globe' }
  };

  function buildIndex(employees) {
    var byNum = {};
    var children = {};
    employees.forEach(function (e) {
      byNum[e.num] = e;
      children[e.num] = children[e.num] || [];
    });
    employees.forEach(function (e) {
      if (e.mgr && children[e.mgr]) children[e.mgr].push(e.num);
    });
    return { byNum: byNum, children: children };
  }
  function ancestors(idx, num) {
    var out = [];
    var cur = idx.byNum[num];
    var guard = 0;
    while (cur && cur.mgr && guard++ < 50) {
      out.push(cur.mgr);
      cur = idx.byNum[cur.mgr];
    }
    return out;
  }
  function subtree(idx, num) {
    var out = [];
    var stack = (idx.children[num] || []).slice();
    while (stack.length) {
      var n = stack.shift();
      out.push(n);
      (idx.children[n] || []).forEach(function (c) {
        stack.push(c);
      });
    }
    return out;
  }
  function isInChainOf(idx, managerNum, subjectNum) {
    return ancestors(idx, subjectNum).indexOf(managerNum) >= 0;
  }

  /**
   * Conjunto de matriculas que a persona enxerga. Colaborador e Recrutador: a si e a cadeia de gestores.
   * Gestor: a si, a cadeia e a subarvore (equipe direta e indireta). RH: todos. Candidato: ninguem.
   */
  function visibleSet(personaKey, idx, employees) {
    var p = PERSONAS[personaKey];
    var set = {};
    if (p.role === 'hr') {
      employees.forEach(function (e) { set[e.num] = true; });
      return set;
    }
    if (!p.empNum) return set;
    set[p.empNum] = true;
    ancestors(idx, p.empNum).forEach(function (n) { set[n] = true; });
    if (p.role === 'manager') subtree(idx, p.empNum).forEach(function (n) { set[n] = true; });
    return set;
  }
  /** Quem a persona pode consultar em detalhe (ferias, avaliacao): a si, subarvore (gestor) ou todos (RH). */
  function canSeeDetail(personaKey, idx, num) {
    var p = PERSONAS[personaKey];
    if (p.role === 'hr') return true;
    if (!p.empNum) return false;
    if (num === p.empNum) return true;
    return p.role === 'manager' && isInChainOf(idx, p.empNum, num);
  }
  /** FLS: salario so para os permission sets de RH. */
  function canSeeSalary(personaKey) {
    return PERSONAS[personaKey].role === 'hr';
  }
  function actorFor(personaKey) {
    var p = PERSONAS[personaKey];
    return { persona: personaKey, role: p.role, empNum: p.empNum };
  }

  RH.visibility = {
    PERSONAS: PERSONAS,
    PERSONA_ORDER: PERSONA_ORDER,
    NAV: NAV,
    DEFAULT_VIEW: DEFAULT_VIEW,
    VIEW_META: VIEW_META,
    buildIndex: buildIndex,
    ancestors: ancestors,
    subtree: subtree,
    isInChainOf: isInChainOf,
    visibleSet: visibleSet,
    canSeeDetail: canSeeDetail,
    canSeeSalary: canSeeSalary,
    actorFor: actorFor
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.visibility;
})(globalThis);
