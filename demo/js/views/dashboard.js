/* RH Core demo: Painel do RH (spec 18) com graficos SVG simples, calculados sobre o estado vivo da demonstracao. */
(function (g) {
  'use strict';
  var RH = g.RH;
  var U = RH.util;
  var UI = RH.ui;
  var esc = UI.esc;
  var Q = RH.q;
  var R = RH.recruiting;

  var PALETTE = ['#0176d3', '#032d60', '#1b96ff', '#5eb4ff', '#014486', '#8a5a00'];

  function hbars(items, label) {
    var rowH = 30;
    var labelW = 168;
    var barW = 280;
    var max = Math.max.apply(null, items.map(function (i) { return i.value; }).concat([1]));
    var h = items.length * rowH + 6;
    var summary = label + ': ' + items.map(function (i) { return i.label + ' ' + i.value; }).join(', ');
    return (
      '<svg class="rhc-chart" viewBox="0 0 ' + (labelW + barW + 46) + ' ' + h + '" role="img" aria-label="' + esc(summary) + '" preserveAspectRatio="xMinYMin meet">' +
      items.map(function (it, i) {
        var y = i * rowH + 4;
        var w = Math.max(it.value ? 4 : 0, Math.round((it.value / max) * barW));
        return (
          '<text x="0" y="' + (y + 16) + '" class="rhc-ct">' + esc(it.label) + '</text>' +
          '<rect x="' + labelW + '" y="' + y + '" width="' + barW + '" height="20" rx="5" class="rhc-cbg"/>' +
          '<rect x="' + labelW + '" y="' + y + '" width="' + w + '" height="20" rx="5" fill="' + (it.color || PALETTE[0]) + '"/>' +
          '<text x="' + (labelW + barW + 8) + '" y="' + (y + 15) + '" class="rhc-cv">' + esc(it.display !== undefined ? it.display : it.value) + '</text>'
        );
      }).join('') + '</svg>'
    );
  }

  function donut(items, label) {
    var total = items.reduce(function (a, i) { return a + i.value; }, 0) || 1;
    var r = 42;
    var c = 2 * Math.PI * r;
    var offset = 0;
    var segs = items.map(function (it, i) {
      var len = (it.value / total) * c;
      var seg = '<circle cx="60" cy="60" r="' + r + '" fill="none" stroke="' + PALETTE[i % PALETTE.length] + '" stroke-width="18" stroke-dasharray="' + len + ' ' + (c - len) + '" stroke-dashoffset="' + -offset + '" transform="rotate(-90 60 60)"/>';
      offset += len;
      return seg;
    }).join('');
    var summary = label + ': ' + items.map(function (i) { return i.label + ' ' + i.value; }).join(', ');
    return (
      '<div class="rhc-donutwrap"><svg class="rhc-donut" viewBox="0 0 120 120" role="img" aria-label="' + esc(summary) + '"><circle cx="60" cy="60" r="' + r + '" fill="none" stroke="#e5e5e5" stroke-width="18"/>' + segs +
      '<text x="60" y="58" text-anchor="middle" class="rhc-cv" style="font-size:18px">' + total + '</text><text x="60" y="74" text-anchor="middle" class="rhc-ct" style="font-size:9px">no total</text></svg>' +
      '<ul class="rhc-legend-list">' + items.map(function (it, i) { return '<li><i style="background:' + PALETTE[i % PALETTE.length] + '"></i>' + esc(it.label) + ' <b>' + it.value + '</b></li>'; }).join('') + '</ul></div>'
    );
  }

  function kpi(icon, value, label, tone) {
    return '<div class="rhc-kpi' + (tone ? ' rhc-kpi-' + tone : '') + '">' + UI.icon(icon) + '<div><strong>' + value + '</strong><span>' + esc(label) + '</span></div></div>';
  }

  RH.views.dashboard = {
    render: function (ctx) {
      var st = ctx.st;
      var staff = ctx.actor.role === 'hr';
      var active = st.employees.filter(function (e) { return e.status === 'Ativo' || e.status === 'Ferias'; });
      var onLeave = st.employees.filter(function (e) { return e.status === 'Ferias'; }).length;
      var openJobs = st.jobs.filter(function (j) { return j.status === 'Aberta'; }).length;
      var liveApps = st.applications.filter(function (a) { return !R.stage(a.stage).terminal; }).length;
      var pendingPromos = st.promotions.filter(function (p) { return p.status === 'Pendente'; }).length;
      var pendingLeave = st.leaveRequests.filter(function (r) { return r.status === 'Pendente'; }).length;
      var urgent = 0;
      st.employees.forEach(function (e) {
        Q.periodsOf(st, e.num).forEach(function (x) { if (x.status === 'Prazo_Proximo') urgent++; });
      });

      var depts = st.departments.map(function (d, i) {
        return { label: d.name, value: active.filter(function (e) { return e.dept === d.code; }).length, color: PALETTE[i % PALETTE.length] };
      });
      var funnel = R.STAGES.map(function (s) {
        return { label: s.label, value: st.applications.filter(function (a) { return a.stage === s.value; }).length, color: s.color };
      });
      var sums = {};
      st.stageHistory.forEach(function (h) {
        if (h.from && h.daysInPrev !== null) (sums[h.from] = sums[h.from] || []).push(h.daysInPrev);
      });
      var avgs = R.STAGES.filter(function (s) { return !s.terminal; }).map(function (s) {
        var arr = sums[s.value] || [];
        var avg = arr.length ? arr.reduce(function (a, b) { return a + b; }, 0) / arr.length : 0;
        return { label: s.label, value: Math.round(avg * 10) / 10, display: arr.length ? avg.toFixed(1).replace('.', ',') + ' d' : '—', color: s.color };
      });
      var reviewCount = {};
      Object.keys(st.reviews).forEach(function (k) { reviewCount[st.reviews[k].status] = (reviewCount[st.reviews[k].status] || 0) + 1; });
      var reviews = ['Pendente', 'Em_Andamento', 'Enviada', 'Calibrada', 'Liberada'].map(function (k) { return { label: RH.performance.REVIEW_LABEL[k], value: reviewCount[k] || 0 }; }).filter(function (x) { return x.value > 0; });
      var promoStatus = ['Pendente', 'Aprovado', 'Efetivado', 'Rejeitado'].map(function (k, i) {
        return { label: RH.promotion.STATUS_LABEL[k], value: st.promotions.filter(function (p) { return p.status === k; }).length, color: PALETTE[i % PALETTE.length] };
      });

      var kpis = '<div class="rhc-kpis rhc-kpis-wide">' +
        (staff ? kpi('users', active.length, 'colaboradores ativos') + kpi('sun', onLeave, 'em férias hoje') + kpi('warning', urgent, 'com prazo concessivo vencendo', urgent ? 'warn' : '') + kpi('inbox', pendingLeave + pendingPromos, 'solicitações pendentes') : '') +
        kpi('briefcase', openJobs, 'vagas abertas') + kpi('board', liveApps, 'candidaturas ativas') + '</div>';

      var cards = '';
      if (staff) cards += UI.card('Headcount por departamento', hbars(depts, 'Headcount por departamento'), { icon: 'building' });
      cards += UI.card('Funil de recrutamento (todas as vagas)', hbars(funnel, 'Funil de recrutamento'), { icon: 'board' });
      cards += UI.card('Tempo médio por etapa', hbars(avgs, 'Tempo médio por etapa em dias'), { icon: 'clock' });
      if (staff) {
        cards += UI.card('Avaliações por status no ciclo', donut(reviews, 'Avaliações por status'), { icon: 'star' });
        cards += UI.card('Promoções por status', hbars(promoStatus, 'Promoções por status'), { icon: 'trendUp' });
      }
      var intro = staff
        ? 'Os números abaixo são calculados na hora a partir dos dados da demonstração. Aprove, mova e contrate em outras telas e volte para ver o painel mudar.'
        : 'Visão do recrutador: funil e tempo por etapa. Indicadores de pessoas e salário não aparecem para esta persona.';
      return UI.pageHead('Painel do RH', intro) + kpis + '<div class="rhc-charts">' + cards + '</div>';
    }
  };
})(globalThis);
