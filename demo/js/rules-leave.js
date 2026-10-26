/* RH Core demo: motor de regras de ferias CLT (spec 11). Funcoes puras, sem DOM, sem estado global.
   Espelha LeaveRuleEngine (V1 a V12) e LeaveAccrualService (R1 a R4) do produto Apex. */
(function (g) {
  'use strict';
  if (typeof module !== 'undefined' && module.exports) require('./util.js');
  var RH = (g.RH = g.RH || {});
  var U = RH.util;

  var DEFAULT_SETTINGS = {
    weeklyRestDays: ['SUN'],
    minNoticeDays: 30,
    maxSplits: 3,
    minMainDays: 14,
    minOtherDays: 5,
    blockDaysBeforeRest: 2,
    soldDivisor: 3,
    abonoDeadlineDays: 15,
    accrualMonths: 12,
    concessionWarningDays: 60,
    candidateRetentionDays: 180,
    portalMinSubmitSeconds: 3,
    portalDailyLimit: 3,
    consentVersion: '2026-10'
  };

  // Tabela do art. 130 da CLT (HR_Absence_Rule__mdt).
  var DEFAULT_ABSENCE_RULES = [
    { min: 0, max: 5, days: 30 },
    { min: 6, max: 14, days: 24 },
    { min: 15, max: 23, days: 18 },
    { min: 24, max: 32, days: 12 }
  ];

  var PERIOD_STATUS_LABEL = {
    Em_Aquisicao: 'Em aquisição',
    Disponivel: 'Disponível',
    Prazo_Proximo: 'Prazo próximo',
    Concluido: 'Concluído',
    Perdido: 'Perdido'
  };
  var REQUEST_STATUS_LABEL = {
    Rascunho: 'Rascunho',
    Pendente: 'Pendente',
    Aprovado: 'Aprovado',
    Rejeitado: 'Rejeitado',
    Cancelado: 'Cancelado',
    Em_Gozo: 'Em gozo',
    Concluido: 'Concluído'
  };
  // Estados que contam como pedido "vivo" para o motor (nao cancelado, nao rejeitado, nao rascunho).
  var ACTIVE_STATUSES = ['Pendente', 'Aprovado', 'Em_Gozo', 'Concluido'];
  var TAKEN_STATUSES = ['Aprovado', 'Em_Gozo', 'Concluido'];

  /** R3: dias de direito pela tabela do art. 130. Acima de 32 faltas o periodo e perdido. */
  function entitledDays(absences, rules) {
    rules = rules || DEFAULT_ABSENCE_RULES;
    var n = Math.max(0, absences || 0);
    for (var i = 0; i < rules.length; i++) {
      if (n >= rules[i].min && n <= rules[i].max) return { days: rules[i].days, lost: false };
    }
    return { days: 0, lost: true };
  }

  function requestEnd(r) {
    return U.addDays(r.start, r.days - 1);
  }

  /** R1 e R2: periodos aquisitivos de um colaborador CLT ate o atual. */
  function buildPeriods(emp, ctx) {
    var today = ctx.today || U.TODAY;
    var settings = ctx.settings || DEFAULT_SETTINGS;
    var rules = ctx.absenceRules || DEFAULT_ABSENCE_RULES;
    var requests = ctx.requests || [];
    if (emp.type !== 'CLT' || emp.status === 'Desligado' || emp.status === 'Pre_Admissao') return [];
    var out = [];
    for (var i = 0; i < 40; i++) {
      var start = U.addMonths(emp.hire, settings.accrualMonths * i);
      if (start > today) break;
      var end = U.addDays(U.addMonths(emp.hire, settings.accrualMonths * (i + 1)), -1);
      var abs = (emp.absences && emp.absences[start]) || 0;
      var ent = entitledDays(abs, rules);
      var key = emp.num + '|' + start;
      var deadline = U.addMonths(end, settings.accrualMonths);
      var hasRequests = requests.some(function (r) {
        return r.periodKey === key;
      });
      out.push({
        key: key,
        empNum: emp.num,
        start: start,
        end: end,
        concessionDeadline: deadline,
        absences: abs,
        entitled: ent.days,
        lost: ent.lost,
        // Periodos antigos, ja vencidos e sem pedido registrado, entram como historico quitado.
        historical: deadline < today && !hasRequests && abs === 0
      });
    }
    return out;
  }

  /** Roll-ups do periodo (Days_Taken, Days_Sold, Days_Pending, Balance). */
  function balanceOf(period, requests) {
    if (period.historical) {
      return { taken: period.entitled, sold: 0, pending: 0, balance: 0 };
    }
    var taken = 0;
    var sold = 0;
    var pending = 0;
    requests.forEach(function (r) {
      if (r.periodKey !== period.key) return;
      if (TAKEN_STATUSES.indexOf(r.status) >= 0) {
        taken += r.days;
        sold += r.sold || 0;
      } else if (r.status === 'Pendente') {
        pending += r.days;
        // Decisao conservadora: o abono de um pedido pendente tambem fica reservado.
        sold += r.sold || 0;
      }
    });
    return { taken: taken, sold: sold, pending: pending, balance: period.entitled - taken - sold - pending };
  }

  /** R4: status do periodo. */
  function periodStatus(period, bal, today, settings) {
    settings = settings || DEFAULT_SETTINGS;
    if (period.lost) return 'Perdido';
    if (today <= period.end) return 'Em_Aquisicao';
    if (period.historical || bal.balance <= 0) return 'Concluido';
    if (U.diffDays(today, period.concessionDeadline) <= settings.concessionWarningDays) return 'Prazo_Proximo';
    return 'Disponivel';
  }

  function holidayDates(holidays, location) {
    var set = {};
    (holidays || []).forEach(function (h) {
      if (!h.location || h.location === location) set[h.date] = h.name;
    });
    return set;
  }

  function dayLabel(iso, restDays, holidaySet) {
    if (holidaySet[iso]) return 'feriado (' + holidaySet[iso] + ')';
    var names = { SUN: 'domingo', MON: 'segunda-feira', TUE: 'terça-feira', WED: 'quarta-feira', THU: 'quinta-feira', FRI: 'sexta-feira', SAT: 'sábado' };
    return 'descanso semanal (' + names[U.dowCode(iso)] + ')';
  }

  function sum(list, f) {
    return list.reduce(function (a, x) {
      return a + (f(x) || 0);
    }, 0);
  }

  function check(code, label, status, message) {
    return { code: code, label: label, status: status, blocking: status === 'blocking', message: message };
  }

  /**
   * Valida um pedido contra V1 a V12.
   * input: { period, existing, employeeRequests, request:{start,days,sold}, today, settings,
   *          holidaySet, teamLeaves:[{name,start,end}], allowNoticeException }
   * Retorna a lista completa de verificacoes (ok, warning ou blocking), cada uma com mensagem em portugues.
   */
  function evaluate(input) {
    var s = input.settings || DEFAULT_SETTINGS;
    var today = input.today || U.TODAY;
    var p = input.period;
    var req = input.request;
    var days = Number(req.days);
    var sold = Number(req.sold || 0);
    var existing = (input.existing || []).filter(function (r) {
      return ACTIVE_STATUSES.indexOf(r.status) >= 0;
    });
    var holidaySet = input.holidaySet || {};
    var restDays = s.weeklyRestDays;
    var results = [];

    if (!req.start || !/^\d{4}-\d{2}-\d{2}$/.test(req.start) || !(days >= 1) || Math.floor(days) !== days || sold < 0 || Math.floor(sold) !== sold) {
      return [check('DADOS_INVALIDOS', 'Dados do pedido', 'blocking', 'Informe uma data de início válida e uma quantidade de dias inteira maior que zero.')];
    }
    var end = U.addDays(req.start, days - 1);

    // V1
    if (today <= p.end) {
      results.push(check('PERIODO_NAO_ADQUIRIDO', 'Período adquirido', 'blocking', 'O período aquisitivo ainda está em andamento (termina em ' + U.fmtBR(p.end) + '). As férias só podem ser tiradas depois de completá-lo.'));
    } else {
      results.push(check('PERIODO_NAO_ADQUIRIDO', 'Período adquirido', 'ok', 'Período aquisitivo completo em ' + U.fmtBR(p.end) + '.'));
    }

    // V2
    var used = sum(existing, function (r) { return r.days; }) + sum(existing, function (r) { return r.sold; });
    var balance = p.entitled - used;
    if (days + sold > balance) {
      results.push(check('SALDO_INSUFICIENTE', 'Saldo', 'blocking', 'Saldo insuficiente: o pedido usa ' + (days + sold) + ' dia(s) (gozo e abono) e o saldo do período é ' + Math.max(balance, 0) + '.'));
    } else {
      results.push(check('SALDO_INSUFICIENTE', 'Saldo', 'ok', 'O pedido usa ' + (days + sold) + ' dia(s) e o saldo é ' + balance + '.'));
    }

    // V3
    var lead = U.diffDays(today, req.start);
    if (lead < s.minNoticeDays) {
      if (input.allowNoticeException) {
        results.push(check('ANTECEDENCIA', 'Antecedência', 'warning', 'Exceção de antecedência autorizada pelo RH: o início é em ' + lead + ' dia(s), abaixo do mínimo de ' + s.minNoticeDays + '.'));
      } else {
        results.push(check('ANTECEDENCIA', 'Antecedência', 'blocking', 'Aviso prévio insuficiente: o início precisa ser pelo menos ' + s.minNoticeDays + ' dias depois de hoje (art. 135 da CLT). Faltam ' + Math.max(s.minNoticeDays - lead, 0) + ' dia(s).'));
      }
    } else {
      results.push(check('ANTECEDENCIA', 'Antecedência', 'ok', 'Aviso com ' + lead + ' dias de antecedência (mínimo ' + s.minNoticeDays + ').'));
    }

    // V4
    var v4 = null;
    for (var k = 1; k <= s.blockDaysBeforeRest; k++) {
      var d = U.addDays(req.start, k);
      if (holidaySet[d] || restDays.indexOf(U.dowCode(d)) >= 0) {
        v4 = 'Início não permitido: ' + U.fmtBR(d) + ' é ' + dayLabel(d, restDays, holidaySet) + ' e as férias não podem começar nos ' + s.blockDaysBeforeRest + ' dias que antecedem feriado ou descanso semanal (art. 134, §3º).';
        break;
      }
    }
    results.push(v4 ? check('INICIO_ANTES_DESCANSO', 'Início antes de descanso', 'blocking', v4) : check('INICIO_ANTES_DESCANSO', 'Início antes de descanso', 'ok', 'O início não antecede feriado nem descanso semanal.'));

    // V5
    if (existing.length + 1 > s.maxSplits) {
      results.push(check('QUANTIDADE_PERIODOS', 'Número de frações', 'blocking', 'O período aquisitivo só pode ser dividido em até ' + s.maxSplits + ' frações.'));
    } else {
      results.push(check('QUANTIDADE_PERIODOS', 'Número de frações', 'ok', 'Fração ' + (existing.length + 1) + ' de no máximo ' + s.maxSplits + '.'));
    }

    // V6
    if (days < s.minOtherDays) {
      results.push(check('MINIMO_FRACAO', 'Tamanho da fração', 'blocking', 'Cada fração precisa ter pelo menos ' + s.minOtherDays + ' dias corridos.'));
    } else {
      results.push(check('MINIMO_FRACAO', 'Tamanho da fração', 'ok', 'A fração tem ' + days + ' dias (mínimo ' + s.minOtherDays + ').'));
    }

    // V7
    var fractions = existing.map(function (r) { return r.days; }).concat([days]);
    var totalSold = sum(existing, function (r) { return r.sold; }) + sold;
    var remaining = p.entitled - totalSold - sum(fractions, function (x) { return x; });
    var hasMain = fractions.some(function (x) { return x >= s.minMainDays; });
    var v7 = null;
    if (!hasMain) {
      if (fractions.length >= s.maxSplits) {
        v7 = 'Com ' + fractions.length + ' frações, uma delas precisa ter pelo menos ' + s.minMainDays + ' dias corridos (art. 134, §1º).';
      } else if (remaining < s.minMainDays) {
        v7 = 'Depois desta fração restariam ' + Math.max(remaining, 0) + ' dia(s) e nenhuma fração chegaria a ' + s.minMainDays + ' dias corridos. Aumente esta fração ou reorganize as anteriores.';
      }
    }
    results.push(v7 ? check('PERIODO_PRINCIPAL', 'Fração principal', 'blocking', v7) : check('PERIODO_PRINCIPAL', 'Fração principal', 'ok', hasMain ? 'Há uma fração de ' + s.minMainDays + ' dias ou mais.' : 'Ainda é possível cumprir a fração de ' + s.minMainDays + ' dias (restam ' + remaining + ').'));

    // V8
    var soldLimit = Math.floor(p.entitled / s.soldDivisor);
    if (totalSold > soldLimit) {
      results.push(check('ABONO_LIMITE', 'Limite do abono', 'blocking', 'Abono pecuniário acima do limite: no máximo 1/' + s.soldDivisor + ' do direito, ou seja ' + soldLimit + ' dia(s) neste período (já vendidos: ' + (totalSold - sold) + ').'));
    } else {
      results.push(check('ABONO_LIMITE', 'Limite do abono', 'ok', sold > 0 ? 'Abono de ' + sold + ' dia(s) dentro do limite de ' + soldLimit + '.' : 'Sem abono neste pedido (limite do período: ' + soldLimit + ').'));
    }

    // V9
    var abonoLimitDate = U.addDays(p.end, -s.abonoDeadlineDays);
    if (sold > 0 && today > abonoLimitDate) {
      results.push(check('ABONO_PRAZO', 'Prazo do abono', 'warning', 'O abono pedido fora do prazo depende de concordância da empresa.'));
    } else {
      results.push(check('ABONO_PRAZO', 'Prazo do abono', 'ok', sold > 0 ? 'Abono solicitado dentro do prazo.' : 'Não se aplica (sem abono).'));
    }

    // V10
    if (end > p.concessionDeadline) {
      results.push(check('PRAZO_CONCESSIVO', 'Prazo concessivo', 'warning', 'Férias após o prazo concessivo são devidas em dobro (art. 137 da CLT). O prazo termina em ' + U.fmtBR(p.concessionDeadline) + '.'));
    } else {
      results.push(check('PRAZO_CONCESSIVO', 'Prazo concessivo', 'ok', 'O gozo termina em ' + U.fmtBR(end) + ', dentro do prazo concessivo (' + U.fmtBR(p.concessionDeadline) + ').'));
    }

    // V11
    var clash = (input.employeeRequests || []).filter(function (r) {
      return ACTIVE_STATUSES.indexOf(r.status) >= 0 && U.overlaps(req.start, end, r.start, requestEnd(r));
    })[0];
    if (clash) {
      results.push(check('SOBREPOSICAO', 'Sobreposição', 'blocking', 'As datas se sobrepõem a outro pedido seu (' + U.fmtBR(clash.start) + ' a ' + U.fmtBR(requestEnd(clash)) + ').'));
    } else {
      results.push(check('SOBREPOSICAO', 'Sobreposição', 'ok', 'Sem sobreposição com outros pedidos do colaborador.'));
    }

    // V12
    var conflicts = (input.teamLeaves || []).filter(function (t) {
      return U.overlaps(req.start, end, t.start, t.end);
    });
    if (conflicts.length) {
      results.push(check('CONFLITO_EQUIPE', 'Conflito na equipe', 'warning', 'Colegas da mesma equipe com férias no intervalo: ' + conflicts.map(function (t) { return t.name + ' (' + U.fmtShort(t.start) + ' a ' + U.fmtShort(t.end) + ')'; }).join(', ') + '.'));
    } else {
      results.push(check('CONFLITO_EQUIPE', 'Conflito na equipe', 'ok', 'Nenhum colega da equipe direta ausente no intervalo.'));
    }
    return results;
  }

  function summarize(results) {
    return {
      blocking: results.filter(function (r) { return r.status === 'blocking'; }),
      warnings: results.filter(function (r) { return r.status === 'warning'; }),
      canSubmit: !results.some(function (r) { return r.status === 'blocking'; })
    };
  }

  RH.leave = {
    DEFAULT_SETTINGS: DEFAULT_SETTINGS,
    DEFAULT_ABSENCE_RULES: DEFAULT_ABSENCE_RULES,
    PERIOD_STATUS_LABEL: PERIOD_STATUS_LABEL,
    REQUEST_STATUS_LABEL: REQUEST_STATUS_LABEL,
    ACTIVE_STATUSES: ACTIVE_STATUSES,
    TAKEN_STATUSES: TAKEN_STATUSES,
    entitledDays: entitledDays,
    buildPeriods: buildPeriods,
    balanceOf: balanceOf,
    periodStatus: periodStatus,
    holidayDates: holidayDates,
    requestEnd: requestEnd,
    evaluate: evaluate,
    summarize: summarize
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.leave;
})(globalThis);
