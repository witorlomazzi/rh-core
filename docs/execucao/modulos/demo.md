# Módulo demo: demo interativa pública

Branch: `feat/demo` (criada de `develop`). Pasta: `demo/`. Nada em `force-app/`, nenhuma org tocada, sem push nem merge.

Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

## O que foi feito

Demo estática (HTML, CSS e JS puros, sem build, sem CDN, sem backend) que reproduz as regras reais das specs 00, 01, 02 e 10 a 18
em JavaScript, com dados da Vetra Distribuidora (40 colaboradores em árvore de 4 níveis, 14 cargos, 6 departamentos,
4 vagas, 25 candidatos, 30 candidaturas, ciclo de avaliação e plano de onboarding).

| Área | Entrega | Spec |
|---|---|---|
| Personas | Colaborador, Gestor, RH, Recrutador e Candidato; muda navegação, dados visíveis e ações | 02 |
| FLS | Salário mascarado (cadeado) em todas as telas, exceto para o RH | 02 |
| Organograma | Árvore e lista, expandir/recolher, busca, teclado (setas), cartão com iniciais, visibilidade por persona | 10 |
| Férias | Períodos aquisitivos (R1 a R4), motor V1 a V12 com explicação por regra, cenários prontos, rascunho, calendário da equipe com conflito, prazos concessivos | 11 |
| Aprovação | Duas etapas (gestor, RH), caixa de aprovações, rejeição com comentário obrigatório, cancelamento, etapa pulada | 10 |
| Promoções | Solicitação do gestor sem salário, aprovação em 2 etapas, faixa salarial e justificativa fora da faixa (P6), efetivação, linha do tempo | 12 |
| Recrutamento | Kanban com arrastar e soltar e menu "Mover para", transições da máquina de etapas, motivo e nota obrigatórios, histórico com dias na etapa, vagas, retenção LGPD | 13 |
| Portal | Lista com filtros, detalhe, formulário com consentimento, honeypot, tempo mínimo, limite diário, DTO sem campos internos; candidatura vai ao mesmo estado do funil | 14 |
| Onboarding | Contratado cria colaborador em pré-admissão e plano de 8 tarefas; checklist por responsável; ativação pelo RH com recálculo de datas | 15 |
| Desempenho | Metas (peso 100%), autoavaliação, avaliação do gestor, calibração, liberação | 16 |
| Início e painel | Meu RH (colaborador e gestor); painel do RH com gráficos SVG (headcount, funil, tempo por etapa, avaliações, promoções) | 17, 18 |
| Guia | Aviso permanente da formulação padrão, "Reiniciar demo", roteiro guiado de 10 passos por persona (`demo/ROTEIRO.md`) | 18 |

Organização do código (`demo/js/`): motores puros sem DOM (`rules-*.js`), dados (`data.js`), consultas (`queries.js`), ações por módulo
(`actions-*.js`), estado (`store.js`) e interface (`ui.js`, `icons.js`, `views/*.js`, `app.js`). Detalhes em `demo/README.md`.

## Como verificar

```bash
node --test "demo/tests/*.test.js"   # 62 testes (regras, fluxos de ponta a ponta, ordem de carga, sem travessão/emoji)
node demo/tools/gen-roteiro.js       # regenera demo/ROTEIRO.md
cd demo && python -m http.server 8123  # abrir http://localhost:8123/ (ou abrir index.html direto)
```

Resultado dos testes na última execução: 62 aprovados, 0 falhas. Cobrem: V1 a V12 (cenários 14+10+6, 5+5+20, 5+5+5, fração de 4 dias,
início na sexta, véspera de feriado, abono de 11 em 30), tabela do art. 130 e período perdido, aprovação em 2 etapas, rejeição,
cancelamento, etapa pulada, transições do funil, nota e motivo, contratação idempotente, retenção LGPD, portal (honeypot, tempo
mínimo, limite diário, duplicidade, reaproveitamento do candidato), promoções (P1, P3, P4, P6, efetivação), desempenho (A3 a A7),
onboarding (O4, O5, O6) e visibilidade/FLS por persona.

### Verificação no navegador (pane embutido, Chromium)

Feita por DOM e eventos reais (os screenshots do pane expiraram por timeout em todas as tentativas, então não há captura visual):

- 27 combinações persona x tela mais 10 subabas/modos renderizam sem erro; console sem erros em todas as passagens.
- Mobile (375 x 812) e desktop (1280): `scrollWidth` igual à largura da janela em todas as telas, com roteiro aberto e com tabela em modo lista
  (tabelas viram cartões; só o calendário do mês rola dentro do próprio contêiner, nunca a página).
- Fluxos clicados: pedido de férias da Carolina (cenário da sexta bloqueia e desabilita o envio; cenário válido envia com aviso de conflito),
  gestor rejeita sem comentário (recusado) e aprova, RH aprova (status Aprovado); candidato sem consentimento (erro), envio com sucesso,
  "Nos bastidores", cartão novo na coluna Nova do recrutador; robô, envio rápido e limite diário; kanban por menu e por eventos de
  arrastar e soltar (colunas permitidas destacadas, soltar em coluna inválida mostra a mensagem da spec); reprovar pede motivo, Proposta pede
  nota, Contratado cria o colaborador e o plano; promoção do Lucas (sem salário para o gestor, atalho do 2o nível, faixa e justificativa
  no RH); metas 70% bloqueiam o envio, avaliação do gestor fora da fase é recusada, calibração e liberação, colaborador só vê depois;
  gestor não conclui tarefa do RH; ativação da admissão; organograma (busca não vaza colega, setas expandem e navegam); retenção LGPD;
  reiniciar demo; os 50 passos dos roteiros navegam para a tela certa.
- Bug encontrado e corrigido na verificação: `rules-promotion.js` dependia de `rules-visibility.js`, que estava depois no `index.html`
  (os testes em Node escondiam isso). Agora a ordem está certa e `tests/load-order.test.js` carrega os scripts como o navegador.

Não verificado: aparência visual por captura de tela, Firefox/Safari (arrastar e soltar nativo difere), leitor de tela real, toque físico.
A interface usa botões reais, `aria-pressed`/`aria-expanded`/`aria-live`, rótulos em todos os campos, foco visível e a alternativa por
menu para o arrastar do kanban.

## Como portar para o site (Astro)

Resumo (passo a passo completo em `demo/README.md`): copiar `demo/` para `public/demos/rh-core/` do site, criar
`RhCoreDemo.astro` com a moldura `.demo-frame` e um `<iframe src="/demos/rh-core/index.html">`, registrar `rh-core` em `[slug].astro`
e em `src/data/projects.ts`. O iframe isola o CSS (tudo sob `.rhc`) e o `localStorage`. Nenhum arquivo do worktree do portfólio foi tocado.
Preview não equivale a produção: revisão de confidencialidade e aprovação do Witor antes de publicar.

## Decisões tomadas (sem perguntar, pela opção mais simples e segura)

1. Data fixa 26/10/2026 (segunda-feira) para prazos determinísticos.
2. Personas fixas, uma pessoa por persona: Carolina Fontes (VTR-0015), Patrícia Lemos (VTR-0007, nível 2), Cláudia Rezende (VTR-0031),
   Marcelo Ibrahim (VTR-0032) e visitante sem login. Gestor contratante é a própria Patrícia (vaga de vendas).
3. Visibilidade: colaborador e recrutador veem a si e a cadeia de gestores; gestor, a subárvore mais a cadeia (para ancorar o organograma);
   RH, todos. A spec dá share de leitura da cadeia ao gestor, não ao subordinado; a demo mostra a cadeia só com nome e cargo.
4. Ciclo de avaliação começa em "Autoavaliação" (a spec 18 diz "Avaliação do gestor" com metade das autoavaliações enviadas). Com a spec,
   o colaborador não poderia editar nada (A3) e o fluxo não poderia ser percorrido. Metade das autoavaliações continua enviada.
5. Abono de pedido pendente também fica reservado no saldo (a spec só soma o abono dos pedidos aprovados). É a decisão mais conservadora.
6. Períodos aquisitivos antigos, com prazo concessivo vencido e sem pedido registrado, aparecem como histórico quitado.
7. A etapa 1 de promoções é do gestor de segundo nível (Rodrigo Tavares), que não é uma persona; a demo oferece o botão
   "Simular aprovação de Rodrigo" (atalho explícito) e o mesmo para a etapa de gestor de qualquer pedido que não seja de uma persona.
8. Etapa pulada recebe status Cancelado com o comentário "Etapa pulada: aprovador indisponível" (a lista de status da spec não tem "Pulada").
9. Notas de 0 a 5 no funil (Score__c); a avaliação de desempenho usa 1 a 5.
10. Salário do cadastro mascarado até para o próprio colaborador (a spec dá FLS de Salary__c só ao RH).

## Limitações

- Não há Apex, sharing real, FLS real nem Experience Cloud: tudo é simulado em JS, reproduzindo as regras. Serve para mostrar o
  comportamento do produto, não para provar a implementação Apex (que tem os próprios testes).
- Sem upload de currículo, login de candidato, notificações, folha, ponto ou integrações (fora do escopo da spec 00).
- Calendário limitado à equipe direta de um gestor por vez; sem feriados além dos de 2026 e 2027 cadastrados.
- Estado em `localStorage` da própria origem; não sincroniza entre abas.
- Sem testes automatizados de interface (a verificação do navegador foi manual por script); as regras têm testes Node.

## Arquivos

`demo/index.html`, `demo/css/demo.css`, `demo/js/*.js`, `demo/js/views/*.js`, `demo/tests/*.test.js`, `demo/tools/gen-roteiro.js`,
`demo/ROTEIRO.md`, `demo/README.md`, `demo/package.json`, este documento.
