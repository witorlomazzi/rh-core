/* Garante que a ordem dos <script> do index.html funciona sem Node (como no navegador): carrega os arquivos
   em um contexto isolado, sem require, e exercita uma regra que depende de modulos carregados antes. */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const scripts = [...html.matchAll(/<script src="([^"]+)"><\/script>/g)].map((m) => m[1]);

test('index.html lista os scripts de logica antes dos de interface', () => {
  assert.ok(scripts.indexOf('js/util.js') < scripts.indexOf('js/data.js'));
  assert.ok(scripts.indexOf('js/rules-visibility.js') < scripts.indexOf('js/rules-promotion.js'));
  assert.ok(scripts.indexOf('js/queries.js') < scripts.indexOf('js/actions-leave.js'));
  assert.ok(scripts.indexOf('js/ui.js') < scripts.indexOf('js/views/org.js'));
  assert.ok(scripts.indexOf('js/app.js') > scripts.indexOf('js/views/dashboard.js'));
});

test('a logica carrega na ordem do navegador (sem require) e uma promocao funciona', () => {
  const ctx = vm.createContext({ console });
  ctx.globalThis = ctx;
  for (const src of scripts.filter((s) => !s.startsWith('js/views/') && !['js/ui.js', 'js/icons.js', 'js/app.js', 'js/tour.js'].includes(s) && s !== 'js/store.js')) {
    vm.runInContext(fs.readFileSync(path.join(root, src), 'utf8'), ctx, { filename: src });
  }
  const out = vm.runInContext(
    `const st = RH.seed.build();
     const r = RH.actions.promotion.create(st, RH.visibility.actorFor('gestor'), { subjectNum: 'VTR-0016', proposedPos: 'P05', effective: '2026-12-01', justification: 'ok' });
     r.ok`,
    ctx
  );
  assert.equal(out, true);
});

test('cada persona tem 10 passos de roteiro e cada tela do roteiro existe na navegacao da persona', () => {
  require('../js/rules-visibility.js');
  const { TOURS } = require('../js/tour.js');
  const V = globalThis.RH.visibility;
  for (const p of V.PERSONA_ORDER) {
    assert.equal(TOURS[p].steps.length, 10, p);
    for (const s of TOURS[p].steps) assert.ok(V.NAV[p].includes(s.go.view), `${p}: ${s.go.view}`);
  }
});

test('sem travessao e sem emoji nos textos do roteiro e dos dados', () => {
  const files = ['index.html', 'css/demo.css'].concat(fs.readdirSync(path.join(root, 'js')).filter((f) => f.endsWith('.js')).map((f) => 'js/' + f), fs.readdirSync(path.join(root, 'js/views')).map((f) => 'js/views/' + f));
  for (const f of files) {
    const text = fs.readFileSync(path.join(root, f), 'utf8');
    assert.equal(text.includes('\u2014'), false, f + ' tem travessao');
    assert.equal(/[\u{1F300}-\u{1FAFF}\u2600-\u27BF]/u.test(text), false, f + ' tem emoji');
  }
});
