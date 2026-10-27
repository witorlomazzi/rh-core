# Relatório final: construção do RH Core

Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

Execução entre 25 e 26/10/2026. A sessão noturna parou após a Onda 0; as ondas 1 a 3 foram retomadas na manhã de 26/10 e atravessaram duas interrupções por limite de uso do modelo (07:55 a 12:10 e 12:30 a 17:10), com os agentes retomados do ponto em que pararam.

## Entregue por fase

| Fase | Módulo | Estado | Números informados pelo módulo |
|---|---|---|---|
| 0 | Core (modelo de dados, segurança, aprovação, organograma) | Integrado | 43 testes Apex, 97% de cobertura, 16 Jest |
| 1 | Férias CLT | Integrado | 99 testes Apex (classes com 94% ou mais), 45 Jest |
| 1 | Promoções | Integrado | 66 testes Apex, 32 Jest |
| 1 | Recrutamento | Integrado | 81 testes Apex (91% a 100%), 24 Jest |
| 1 | Desempenho | Integrado | 57 testes Apex (90% a 100%), 38 Jest |
| 2 | Onboarding | Integrado | 40 métodos de teste, 26 Jest |
| 2 | Analytics (seed, relatórios, painel) | Integrado | 2 testes de metadados; 7 relatórios, 4 report types, painel com 6 componentes |
| 2 | Meu RH | Integrado | 19 testes Apex (100%), 33 Jest |
| 2 | Portal de vagas | Integrado | 20 testes Apex (90% e 98%), 27 Jest; site publicado em scratch org |
| Extra | Demo pública (HTML, CSS, JS) | Integrada em `demo/` | 62 testes Node |
| 3 | README, CI e relatório | Concluído | n/a |
| 3 | Pacote (unlocked) | Ver "Pendências" | n/a |

Os números por módulo são os relatados nos relatórios em `docs/execucao/modulos/`. Os números do conjunto abaixo foram medidos na integração.

## Números do conjunto (medidos na org de integração `rh-int`)

- Apex: 440 testes, 0 falhas, cobertura de 97% (`RunLocalTests`, todos os módulos implantados). Só `SiteRegisterController` e `CommunitiesSelfRegController`, classes padrão do Experience Cloud da org e fora do pacote, ficam abaixo de 85%.
- Jest: 241 testes em 30 suítes passando (`npm run test:unit`).
- Demo: 62 testes Node passando (`node --test "demo/tests/*.test.js"`).
- Tamanho: 142 classes Apex (49 de teste), 12 triggers, 30 componentes LWC, 25 objetos, 19 permission sets, 7 relatórios.
- Seed em `rh-int`: 40 colaboradores, 6 departamentos, 14 cargos, 12 pedidos de férias, 3 promoções, 4 vagas, 25 candidatos, 30 candidaturas, 1 contratado com onboarding de 8 tarefas, Ciclo 2026 com 39 avaliações.
- Code Analyzer: cada módulo informou nenhuma violação de severidade 1 ou 2; não foi rodado de novo no conjunto.

## Critérios de aceite do projeto (spec 00)

- [x] Todas as fases com os critérios de aceite atendidos ou com pendência documentada.
- [x] Deploy de `force-app` inteiro numa scratch org sem erro (`rh-int`, 513 componentes e depois 600 e poucos com portal e analytics; não foi testado numa scratch org criada do zero para o projeto inteiro).
- [x] Testes Apex passando, cobertura de cada classe do pacote de pelo menos 85%; Jest passando.
- [~] Code Analyzer: informado por módulo; sem rodada única no repositório.
- [x] Versão do pacote criada com `--code-coverage`: 1.0.0-1, `04tbm000000t3JpAAI`, cobertura de 97%, validação de cobertura aprovada (terceira tentativa).
- [x] README no formato do portfólio.

## Decisões e divergências relevantes

Registradas em `docs/execucao/PROGRESSO.md` (decisões 1 a 8 do core) e em cada relatório de módulo. As principais:

- Hierarchy_Path__c virou Text(255) (limite de cerca de 13 níveis) porque Long Text não é filtrável por LIKE.
- Campo novo sem permission set fica invisível até para o admin: todo campo precisa de permissão de campo em um permission set atribuído a quem roda e testa. Foi a causa de falhas de validação do pacote em org limpa; seis testes passaram a rodar como usuário com HR_Admin.
- O portal recebe a candidatura como JSON em texto, porque o runtime LWR entregou parâmetros de classe Apex com campos nulos (achado só no site real).
- A demo pública começa o ciclo de avaliação em autoavaliação; a org começa em avaliação do gestor (spec 18). Documentado no `DEMO.md`.
- Jobs agendados pelo seed (`--agendar`) impedem o deploy de classes agendáveis e faziam falhar três testes de agendamento; os testes agora abortam jobs existentes e, para implantar, é preciso abortar os jobs antes.

## Pendências

- **Pacote.** A versão 1.0.0-1 foi criada na terceira e última tentativa permitida. As duas primeiras falharam na validação por testes que dependiam de permissão de campo do administrador (corrigidos). A versão é beta (não promovida) e não foi instalada numa org nova para testar a instalação nem rodar o seed lá.
- **Validação visual dos componentes Salesforce.** Os LWCs foram validados por Jest e por deploy; só o site de vagas (portal) foi aberto e usado em navegador como visitante anônimo.
- **Site de vagas.** Roda numa scratch org (expira em 02/11/2026); o Network está em `UnderConstruction`, publicado e acessível sem login.
- **Agendamentos.** Em `rh-int` os jobs recorrentes foram criados pelo seed; precisam ser abortados antes de novo deploy de classes agendáveis.
- **Dashboard na página "Painel do RH" do Meu RH.** O painel existe na pasta de dashboards e como aba padrão; não foi embutido na página de aplicativo.
- **Trocar o gestor depois do lançamento do ciclo de avaliação** não recalcula avaliador nem compartilhamento.
- **Os 3 colaboradores com usuário no seed** são limitados pelas licenças da scratch org (3 Salesforce Platform livres).

## URLs

- Repositório (privado): https://github.com/witorlomazzi/rh-core
- Site de vagas na scratch org `rh-w2` (expira com ela): https://computing-ruby-4189-dev-ed.scratch.my.site.com/vagas/
- Página do portfólio: criada em branch local `codex/rh-core-demo` do worktree `portfolio-site-rh-demo`, sem deploy.

## Reproduzir

```bash
npm install
sf org create scratch --definition-file config/project-scratch-def.json --alias rh-demo --duration-days 7 --target-dev-hub <dev-hub>
sf project deploy start --source-dir force-app --target-org rh-demo
bash scripts/seed-vetra-rh.sh rh-demo --agendar
sf apex run test --test-level RunLocalTests --code-coverage --target-org rh-demo --wait 60
npm run test:unit
node --test "demo/tests/*.test.js"
```

## O que depende de decisão do Witor

1. Abertura do repositório ao público e publicação da página no portfólio: autorizadas pelo Witor na conversa de 26/10/2026 (ver o registro no ClickUp 868mn2r18).
2. Promover a versão do pacote (hoje beta) e testar a instalação em org nova.
3. Gravar a demonstração em vídeo.
4. Quando abrir o repositório, decidir o link do GitHub na página do portfólio.

## Estado do pacote

Versão 1.0.0-1 (`04tbm000000t3JpAAI`), unlocked sem namespace, 611 arquivos de metadado, cobertura de 97%, `HasPassedCodeCoverageCheck` verdadeiro. Instalação: `sf package install --package 04tbm000000t3JpAAI --target-org <org> --wait 30`. Não promovida (`sf package version promote` fica para quando o Witor decidir). Não testada a instalação em org nova.

## Atualização de 26/10/2026 (noite)

- Repositório público (MIT, branch padrão `develop`).
- Página https://salesforce.flupdigital.com.br/projetos/rh-core.html publicada em produção; sitemap atualizado.
- App implantado na org `witor-dev` (560 componentes, 401 testes aprovados), com os grupos HR_Admin e HR_Manager atribuídos ao administrador e dados de demonstração da Vetra. Sem os três usuários de demonstração e sem jobs agendados.
- Em `witor-dev` a permissão `ViewDashboards` não é reconhecida: o permission set de analytics foi implantado sem ela (diferença só na org, não no repositório).
