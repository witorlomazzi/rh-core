/* RH Core demo: organograma navegavel (spec 10, coreOrgChart) com visibilidade por persona e FLS de salario. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var V = RH.visibility;

  var local = { persona: null, expanded: {}, query: '', mode: 'tree', selected: null, showFormer: false };

  function norm(s) {
    return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  }

  function model(ctx) {
    var st = ctx.st;
    var idx = Q.index(st);
    var set = V.visibleSet(ctx.persona, idx, st.employees);
    var emps = st.employees.filter(function (e) {
      if (!set[e.num] || e.status === 'Pre_Admissao') return false;
      return e.status !== 'Desligado' || (ctx.persona === 'rh' && local.showFormer);
    });
    var vis = {};
    emps.forEach(function (e) { vis[e.num] = e; });
    var kids = {};
    emps.forEach(function (e) {
      if (e.mgr && vis[e.mgr]) (kids[e.mgr] = kids[e.mgr] || []).push(e);
    });
    var roots = emps.filter(function (e) { return !e.mgr || !vis[e.mgr]; });
    return { emps: emps, vis: vis, kids: kids, roots: roots, idx: idx };
  }

  function resetFor(ctx) {
    if (local.persona === ctx.persona) return;
    local.persona = ctx.persona;
    local.expanded = {};
    local.query = '';
    local.mode = 'tree';
    local.showFormer = false;
    var me = V.PERSONAS[ctx.persona].empNum;
    var idx = Q.index(ctx.st);
    if (ctx.persona === 'rh') {
      local.expanded['VTR-0001'] = true;
      (idx.children['VTR-0001'] || []).forEach(function (n) { local.expanded[n] = true; });
    }
    if (me) {
      V.ancestors(idx, me).forEach(function (n) { local.expanded[n] = true; });
      local.expanded[me] = true;
    }
    local.selected = me;
  }

  function inScope(ctx, m, e) {
    var p = V.PERSONAS[ctx.persona];
    if (p.role === 'hr') return true;
    if (p.role === 'manager') return e.num === p.empNum || V.isInChainOf(m.idx, p.empNum, e.num);
    return false;
  }

  function statusChip(e) {
    if (e.status === 'Ferias') return UI.badge('Em férias', 'info', 'sun');
    if (e.status === 'Desligado') return UI.badge('Desligado', 'neutral', 'ban');
    if (e.type === 'Estagio') return UI.badge('Estágio', 'neutral');
    return '';
  }

  function mark(text, q) {
    if (!q) return esc(text);
    var n = norm(text);
    var i = n.indexOf(q);
    if (i < 0) return esc(text);
    return esc(text.slice(0, i)) + '<mark>' + esc(text.slice(i, i + q.length)) + '</mark>' + esc(text.slice(i + q.length));
  }

  function cardHtml(ctx, m, e, q, open, hasKids) {
    var me = V.PERSONAS[ctx.persona].empNum;
    var count = (m.kids[e.num] || []).length;
    var showCount = inScope(ctx, m, e) && hasKids;
    var isSel = local.selected === e.num;
    var toggle = hasKids
      ? '<button type="button" class="rhc-org-toggle" data-act="org.toggle" data-num="' + e.num + '" aria-expanded="' + (open ? 'true' : 'false') + '" aria-label="' + (open ? 'Recolher' : 'Expandir') + ' equipe de ' + esc(e.name) + '"' + (q ? ' disabled' : '') + '>' + UI.icon(open ? 'chevronDown' : 'chevronRight') + '</button>'
      : '<span class="rhc-org-toggle rhc-org-toggle-empty" aria-hidden="true"></span>';
    return (
      '<div class="rhc-org-card' + (isSel ? ' is-selected' : '') + (e.num === me ? ' is-me' : '') + (e.status === 'Desligado' ? ' is-former' : '') + '">' + toggle +
      '<button type="button" class="rhc-org-main" data-act="org.select" data-key="org.key" data-num="' + e.num + '" aria-pressed="' + (isSel ? 'true' : 'false') + '">' +
      UI.avatar(e.name) +
      '<span class="rhc-org-text"><strong>' + mark(e.name, q) + '</strong><small>' + mark(Q.posName(ctx.st, e.pos), q) + ' · ' + mark(Q.deptName(ctx.st, e.dept), q) + '</small></span>' +
      '<span class="rhc-org-tags">' + (e.num === me ? UI.badge('Você', 'info') : '') + statusChip(e) + (showCount ? UI.badge(count + (count === 1 ? ' pessoa' : ' pessoas'), 'neutral', 'users') : '') + '</span>' +
      '</button></div>'
    );
  }

  function nodeHtml(ctx, m, e, q) {
    var allKids = m.kids[e.num] || [];
    var hasKids = allKids.length > 0;
    var kids = q ? allKids.filter(function (k) { return q.keep[k.num]; }) : allKids;
    var open = q ? kids.length > 0 : !!local.expanded[e.num];
    return (
      '<li>' + cardHtml(ctx, m, e, q ? q.text : '', open, hasKids) +
      (hasKids && open && kids.length ? '<ul>' + kids.map(function (k) { return nodeHtml(ctx, m, k, q); }).join('') + '</ul>' : '') +
      '</li>'
    );
  }

  function searchModel(m) {
    var text = norm(local.query.trim());
    if (!text) return null;
    var keep = {};
    var hits = 0;
    m.emps.forEach(function (e) {
      var hay = norm(e.name + ' ' + e.num + ' ' + Q.posName(RH.store.state, e.pos) + ' ' + Q.deptName(RH.store.state, e.dept));
      if (hay.indexOf(text) >= 0) {
        hits++;
        keep[e.num] = true;
        V.ancestors(m.idx, e.num).forEach(function (a) {
          if (m.vis[a]) keep[a] = true;
        });
      }
    });
    return { text: text, keep: keep, hits: hits };
  }

  function treeHtml(ctx) {
    var m = model(ctx);
    var q = searchModel(m);
    if (q && !q.hits) return UI.empty('search', 'Ninguém encontrado', 'Nenhum colaborador visível para você corresponde a "' + local.query + '".');
    var roots = q ? m.roots.filter(function (r) { return q.keep[r.num]; }) : m.roots;
    return '<ul class="rhc-org-tree" aria-label="Organograma">' + roots.map(function (r) { return nodeHtml(ctx, m, r, q); }).join('') + '</ul>' + (q ? '<p class="rhc-muted rhc-org-hits" role="status">' + q.hits + (q.hits === 1 ? ' resultado' : ' resultados') + '</p>' : '');
  }

  function listHtml(ctx) {
    var m = model(ctx);
    var canSal = V.canSeeSalary(ctx.persona);
    var rows = m.emps.slice().sort(function (a, b) { return a.num < b.num ? -1 : 1; }).map(function (e) {
      var mgr = e.mgr ? Q.emp(ctx.st, e.mgr) : null;
      return (
        '<tr><td data-label="Matrícula">' + esc(e.num) + '</td><td data-label="Nome"><button type="button" class="rhc-link" data-act="org.select" data-num="' + e.num + '">' + esc(e.name) + '</button></td>' +
        '<td data-label="Cargo">' + esc(Q.posName(ctx.st, e.pos)) + '</td><td data-label="Departamento">' + esc(Q.deptName(ctx.st, e.dept)) + '</td>' +
        '<td data-label="Gestor">' + (mgr ? esc(mgr.name) : '<span class="rhc-muted">-</span>') + '</td><td data-label="Admissão">' + U.fmtBR(e.hire) + '</td>' +
        '<td data-label="Status">' + (statusChip(e) || UI.badge('Ativo', 'success', 'check')) + '</td><td data-label="Salário">' + UI.salaryCell(e.salary, canSal) + '</td></tr>'
      );
    }).join('');
    return (
      '<div class="rhc-tablewrap"><table class="rhc-table rhc-table-stack"><caption class="rhc-sr">Colaboradores visíveis para a persona atual</caption><thead><tr><th scope="col">Matrícula</th><th scope="col">Nome</th><th scope="col">Cargo</th><th scope="col">Departamento</th><th scope="col">Gestor</th><th scope="col">Admissão</th><th scope="col">Status</th><th scope="col">Salário</th></tr></thead><tbody>' + rows + '</tbody></table></div>'
    );
  }

  function detailHtml(ctx) {
    var st = ctx.st;
    var e = local.selected ? Q.emp(st, local.selected) : null;
    var m = model(ctx);
    if (!e || !m.vis[e.num]) return UI.empty('person', 'Selecione um cartão', 'Escolha uma pessoa no organograma para ver o cadastro dela.');
    var mgr = e.mgr ? Q.emp(st, e.mgr) : null;
    var canSal = V.canSeeSalary(ctx.persona);
    var detail = V.canSeeDetail(ctx.persona, m.idx, e.num);
    var hist = st.positionHistory.filter(function (h) { return h.empNum === e.num; }).sort(function (a, b) { return a.start < b.start ? 1 : -1; });
    var kids = (m.kids[e.num] || []).length;
    var out =
      '<div class="rhc-detail-head">' + UI.avatar(e.name) + '<div><h4>' + esc(e.name) + '</h4><p>' + esc(Q.posName(st, e.pos)) + ' · ' + esc(Q.deptName(st, e.dept)) + '</p></div></div>' +
      '<dl class="rhc-kvlist">' +
      UI.kv('Matrícula', esc(e.num)) +
      UI.kv('E-mail', esc(e.email)) +
      UI.kv('Gestor direto', mgr ? esc(mgr.name) : '<span class="rhc-muted">Sem gestor (topo)</span>') +
      UI.kv('Admissão', U.fmtBR(e.hire) + ' <span class="rhc-muted">(' + esc(U.tenureText(e.hire, st.today)) + ')</span>') +
      UI.kv('Vínculo', esc(e.type === 'Estagio' ? 'Estágio' : e.type)) +
      UI.kv('Localidade', esc(e.location)) +
      UI.kv('Salário', UI.salaryCell(e.salary, canSal)) +
      (kids ? UI.kv('Equipe direta visível', kids + (kids === 1 ? ' pessoa' : ' pessoas')) : '') +
      '</dl>';
    if (!canSal) {
      out += '<p class="rhc-note">' + UI.icon('lock') + '<span>O salário existe no cadastro, mas o campo é protegido por segurança em nível de campo (FLS). Só os permission sets de RH o leem. Troque para a persona <strong>RH</strong> para comparar.</span></p>';
    }
    if (!detail) {
      out += '<p class="rhc-note rhc-note-info">' + UI.icon('shield') + '<span>Você enxerga esta pessoa apenas como parte da cadeia de gestores (nome e cargo). Histórico, férias e avaliações dela não são compartilhados com você.</span></p>';
    } else {
      out += '<h5 class="rhc-subtitle">Linha do tempo de cargos</h5><ol class="rhc-timeline">' + hist.map(function (h) {
        var reason = { Admissao: 'Admissão', Promocao: 'Promoção', Merito: 'Mérito', Transferencia: 'Transferência' }[h.reason] || h.reason;
        return (
          '<li><span class="rhc-timeline-dot"></span><div><strong>' + esc(Q.posName(st, h.pos)) + '</strong>' +
          '<small>' + U.fmtBR(h.start) + ' a ' + (h.end ? U.fmtBR(h.end) : 'hoje') + ' · ' + esc(reason) + '</small>' +
          (canSal && h.salary ? '<small class="rhc-money">' + esc(U.brl(h.salary)) + '</small>' : '') + '</div></li>'
        );
      }).join('') + '</ol>';
    }
    return out;
  }

  var VISIBILITY_NOTE = {
    colaborador: 'Você vê o seu cadastro e a cadeia de gestores acima de você. Colegas não aparecem: dado de pessoa é privado por padrão.',
    gestor: 'Você vê a sua equipe direta e indireta (a subárvore) e a cadeia acima de você. Outras equipes ficam fora do seu alcance.',
    rh: 'O RH enxerga a empresa inteira, inclusive o salário, por View All e FLS nos permission sets de RH.',
    recrutador: 'O recrutador é um colaborador comum nesta tela: vê o próprio cadastro e a cadeia de gestores.',
    candidato: ''
  };

  RH.views.org = {
    render: function (ctx) {
      resetFor(ctx);
      var m = model(ctx);
      var depts = {};
      m.emps.forEach(function (e) { depts[e.dept] = true; });
      var mode = local.mode;
      var body =
        '<div class="rhc-toolbar">' +
        '<div class="rhc-search">' + UI.icon('search') + '<label class="rhc-sr" for="rhc-org-q">Buscar colaborador</label><input id="rhc-org-q" type="search" placeholder="Buscar por nome, cargo, departamento ou matrícula" value="' + esc(local.query) + '" data-input="org.search" autocomplete="off"></div>' +
        '<div class="rhc-seg" role="group" aria-label="Modo de exibição">' +
        '<button type="button" class="' + (mode === 'tree' ? 'is-active' : '') + '" data-act="org.mode" data-mode="tree" aria-pressed="' + (mode === 'tree') + '">' + UI.icon('org') + 'Árvore</button>' +
        '<button type="button" class="' + (mode === 'list' ? 'is-active' : '') + '" data-act="org.mode" data-mode="list" aria-pressed="' + (mode === 'list') + '">' + UI.icon('list') + 'Lista</button></div>' +
        (ctx.persona === 'rh' ? '<label class="rhc-inline-check"><input type="checkbox" data-change="org.former"' + (local.showFormer ? ' checked' : '') + '> Mostrar desligados</label>' : '') +
        '</div>' +
        '<p class="rhc-note rhc-note-info">' + UI.icon('shield') + '<span>' + esc(VISIBILITY_NOTE[ctx.persona]) + '</span></p>';
      var main = mode === 'tree' ? '<div id="rhc-org-tree">' + treeHtml(ctx) + '</div>' : '<div id="rhc-org-tree">' + listHtml(ctx) + '</div>';
      return (
        UI.pageHead('Organograma', m.emps.length + (m.emps.length === 1 ? ' pessoa visível' : ' pessoas visíveis') + ' em ' + Object.keys(depts).length + ' departamento(s) da Vetra Distribuidora.') +
        '<div class="rhc-split">' + UI.card('Estrutura', body + main, { icon: 'org', cls: 'rhc-split-main' }) + UI.card('Cadastro', '<div id="rhc-org-detail">' + detailHtml(ctx) + '</div>', { icon: 'person', cls: 'rhc-split-side' }) + '</div>'
      );
    }
  };

  function refreshTree() {
    var ctx = RH.app.ctx();
    var host = document.getElementById('rhc-org-tree');
    if (host) host.innerHTML = local.mode === 'tree' ? treeHtml(ctx) : listHtml(ctx);
    var d = document.getElementById('rhc-org-detail');
    if (d) d.innerHTML = detailHtml(ctx);
  }
  UI.on('org.search', function (el) {
    local.query = el.value;
    refreshTree();
  });
  UI.on('org.toggle', function (el) {
    var n = el.getAttribute('data-num');
    local.expanded[n] = !local.expanded[n];
    RH.app.render('org.toggle:' + n);
  });
  UI.on('org.select', function (el) {
    local.selected = el.getAttribute('data-num');
    RH.app.render('org.select:' + local.selected);
  });
  UI.on('org.mode', function (el) {
    local.mode = el.getAttribute('data-mode');
    RH.app.render('org.mode:' + local.mode);
  });
  UI.on('org.former', function (el) {
    local.showFormer = el.checked;
    RH.app.render('org.former');
  });
  // Navegacao por teclado entre os cartoes: setas, Home e End.
  UI.on('org.key', function (el, ev) {
    var keys = ['ArrowDown', 'ArrowUp', 'ArrowRight', 'ArrowLeft', 'Home', 'End'];
    if (keys.indexOf(ev.key) < 0) return;
    var all = Array.prototype.slice.call(document.querySelectorAll('#rhc-org-tree .rhc-org-main'));
    var i = all.indexOf(el);
    var num = el.getAttribute('data-num');
    var toggle = el.parentNode.querySelector('.rhc-org-toggle[data-act]');
    var target = null;
    if (ev.key === 'ArrowDown') target = all[i + 1];
    else if (ev.key === 'ArrowUp') target = all[i - 1];
    else if (ev.key === 'Home') target = all[0];
    else if (ev.key === 'End') target = all[all.length - 1];
    else if (ev.key === 'ArrowRight') {
      if (toggle && toggle.getAttribute('aria-expanded') === 'false') {
        local.expanded[num] = true;
        RH.app.render('org.key:' + num);
        return ev.preventDefault();
      }
      target = all[i + 1];
    } else if (ev.key === 'ArrowLeft') {
      if (toggle && toggle.getAttribute('aria-expanded') === 'true' && !local.query) {
        local.expanded[num] = false;
        RH.app.render('org.key:' + num);
        return ev.preventDefault();
      }
      var parentLi = el.closest('ul') && el.closest('ul').parentNode;
      target = parentLi && parentLi.querySelector ? parentLi.querySelector('.rhc-org-main') : null;
    }
    if (target) {
      ev.preventDefault();
      target.focus();
    }
  });
})(globalThis);
