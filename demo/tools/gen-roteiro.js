/* Gera demo/ROTEIRO.md a partir de js/tour.js (a mesma fonte do roteiro guiado da interface).
   Uso: node demo/tools/gen-roteiro.js */
const fs = require('node:fs');
const path = require('node:path');
const { TOURS } = require('../js/tour.js');
const NAMES = { colaborador: 'Colaborador', gestor: 'Gestor', rh: 'RH', recrutador: 'Recrutador', candidato: 'Candidato' };
const VIEWS = { home: 'Meu RH', dashboard: 'Painel', org: 'Organograma', leave: 'Férias', approvals: 'Aprovações', promotions: 'Promoções', recruiting: 'Recrutamento', performance: 'Desempenho', onboarding: 'Onboarding', portal: 'Portal de vagas' };

const TABS = { mine: 'Minhas férias', team: 'Calendário da equipe', deadlines: 'Prazos concessivos', board: 'Funil', jobs: 'Vagas', lgpd: 'Retenção LGPD', admin: 'Painel do ciclo' };
const TABS_PERF = { mine: 'Minha avaliação', team: 'Minha equipe', admin: 'Painel do ciclo' };
let md = '# Roteiro da demonstração do RH Core\n\n';
md += 'Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.\n\n';
md += 'A data da demonstração é fixa (segunda-feira, 26/10/2026), para que os prazos e as regras sejam sempre os mesmos. Cada persona tem 10 passos. ';
md += 'Na interface, o botão "Roteiro guiado" abre este mesmo roteiro e leva você à tela de cada passo. "Reiniciar demo" devolve os dados ao estado inicial.\n\n';
md += 'Os personagens estão vinculados à árvore de 40 colaboradores fictícios da Vetra Distribuidora (matrículas VTR-0001 em diante). ';
md += 'Os fluxos se encadeiam: o pedido de férias enviado pelo Colaborador chega ao Gestor, depois ao RH; a candidatura enviada pelo Candidato aparece no funil do Recrutador.\n\n';
md += 'Arquivo gerado por `node demo/tools/gen-roteiro.js` a partir de `demo/js/tour.js`. Não edite à mão.\n';
for (const key of Object.keys(TOURS)) {
  const t = TOURS[key];
  md += `\n## ${NAMES[key]}\n\n${t.title}\n\n`;
  t.steps.forEach((s, i) => {
    const where = VIEWS[s.go.view] + (s.go.tab ? ', aba ' + (s.go.view === 'performance' ? TABS_PERF : TABS)[s.go.tab] : '');
    md += `${i + 1}. **${s.title}** (tela: ${where}). ${s.text}\n`;
  });
}
fs.writeFileSync(path.join(__dirname, '..', 'ROTEIRO.md'), md);
console.log('ROTEIRO.md gerado');
