/* RH Core demo: avaliacao de desempenho (spec 16): metas, autoavaliacao, avaliacao do gestor, calibracao e liberacao. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var V = RH.visibility;
  var A = RH.actions;
  var PF = RH.performance;

  var local = { persona: null, tab: 'mine', self: null, goalErr: '' };

  function resetFor(ctx) {
    if (local.persona === ctx.persona) return;
    local.persona = ctx.persona;
    local.tab = ctx.actor.role === 'hr' ? 'admin' : 'mine';
    local.self = null;
    local.goalErr = '';
  }

  function phaseStepper(cycle) {
    var cur = PF.PHASES.indexOf(cycle.status);
    return '<ol class="rhc-phases" aria-label="Fases do ciclo">' + PF.PHASES.map(function (p, i) {
      var cls = i < cur ? 'is-done' : i === cur ? 'is-current' : '';
      return '<li class="' + cls + '"' + (i === cur ? ' aria-current="step"' : '') + '><span>' + (i < cur ? UI.icon('check') : i + 1) + '</span>' + esc(PF.PHASE_LABEL[p]) + '</li>';
    }).join('') + '</ol>';
  }

  function ratingButtons(name, value, disabled) {
    return '<div class="rhc-rating" role="radiogroup" aria-label="Nota de 1 a 5">' + [1, 2, 3, 4, 5].map(function (n) {
      return '<label class="rhc-rate' + (Number(value) === n ? ' is-on' : '') + '"><input type="radio" name="' + name + '" value="' + n + '"' + (Number(value) === n ? ' checked' : '') + (disabled ? ' disabled' : '') + '><span>' + n + '</span></label>';
    }).join('') + '</div>';
  }

  // ---------------------------------------------------------------- colaborador
  function goalsCard(ctx, empNum, editable) {
    var goals = A.performance.goalsOf(ctx.st, empNum);
    var sum = PF.weightSum(goals);
    var ok = sum === 100;
    var rows = goals.map(function (x) {
      return (
        '<tr><td data-label="Meta"><strong>' + esc(x.name) + '</strong><small class="rhc-cellsub">Alvo: ' + esc(x.target || '—') + '</small></td>' +
        '<td data-label="Peso">' + (editable ? '<label class="rhc-sr" for="gw-' + x.id + '">Peso de ' + esc(x.name) + '</label><input id="gw-' + x.id + '" class="rhc-num" type="number" min="1" max="100" value="' + x.weight + '" data-change="perf.goalWeight" data-id="' + x.id + '"> %' : x.weight + '%') + '</td>' +
        (editable ? '<td><button type="button" class="rhc-iconbtn" data-act="perf.goalDel" data-id="' + x.id + '" aria-label="Remover meta ' + esc(x.name) + '">' + UI.icon('trash') + '</button></td>' : '') + '</tr>'
      );
    }).join('');
    var add = editable
      ? '<form class="rhc-form rhc-inline-form" data-submit="perf.goalAdd" novalidate>' +
        UI.field({ id: 'ng-name', name: 'name', label: 'Nova meta', required: true }) + UI.field({ id: 'ng-target', name: 'target', label: 'Alvo' }) +
        UI.field({ id: 'ng-weight', name: 'weight', label: 'Peso (%)', type: 'number', attrs: 'min="1" max="100"', value: Math.max(0, 100 - sum) || '' }) +
        '<button type="submit" class="rhc-btn rhc-btn-secondary">' + UI.icon('plus') + 'Adicionar meta</button></form>' + (local.goalErr ? '<p class="rhc-error" role="alert">' + esc(local.goalErr) + '</p>' : '')
      : '';
    return (
      '<div class="rhc-weight ' + (ok ? 'is-ok' : 'is-bad') + '">' + UI.icon(ok ? 'check' : 'warning') + '<strong>' + sum + '%</strong><span>' + (ok ? 'Pesos fecham em 100%.' : 'Os pesos das metas ativas precisam somar 100% para enviar a autoavaliação.') + '</span></div>' +
      '<div class="rhc-tablewrap"><table class="rhc-table rhc-table-stack"><caption class="rhc-sr">Metas do ciclo</caption><thead><tr><th scope="col">Meta</th><th scope="col">Peso</th>' + (editable ? '<th scope="col"><span class="rhc-sr">Remover</span></th>' : '') + '</tr></thead><tbody>' + rows + '</tbody></table></div>' + add
    );
  }

  function mineHtml(ctx) {
    var st = ctx.st;
    var me = ctx.actor.empNum;
    var self = st.selfAssessments[me];
    var rv = st.reviews[me];
    if (!self) return UI.empty('info', 'Sem avaliação neste ciclo', 'Seu cadastro não está no ciclo atual.');
    var chk = PF.canEditSelf(st.cycle.status, self, me, me);
    var editableGoals = chk.ok;
    var draft = local.self || { rating: self.rating, strengths: self.strengths, improvements: self.improvements };
    var selfBody;
    if (self.submitted) {
      selfBody = '<p class="rhc-note rhc-note-ok">' + UI.icon('check') + '<span>Autoavaliação enviada em ' + U.fmtBR(self.submittedDate) + '. Ela não pode mais ser alterada.</span></p>' +
        '<dl class="rhc-kvlist">' + UI.kv('Minha nota', '<strong>' + self.rating + '</strong> de 5') + UI.kv('Pontos fortes', esc(self.strengths)) + UI.kv('A melhorar', esc(self.improvements)) + '</dl>';
    } else {
      selfBody =
        (chk.ok ? '' : '<p class="rhc-note rhc-note-warn">' + UI.icon('lock') + '<span>' + esc(chk.error) + '</span></p>') +
        '<form class="rhc-form" data-submit="perf.selfSend" novalidate><fieldset' + (chk.ok ? '' : ' disabled') + '><legend class="rhc-sr">Autoavaliação</legend>' +
        '<div class="rhc-field"><span class="rhc-label">Minha nota geral (1 a 5)</span>' + ratingButtons('rating', draft.rating, !chk.ok) + '</div>' +
        UI.field({ id: 'sf-str', name: 'strengths', label: 'Pontos fortes', type: 'textarea', rows: 3, value: draft.strengths }) +
        UI.field({ id: 'sf-imp', name: 'improvements', label: 'O que posso melhorar', type: 'textarea', rows: 3, value: draft.improvements }) +
        '<div class="rhc-actions"><button type="button" class="rhc-btn rhc-btn-ghost" data-act="perf.selfSave">' + UI.icon('edit') + 'Salvar rascunho</button><button type="submit" class="rhc-btn rhc-btn-primary">' + UI.icon('send') + 'Enviar autoavaliação</button></div></fieldset></form>';
    }
    var result;
    if (rv && rv.status === 'Liberada') {
      var fin = PF.finalRating(rv);
      result = '<div class="rhc-final">' + UI.icon('award') + '<div><small>Nota final do ciclo</small><strong>' + fin + ' / 5</strong></div></div>' +
        '<dl class="rhc-kvlist">' + UI.kv('Avaliação do gestor', '<strong>' + (rv.managerRating || '—') + '</strong> de 5') + UI.kv('Comentários do gestor', esc(rv.comments || '—')) + UI.kv('Liberada em', U.fmtBR(rv.releasedDate)) + '</dl>';
    } else {
      result = UI.empty('lock', 'Resultado ainda não liberado', 'A avaliação do seu gestor só fica visível depois que o RH calibrar as notas e liberar o ciclo. Até lá, ela não aparece para você.');
    }
    return (
      UI.card('Ciclo ' + st.cycle.name.replace('Ciclo ', ''), phaseStepper(st.cycle) + '<p class="rhc-muted">Autoavaliação até ' + U.fmtBR(st.cycle.selfDue) + ' · avaliação do gestor até ' + U.fmtBR(st.cycle.managerDue) + '</p>', { icon: 'star', cls: 'rhc-mt0' }) +
      UI.card('Minhas metas', goalsCard(ctx, me, editableGoals), { icon: 'target' }) +
      UI.card('Minha autoavaliação', selfBody, { icon: 'edit' }) +
      UI.card('Resultado', result, { icon: 'award' })
    );
  }

  // ---------------------------------------------------------------- gestor
  function reviewBadge(rv) {
    var tone = { Pendente: 'neutral', Em_Andamento: 'info', Enviada: 'success', Calibrada: 'success', Liberada: 'success' }[rv.status];
    return UI.badge(PF.REVIEW_LABEL[rv.status], tone, rv.status === 'Pendente' ? 'clock' : 'check');
  }
  function teamHtml(ctx) {
    var st = ctx.st;
    var idx = Q.index(st);
    var team = V.subtree(idx, ctx.actor.empNum).map(function (n) { return idx.byNum[n]; }).filter(function (e) { return st.reviews[e.num]; });
    var phaseTxt = st.cycle.status === 'Avaliacao_Gestor' ? '' : '<p class="rhc-note rhc-note-warn">' + UI.icon('lock') + '<span>Fase atual: <strong>' + esc(PF.PHASE_LABEL[st.cycle.status]) + '</strong>. A avaliação do gestor só abre na fase "Avaliação do gestor", quando o RH avança o ciclo. Você pode abrir os cartões para ler, mas o envio será recusado.</span></p>';
    var rows = team.map(function (e) {
      var self = st.selfAssessments[e.num];
      var rv = st.reviews[e.num];
      var direct = rv.reviewer === ctx.actor.empNum;
      return (
        '<tr><td data-label="Colaborador"><div class="rhc-person">' + UI.avatar(e.name) + '<div><strong>' + esc(e.name) + '</strong><small>' + esc(Q.posName(st, e.pos)) + (direct ? '' : ' · equipe indireta') + '</small></div></div></td>' +
        '<td data-label="Autoavaliação">' + (self && self.submitted ? UI.badge('Enviada · nota ' + self.rating, 'success', 'check') : UI.badge('Não enviada', 'neutral', 'clock')) + '</td>' +
        '<td data-label="Avaliação">' + reviewBadge(rv) + (rv.managerRating ? ' <small class="rhc-muted">nota ' + rv.managerRating + '</small>' : '') + '</td>' +
        '<td data-label="Nota calibrada">' + UI.locked('Nota calibrada restrita ao RH').replace('R$ ••••••', '•••') + '</td>' +
        '<td><button type="button" class="rhc-btn rhc-btn-secondary rhc-btn-sm" data-act="perf.openReview" data-num="' + e.num + '">' + UI.icon(direct ? 'edit' : 'eye') + (direct ? 'Avaliar' : 'Ver') + '</button></td></tr>'
      );
    }).join('');
    return phaseTxt + '<div class="rhc-tablewrap"><table class="rhc-table rhc-table-stack"><caption class="rhc-sr">Avaliações da equipe</caption><thead><tr><th scope="col">Colaborador</th><th scope="col">Autoavaliação</th><th scope="col">Sua avaliação</th><th scope="col">Nota calibrada</th><th scope="col"><span class="rhc-sr">Ações</span></th></tr></thead><tbody>' + rows + '</tbody></table></div>' +
      '<p class="rhc-note">' + UI.icon('lock') + '<span>A nota calibrada pelo RH é um campo restrito (FLS): o gestor não a lê, mesmo depois da liberação.</span></p>';
  }

  function openReview(num) {
    var ctx = RH.app.ctx();
    var st = ctx.st;
    var e = Q.emp(st, num);
    var self = st.selfAssessments[num];
    var rv = st.reviews[num];
    var goals = A.performance.goalsOf(st, num);
    var direct = rv.reviewer === ctx.actor.empNum;
    var locked = rv.status === 'Enviada' || rv.status === 'Calibrada' || rv.status === 'Liberada';
    UI.modal({
      title: 'Avaliação de ' + e.name,
      wide: true,
      confirm: direct && !locked ? 'Enviar avaliação' : 'Fechar',
      cancel: direct && !locked ? 'Salvar rascunho' : false,
      body:
        '<h5 class="rhc-subtitle">Metas (' + PF.weightSum(goals) + '% dos pesos)</h5><ul class="rhc-abslist">' + goals.map(function (x) { return '<li>' + UI.icon('target') + '<span>' + esc(x.name) + '</span>' + UI.badge(x.weight + '%', 'neutral') + '</li>'; }).join('') + '</ul>' +
        '<h5 class="rhc-subtitle">Autoavaliação</h5>' + (self.submitted ? '<dl class="rhc-kvlist">' + UI.kv('Nota', '<strong>' + self.rating + '</strong> de 5') + UI.kv('Pontos fortes', esc(self.strengths)) + UI.kv('A melhorar', esc(self.improvements)) + '</dl>' : '<p class="rhc-muted">O colaborador ainda não enviou a autoavaliação.</p>') +
        '<h5 class="rhc-subtitle">Sua avaliação</h5>' + (direct && !locked
          ? '<div class="rhc-field"><span class="rhc-label">Nota (1 a 5)</span>' + ratingButtons('rating', rv.managerRating, false) + '</div>' + UI.field({ id: 'mr-com', name: 'comments', label: 'Comentários', type: 'textarea', rows: 4, value: rv.comments })
          : '<dl class="rhc-kvlist">' + UI.kv('Status', esc(PF.REVIEW_LABEL[rv.status])) + UI.kv('Nota', rv.managerRating ? rv.managerRating + ' de 5' : '—') + UI.kv('Comentários', esc(rv.comments || '—')) + '</dl>' + (direct ? '' : '<p class="rhc-muted">Somente o gestor direto (avaliador) edita esta avaliação.</p>')),
      onConfirm: function (d) {
        if (!(direct && !locked)) return true;
        var r = RH.store.act(function (s, actor) { return A.performance.saveManagerReview(s, actor, num, { rating: d.rating, comments: d.comments }, true); });
        if (!r.ok) {
          UI.toast(r.error, 'danger');
          return r.error;
        }
        UI.toast('Avaliação de ' + e.name + ' enviada.', 'success');
        return true;
      }
    });
    // "Salvar rascunho" reaproveita o botao de cancelar
    var cancelBtn = UI.root().querySelector('.rhc-modal footer [data-act="ui.modal.close"]');
    if (direct && !locked && cancelBtn) {
      cancelBtn.setAttribute('data-act', 'perf.reviewDraft');
      cancelBtn.setAttribute('data-num', num);
    }
  }

  // ---------------------------------------------------------------- RH
  function adminHtml(ctx) {
    var st = ctx.st;
    var idx = Q.index(st);
    var nums = Object.keys(st.reviews);
    var by = { Pendente: 0, Em_Andamento: 0, Enviada: 0, Calibrada: 0, Liberada: 0 };
    nums.forEach(function (n) { by[st.reviews[n].status]++; });
    var selfSent = Object.keys(st.selfAssessments).filter(function (n) { return st.selfAssessments[n].submitted; }).length;
    var selfTotal = Object.keys(st.selfAssessments).length;
    var cycle = st.cycle;
    var next = PF.nextPhase(cycle.status);
    var btn = cycle.status === 'Calibracao'
      ? '<button type="button" class="rhc-btn rhc-btn-primary" data-act="perf.release">' + UI.icon('award') + 'Liberar resultados e concluir o ciclo</button>'
      : cycle.status === 'Concluido' ? '<span class="rhc-muted">Ciclo concluído.</span>'
      : '<button type="button" class="rhc-btn rhc-btn-primary" data-act="perf.advance">' + UI.icon('arrowRight') + 'Avançar para "' + esc(PF.PHASE_LABEL[next]) + '"</button>';
    var max = Math.max.apply(null, Object.keys(by).map(function (k) { return by[k]; }).concat([1]));
    var statusBars = '<ul class="rhc-bars">' + Object.keys(by).map(function (k) {
      return '<li><span>' + esc(PF.REVIEW_LABEL[k]) + '</span><div class="rhc-bar"><i style="width:' + Math.round((by[k] / max) * 100) + '%"></i></div><b>' + by[k] + '</b></li>';
    }).join('') + '</ul>';
    var calRows = '';
    if (cycle.status === 'Calibracao' || cycle.status === 'Concluido') {
      calRows = nums.filter(function (n) { return ['Enviada', 'Calibrada', 'Liberada'].indexOf(st.reviews[n].status) >= 0; }).map(function (n) {
        var rv = st.reviews[n];
        var e = idx.byNum[n];
        var cal = rv.status === 'Liberada'
          ? '<strong>' + (rv.calibrated || '—') + '</strong>'
          : '<label class="rhc-sr" for="cal-' + n + '">Nota calibrada de ' + esc(e.name) + '</label><select id="cal-' + n + '" class="rhc-num" data-change="perf.calibrate" data-num="' + n + '"><option value="">—</option>' + [1, 2, 3, 4, 5].map(function (k) { return '<option value="' + k + '"' + (rv.calibrated === k ? ' selected' : '') + '>' + k + '</option>'; }).join('') + '</select>';
        return '<tr><td data-label="Colaborador"><strong>' + esc(e.name) + '</strong></td><td data-label="Nota do gestor">' + rv.managerRating + '</td><td data-label="Calibrada">' + cal + '</td><td data-label="Status">' + reviewBadge(rv) + '</td></tr>';
      }).join('');
    }
    var calibration = cycle.status === 'Calibracao' || cycle.status === 'Concluido'
      ? (calRows ? '<div class="rhc-tablewrap"><table class="rhc-table rhc-table-stack"><caption class="rhc-sr">Calibração das notas</caption><thead><tr><th scope="col">Colaborador</th><th scope="col">Nota do gestor</th><th scope="col">Calibrada (RH)</th><th scope="col">Status</th></tr></thead><tbody>' + calRows + '</tbody></table></div>' : UI.empty('star', 'Nenhuma avaliação enviada', 'Os gestores precisam enviar as avaliações na fase anterior. Para ver a calibração em ação, execute o roteiro do Gestor e depois volte aqui.'))
      : '<p class="rhc-muted">A calibração abre quando o ciclo chega à fase "Calibração".</p>';
    return (
      UI.card('Painel do ciclo ' + cycle.name.replace('Ciclo ', ''), phaseStepper(cycle) + '<div class="rhc-kpis"><div class="rhc-kpi">' + UI.icon('edit') + '<div><strong>' + selfSent + '/' + selfTotal + '</strong><span>autoavaliações enviadas</span></div></div><div class="rhc-kpi">' + UI.icon('team') + '<div><strong>' + (by.Enviada + by.Calibrada + by.Liberada) + '/' + nums.length + '</strong><span>avaliações de gestor enviadas</span></div></div></div>' +
        '<div class="rhc-actions">' + btn + '</div>', { icon: 'star', cls: 'rhc-mt0' }) +
      UI.card('Avaliações por status', statusBars, { icon: 'chart' }) +
      UI.card('Calibração e liberação', calibration, { icon: 'shield' })
    );
  }

  RH.views.performance = {
    render: function (ctx) {
      resetFor(ctx);
      var role = ctx.actor.role;
      var tabs = [['mine', 'Minha avaliação', 'person']];
      if (role === 'manager') tabs.push(['team', 'Minha equipe', 'team']);
      if (role === 'hr') tabs.unshift(['admin', 'Painel do ciclo', 'shield']);
      if (!tabs.some(function (t) { return t[0] === local.tab; })) local.tab = tabs[0][0];
      var nav = tabs.length > 1 ? '<div class="rhc-tabs" role="tablist" aria-label="Seções de desempenho">' + tabs.map(function (t) {
        return '<button type="button" role="tab" class="rhc-tab' + (local.tab === t[0] ? ' is-active' : '') + '" aria-selected="' + (local.tab === t[0]) + '" data-act="perf.tab" data-id="' + t[0] + '">' + UI.icon(t[2]) + t[1] + '</button>';
      }).join('') + '</div>' : '';
      var body = local.tab === 'mine' ? mineHtml(ctx) : local.tab === 'team' ? UI.card('Avaliações da equipe', teamHtml(ctx), { icon: 'team', cls: 'rhc-mt0' }) : adminHtml(ctx);
      return UI.pageHead('Avaliação de desempenho', 'Metas, autoavaliação, avaliação do gestor, calibração do RH e liberação do resultado.') + nav + '<div role="tabpanel">' + body + '</div>';
    },
    setTab: function (t) {
      local.tab = t;
    },
    reset: function () {
      local.persona = null;
      local.self = null;
    }
  };

  function selfData(form) {
    var d = UI.formData(form);
    return { rating: d.rating, strengths: d.strengths, improvements: d.improvements };
  }
  UI.on('perf.tab', function (el) {
    local.tab = el.getAttribute('data-id');
    RH.app.render();
  });
  UI.on('perf.goalWeight', function (el) {
    var r = RH.store.act(function (st, actor) { return A.performance.updateGoalWeight(st, actor, el.getAttribute('data-id'), el.value); });
    if (!r.ok) UI.toast(r.error, 'danger');
  });
  UI.on('perf.goalDel', function (el) {
    var r = RH.store.act(function (st, actor) { return A.performance.removeGoal(st, actor, el.getAttribute('data-id')); });
    if (!r.ok) UI.toast(r.error, 'danger');
  });
  UI.on('perf.goalAdd', function (form) {
    var d = UI.formData(form);
    var r = RH.store.act(function (st, actor) { return A.performance.addGoal(st, actor, actor.empNum, d); });
    local.goalErr = r.ok ? '' : r.error;
    if (r.ok) UI.toast('Meta adicionada.', 'success');
    else RH.app.render();
  });
  UI.on('perf.selfSave', function (el) {
    var form = el.closest('form');
    var d = selfData(form);
    local.self = d;
    var r = RH.store.act(function (st, actor) { return A.performance.saveSelf(st, actor, actor.empNum, d, false); });
    UI.toast(r.ok ? 'Rascunho salvo.' : r.error, r.ok ? 'info' : 'danger');
  });
  UI.on('perf.selfSend', function (form) {
    var d = selfData(form);
    local.self = d;
    var r = RH.store.act(function (st, actor) { return A.performance.saveSelf(st, actor, actor.empNum, d, true); });
    if (r.ok) {
      local.self = null;
      UI.toast('Autoavaliação enviada.', 'success');
    } else UI.toast(r.error, 'danger');
  });
  UI.on('perf.openReview', function (el) {
    openReview(el.getAttribute('data-num'));
  });
  UI.on('perf.reviewDraft', function (el) {
    var form = UI.root().querySelector('[data-modal-form]');
    var d = UI.formData(form);
    var num = el.getAttribute('data-num');
    var r = RH.store.act(function (st, actor) { return A.performance.saveManagerReview(st, actor, num, { rating: d.rating, comments: d.comments }, false); });
    if (r.ok) {
      UI.closeModal();
      UI.toast('Rascunho da avaliação salvo.', 'info');
    } else {
      UI.toast(r.error, 'danger');
      var er = UI.root().querySelector('.rhc-modal-error');
      if (er) {
        er.textContent = r.error;
        er.hidden = false;
      }
    }
  });
  UI.on('perf.advance', function () {
    var r = RH.store.act(function (st, actor) { return A.performance.advancePhase(st, actor); });
    UI.toast(r.ok ? 'Ciclo avançou para "' + PF.PHASE_LABEL[r.status] + '".' : r.error, r.ok ? 'success' : 'danger');
  });
  UI.on('perf.calibrate', function (el) {
    if (!el.value) return;
    var r = RH.store.act(function (st, actor) { return A.performance.calibrate(st, actor, el.getAttribute('data-num'), el.value); });
    UI.toast(r.ok ? 'Nota calibrada registrada.' : r.error, r.ok ? 'success' : 'danger');
  });
  UI.on('perf.release', function () {
    var r = RH.store.act(function (st, actor) { return A.performance.release(st, actor); });
    UI.toast(r.ok ? r.released + ' avaliação(ões) liberada(s). O colaborador agora vê o resultado.' : r.error, r.ok ? 'success' : 'danger');
  });
})(globalThis);
