/* RH Core demo: utilitarios puros (datas ISO, texto, moeda). Sem acesso ao DOM. */
(function (g) {
  'use strict';
  var RH = (g.RH = g.RH || {});

  // Data fixa da demonstracao: segunda-feira. Mantem as regras de prazo deterministicas.
  var TODAY = '2026-10-26';
  var DOW_CODES = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  var MONTHS = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

  function parse(iso) {
    var p = String(iso).split('-').map(Number);
    return new Date(Date.UTC(p[0], p[1] - 1, p[2]));
  }
  function fmt(d) {
    return d.toISOString().slice(0, 10);
  }
  function addDays(iso, n) {
    var d = parse(iso);
    d.setUTCDate(d.getUTCDate() + n);
    return fmt(d);
  }
  function diffDays(a, b) {
    return Math.round((parse(b) - parse(a)) / 86400000);
  }
  function addMonths(iso, n) {
    var p = iso.split('-').map(Number);
    var total = p[0] * 12 + (p[1] - 1) + n;
    var ny = Math.floor(total / 12);
    var nm = total % 12;
    var last = new Date(Date.UTC(ny, nm + 1, 0)).getUTCDate();
    return fmt(new Date(Date.UTC(ny, nm, Math.min(p[2], last))));
  }
  function dow(iso) {
    return parse(iso).getUTCDay();
  }
  function dowCode(iso) {
    return DOW_CODES[dow(iso)];
  }
  function overlaps(a1, a2, b1, b2) {
    return a1 <= b2 && b1 <= a2;
  }
  function fmtBR(iso) {
    if (!iso) return '';
    var p = iso.split('-');
    return p[2] + '/' + p[1] + '/' + p[0];
  }
  function fmtShort(iso) {
    if (!iso) return '';
    var p = iso.split('-');
    return p[2] + '/' + p[1];
  }
  function monthLabel(year, month) {
    return MONTHS[month - 1] + ' de ' + year;
  }
  function daysInMonth(year, month) {
    return new Date(Date.UTC(year, month, 0)).getUTCDate();
  }
  function tenureText(hire, today) {
    var months = (parseInt(today.slice(0, 4), 10) - parseInt(hire.slice(0, 4), 10)) * 12 + (parseInt(today.slice(5, 7), 10) - parseInt(hire.slice(5, 7), 10));
    if (today.slice(8) < hire.slice(8)) months -= 1;
    if (months < 0) return 'ainda não iniciou';
    var y = Math.floor(months / 12);
    var m = months % 12;
    var parts = [];
    if (y) parts.push(y + (y === 1 ? ' ano' : ' anos'));
    if (m || !y) parts.push(m + (m === 1 ? ' mês' : ' meses'));
    return parts.join(' e ');
  }

  function initials(name) {
    var parts = String(name).trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '?';
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  function brl(n) {
    if (n === null || n === undefined || isNaN(n)) return '';
    return 'R$ ' + Number(n).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }
  function esc(s) {
    return String(s === null || s === undefined ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }
  function stripHtml(s) {
    return String(s === null || s === undefined ? '' : s)
      .replace(/<[^>]*>/g, '')
      .replace(/[<>]/g, '')
      .trim();
  }
  function slugify(s) {
    return String(s)
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }
  function pad(n, w) {
    var s = String(n);
    while (s.length < w) s = '0' + s;
    return s;
  }
  function clone(o) {
    return JSON.parse(JSON.stringify(o));
  }

  RH.util = {
    TODAY: TODAY,
    DOW_CODES: DOW_CODES,
    parse: parse,
    fmt: fmt,
    addDays: addDays,
    diffDays: diffDays,
    addMonths: addMonths,
    dow: dow,
    dowCode: dowCode,
    overlaps: overlaps,
    fmtBR: fmtBR,
    fmtShort: fmtShort,
    monthLabel: monthLabel,
    daysInMonth: daysInMonth,
    tenureText: tenureText,
    initials: initials,
    brl: brl,
    esc: esc,
    stripHtml: stripHtml,
    slugify: slugify,
    pad: pad,
    clone: clone
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.util;
})(globalThis);
