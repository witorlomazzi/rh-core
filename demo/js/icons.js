/* RH Core demo: icones SVG inline no estilo do portfolio (traco 2px, 24x24, currentColor). Sem emoji. */
(function (g) {
  'use strict';
  var RH = (g.RH = g.RH || {});
  var P = {
    home: '<path d="M4 11l8-7 8 7"/><path d="M6 10v10h12V10"/><path d="M10 20v-6h4v6"/>',
    chart: '<path d="M4 20V4"/><path d="M4 20h16"/><rect x="7.5" y="12" width="3" height="5"/><rect x="12.5" y="8" width="3" height="9"/><rect x="17.5" y="5" width="2.5" height="12"/>',
    org: '<rect x="9" y="3" width="6" height="5" rx="1"/><rect x="3" y="16" width="6" height="5" rx="1"/><rect x="15" y="16" width="6" height="5" rx="1"/><path d="M12 8v4M6 16v-4h12v4"/>',
    calendar: '<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
    inbox: '<path d="M3 13l3-8h12l3 8"/><path d="M3 13v6h18v-6h-5l-1.5 2.5h-5L8 13z"/>',
    trendUp: '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M3 13h18"/>',
    star: '<path d="M12 3l2.6 5.6 6.1.6-4.6 4.1 1.3 6-5.4-3.2-5.4 3.2 1.3-6-4.6-4.1 6.1-.6z"/>',
    clipboard: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4h6v3H9z"/><path d="M9 12l2 2 4-4"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
    person: '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c1-4 4-6 7-6s6 2 7 6"/>',
    team: '<circle cx="9" cy="8" r="3"/><path d="M3 19c.8-3.4 3.2-5 6-5s5.200 1.600 6 5"/><circle cx="17" cy="9" r="2.500"/><path d="M16 14c2.800-.2 4.600 1.200 5 4"/>',
    shield: '<path d="M12 3l8 3v6c0 5-3.500 8-8 9-4.500-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
    lock: '<rect x="5" y="11" width="14" height="9" rx="1.500"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    check: '<path d="M5 12l4 4 10-10"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>',
    warning: '<path d="M12 3l10 18H2z"/><path d="M12 10v4"/><circle cx="12" cy="17" r=".6" fill="currentColor" stroke="none"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="8" r=".6" fill="currentColor" stroke="none"/>',
    ban: '<circle cx="12" cy="12" r="9"/><path d="M5.700 5.700l12.600 12.600"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.300-4.300"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    chevronRight: '<path d="M9 5l7 7-7 7"/>',
    chevronDown: '<path d="M5 9l7 7 7-7"/>',
    chevronLeft: '<path d="M15 5l-7 7 7 7"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    doc: '<path d="M6 3h9l4 4v14H6z"/><path d="M15 3v4h4M9 12h6M9 16h6"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
    building: '<rect x="4" y="3" width="16" height="18" rx="1"/><path d="M9 8h1M14 8h1M9 12h1M14 12h1M9 16h1M14 16h1"/>',
    flag: '<path d="M5 21V4"/><path d="M5 4h13l-3 4 3 4H5"/>',
    target: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r=".6" fill="currentColor" stroke="none"/>',
    play: '<path d="M7 4l13 8-13 8z"/>',
    refresh: '<path d="M4 12a8 8 0 0 1 13.700-5.700L21 9"/><path d="M21 4v5h-5"/><path d="M20 12a8 8 0 0 1-13.700 5.700L3 15"/><path d="M3 20v-5h5"/>',
    send: '<path d="M21 3L10 14"/><path d="M21 3l-7 18-4-7-7-4z"/>',
    arrowRight: '<path d="M4 12h16M14 6l6 6-6 6"/>',
    grip: '<circle cx="9" cy="6" r="1.200" fill="currentColor" stroke="none"/><circle cx="15" cy="6" r="1.200" fill="currentColor" stroke="none"/><circle cx="9" cy="12" r="1.200" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="1.200" fill="currentColor" stroke="none"/><circle cx="9" cy="18" r="1.200" fill="currentColor" stroke="none"/><circle cx="15" cy="18" r="1.200" fill="currentColor" stroke="none"/>',
    filter: '<path d="M3 5h18l-7 8v6l-4-2v-4z"/>',
    trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
    edit: '<path d="M4 20l1-4L16.500 4.500a2.100 2.100 0 0 1 3 3L8 19z"/><path d="M13.500 7.500l3 3"/>',
    userPlus: '<circle cx="10" cy="8" r="3.500"/><path d="M3 20c1-4 4-6 7-6s4 .8 5 2"/><path d="M19 8v6M16 11h6"/>',
    key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M16 7l3 3"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13"/><circle cx="4" cy="6" r="1" fill="currentColor" stroke="none"/><circle cx="4" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="4" cy="18" r="1" fill="currentColor" stroke="none"/>',
    board: '<rect x="3" y="4" width="5" height="16" rx="1"/><rect x="9.500" y="4" width="5" height="10" rx="1"/><rect x="16" y="4" width="5" height="13" rx="1"/>',
    award: '<circle cx="12" cy="9" r="5.500"/><path d="M8.500 14L7 21l5-3 5 3-1.500-7"/>',
    phone: '<path d="M5 4h4l2 5-2.500 1.500a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
    link: '<path d="M10 14a4 4 0 0 0 5.700 0l3-3a4 4 0 0 0-5.700-5.700L12 6.300"/><path d="M14 10a4 4 0 0 0-5.700 0l-3 3a4 4 0 0 0 5.700 5.700L12 17.700"/>',
    eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    dollar: '<path d="M12 3v18"/><path d="M16.500 7.500C16 6 14.500 5 12 5S8 6.200 8 8s1.500 2.500 4 3 4 1.200 4 3-1.700 3-4 3-4-1-4.500-2.500"/>',
    bot: '<rect x="4" y="8" width="16" height="12" rx="2"/><path d="M12 4v4"/><circle cx="12" cy="3.500" r="1" fill="currentColor" stroke="none"/><circle cx="9" cy="14" r="1.200" fill="currentColor" stroke="none"/><circle cx="15" cy="14" r="1.200" fill="currentColor" stroke="none"/>',
    book: '<path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M4 19V5M9 7h6"/>',
    pin: '<path d="M12 21s-7-5.500-7-11a7 7 0 0 1 14 0c0 5.500-7 11-7 11z"/><circle cx="12" cy="10" r="2.500"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/>',
    users: '<circle cx="9" cy="8" r="3"/><path d="M3 19c.8-3.400 3.200-5 6-5s5.200 1.600 6 5"/><circle cx="17" cy="9" r="2.500"/><path d="M16 14c2.800-.2 4.600 1.200 5 4"/>'
  };
  function svg(name) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' + (P[name] || P.info) + '</svg>';
  }
  RH.icons = {
    svg: svg,
    /** Span com o SVG inline, pronto para usar em template. */
    html: function (name, cls) {
      return '<span class="rhc-ic' + (cls ? ' ' + cls : '') + '" aria-hidden="true">' + svg(name) + '</span>';
    },
    names: Object.keys(P)
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.icons;
})(globalThis);
