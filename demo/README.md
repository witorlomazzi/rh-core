# RH Core: demo interativa pública

Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

Demonstração do RH Core (produto de RH para Salesforce) que roda 100% no navegador: HTML, CSS e JavaScript puros, sem build,
sem CDN, sem backend. Os dados vivem em memória e em `localStorage` (chave `rhcore-demo-v3`). A empresa é a Vetra Distribuidora,
fictícia; os 40 colaboradores seguem a árvore da spec 18 (matrículas VTR-0001 em diante).

## O que a demo mostra

- Seletor de persona (Colaborador, Gestor, RH, Recrutador, Candidato) que muda o que se vê e o que se pode fazer.
  Salário aparece mascarado para todos, menos para o RH (prova do FLS).
- Organograma navegável (árvore e lista, busca, teclado) com visibilidade por persona.
- Férias CLT com o motor de regras V1 a V12, saldo por período aquisitivo, calendário da equipe e prazos concessivos.
- Aprovação em duas etapas (férias e promoções), com rejeição comentada e cancelamento.
- Promoções com histórico de cargo e revisão de faixa salarial pelo RH.
- Recrutamento: kanban com arrastar e soltar (e menu "Mover para" por teclado), motivo e nota obrigatórios, histórico com dias na etapa.
- Portal público de vagas, com LGPD, honeypot, tempo mínimo e limite diário (simulados). A candidatura enviada aparece no funil.
- Avaliação de desempenho (metas, autoavaliação, avaliação do gestor, calibração, liberação), onboarding e painel do RH em SVG.
- Roteiro guiado de 10 passos por persona (`ROTEIRO.md`) e botão "Reiniciar demo".

## Como abrir

Opção simples: abrir `demo/index.html` no navegador (funciona por `file://`, pois não usa módulos ES).

Opção com servidor local (qualquer um serve):

```bash
cd demo
python -m http.server 8123   # ou: npx serve .
# abrir http://localhost:8123/
```

## Testes

Regras puras e fluxos de ponta a ponta, sem DOM, usando o test runner do Node (22 ou superior):

```bash
node --test "demo/tests/*.test.js"      # da raiz do repositório
cd demo && npm test                      # equivalente
```

Observação: no Node 22, `node --test demo/tests/` (só o diretório) não funciona; use o glob.

Os motores de regras ficam em arquivos próprios, sem acesso ao DOM:

| Arquivo | Regras |
|---|---|
| `js/rules-leave.js` | férias CLT: períodos aquisitivos (R1 a R4), validação V1 a V12 |
| `js/rules-recruiting.js` | máquina de etapas (C1, C2), e-mail normalizado, slug, retenção LGPD |
| `js/rules-approval.js` | aprovação em etapas (submit, decide, cancel, etapa pulada) |
| `js/rules-portal.js` | portal público (G1 a G5): honeypot, tempo mínimo, limite diário, DTO |
| `js/rules-promotion.js` | promoções P1 a P6, faixa salarial |
| `js/rules-performance.js` | avaliação A3 a A7 |
| `js/rules-visibility.js` | personas, sharing por cadeia de gestores, FLS de salário |

Depois dos motores vêm `data.js` (dados fictícios), `queries.js`, `actions-*.js` (mutações sobre o estado), `store.js`,
e a interface (`ui.js`, `icons.js`, `views/*.js`, `app.js`).

## Roteiro

`ROTEIRO.md` é gerado a partir de `js/tour.js`, a mesma fonte do roteiro guiado da interface:

```bash
node demo/tools/gen-roteiro.js
```

## Como portar para o site Astro

O site (`salesforce.flupdigital.com.br`, worktree do portfólio) renderiza as demos em `astro/src/pages/projetos/[slug].astro`.
Esta demo foi feita para entrar como um iframe isolado: o CSS (todo sob `.rhc`) e o `localStorage` não colidem com o site.

1. Copie a pasta para o estático do site: `demo/` para `public/demos/rh-core/` (ou `astro/public/demos/rh-core/`, conforme o
   projeto). Não precisa de build nem de dependência.
2. Crie `astro/src/components/portfolio/demos/RhCoreDemo.astro`:

   ```astro
   <div class="demo-block live-demo" id="demo-rh-core">
     <div class="demo-header">
       <div><h3>Explore o RH Core como cinco personas</h3><p>Troque de persona, siga o roteiro guiado e veja as regras de férias, recrutamento e segurança funcionando.</p></div>
       <span class="demo-badge">Demo ao vivo</span>
     </div>
     <div class="demo-frame">
       <div class="demo-frame-bar"><span></span><span></span><span></span><code>rh-core.app</code></div>
       <iframe src="/demos/rh-core/index.html" title="Demonstração interativa do RH Core" loading="lazy"
         style="width:100%;height:min(88vh,920px);border:0;display:block"></iframe>
     </div>
   </div>
   ```

3. Em `[slug].astro`: importe o componente e acrescente `{project.slug === 'rh-core' && <RhCoreDemo />}` dentro de
   `<section class="project-demo-section" id="demo">`.
4. Em `astro/src/data/projects.ts`, adicione o projeto `rh-core` (título, resumo, problema, arquitetura, decisões, seções, link do
   GitHub). Mantenha a formulação padrão de confidencialidade e não invente clientes, resultados ou prazos.
5. Se preferir sem iframe, dá para montar `<div id="rhc-app">` na página e carregar os scripts na ordem do `index.html`
   (a ordem importa), mas aí o `localStorage` e o CSS passam a compartilhar a página com o site.
6. Preview no worktree do site e revisão de confidencialidade antes de qualquer publicação. Esta pasta não faz deploy.

## Como publicar no GitHub Pages (opcional)

A pasta `demo/` é estática. Duas formas:

- Em Settings > Pages, publicar a partir de uma branch e pasta (renomeie ou copie `demo/` para `docs/` na branch de publicação), ou
- uma ação do GitHub que envie a pasta `demo/` com `actions/upload-pages-artifact` e `actions/deploy-pages`.

Não há arquivo de workflow neste diretório: a decisão de publicar é do Witor.

## Limitações

- Dados em memória e `localStorage`: apagar os dados do site ou usar "Reiniciar demo" volta ao estado inicial. A demo não sincroniza entre abas.
- A data é fixa (26/10/2026) para que prazos e regras sejam determinísticos.
- Simplificações em relação ao produto Salesforce estão listadas em `docs/execucao/modulos/demo.md`.
