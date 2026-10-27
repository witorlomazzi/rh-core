# Prompt da sessão noturna: orquestrador do RH Core

Você é o orquestrador da construção do **RH Core**, um produto de RH para Salesforce (unlocked package)
com a empresa fictícia Vetra Distribuidora. O Witor autorizou nesta noite (25 para 26/10/2026) a
construção completa com múltiplos agentes e vai deixar o computador ligado. **Ele está dormindo: não faça
perguntas, não espere respostas.** Decida pela opção mais simples e segura que cumpra as specs, registre
e siga. O objetivo é chegar de manhã com o máximo entregue, testado e documentado.

## Antes de tudo (10 minutos)

1. Leia, nesta ordem: `docs/specs/00-visao-geral.md`, `01`, `02`, `03`, `10`, depois os títulos e critérios
   de aceite de `11` a `19`, `docs/specs/91-fontes.md`, `docs/execucao/00-plano-multiagente.md` e
   `docs/execucao/PROMPT-AGENTE-MODULO.md`.
2. Leia `docs/execucao/PROGRESSO.md`. **Se já houver progresso registrado, você está retomando: continue
   do último passo marcado, não refaça o que está feito.**
3. Leia as regras do workspace em `AGENTS.md do workspace` e as notas de
   memória `padrao-projeto-salesforce.md`, `org-deploy-blockers.md`, `apex-approval-e-deploy-gotchas.md`,
   `permset-fls-campo-required-gotcha.md`, `cmdt-record-xmlns-xsd-gotcha.md` em
   a memoria do workspace.
4. Registre no ClickUp, na tarefa 868mn2r18 (https://app.clickup.com/t/868mn2r18), um comentário começando com `EM EXECUÇÃO` (agente,
   escopo, repositório, branches, orgs). Ao final, um comentário `CONCLUÍDO` ou `PARCIAL` com o resumo do
   relatório final.

## O que está autorizado (e o que não está)

Autorizado pelo Witor: criar 3 scratch orgs no Dev Hub `witor-dev` (aliases `rh-int`, `rh-w1`, `rh-w2`,
duração 7 dias) e mais 1 para teste de instalação se o limite permitir; criar o repositório privado
`witorlomazzi/rh-core` e fazer push de `main` (commit inicial), `develop` e `feat/*`; criar o pacote
"RH Core" e até 3 versões; disparar agentes em paralelo; commits locais.

Proibido: tornar o repositório público; push em `main` depois do commit inicial; merge em `main`; force
push; implantar qualquer coisa na org `witor-dev` (é Dev Hub e org pessoal) ou em outra org que não as
scratch orgs deste projeto; mexer no site do portfólio; enviar mensagem a terceiros; usar dado real; linha
`Co-Authored-By` nos commits.

## Execução

Siga `docs/execucao/00-plano-multiagente.md`:

1. **Preparação**: commit inicial em `main` só com `docs/` e `.gitignore`; `gh repo create witorlomazzi/rh-core --private --source . --push`;
   criar `develop`; criar as 3 orgs; registrar em PROGRESSO.md.
2. **Onda 0**: implementar a spec 10 (você mesmo, ou um único agente `core` se preferir preservar
   contexto). Gate: deploy de `force-app` em `rh-int`, `rh-w1`, `rh-w2`; testes do core verdes; gates da
   spec 03 no core. Commit em `develop`, push.
3. **Onda 1**: estando em `develop`, disparar na mesma mensagem 4 agentes (`Agent`, `general-purpose`,
   `isolation: "worktree"`, rodando em segundo plano) para leave, promotion, recruiting e performance,
   com o prompt de `PROMPT-AGENTE-MODULO.md` preenchido (módulo, spec, org, branch, dependências).
4. **Integração 1**: a cada agente que terminar, revisar o diff, conferir o relatório do módulo, rodar os
   gates por amostragem, merge `--no-ff` em `develop`, deploy em `rh-int`, `RunLocalTests` em `rh-int`,
   push. Corrigir quebras de integração. Atualizar PROGRESSO.md.
5. **Onda 2**: portal, onboarding e analytics assim que as dependências estiverem em `develop`; myhr
   quando leave, promotion, performance e onboarding estiverem integrados.
6. **Integração 2**: merges, deploy completo em `rh-int`, seed (`scripts/apex/seed-vetra-rh.apex`) em
   `rh-int`, site do portal (spec 14), smoke.
7. **Onda 3**: spec 19 (pacote, README, CI, relatório final), push de `develop`.

## Disciplina de execução

- Atualize `docs/execucao/PROGRESSO.md` em cada marco: horário, passo, resultado, próximo passo. Se a
  sessão cair por limite de uso, a próxima sessão retoma por ele.
- Nunca fique esperando sem fazer nada: enquanto agentes rodam, integre os que terminaram, revise código,
  escreva o README ou prepare o seed.
- Se um agente devolver parcial, decida: relançar com o contexto (a branch já existe), terminar você
  mesmo, ou registrar a pendência e seguir. Não deixe uma pendência travar as demais ondas.
- Comandos que podem passar de 2 minutos (deploy, testes, criação de org, versão de pacote) rodam em
  segundo plano com notificação, não em espera ativa.
- Antes de afirmar que algo está pronto, verifique (deploy, teste, consulta). Relatório honesto: o que
  não foi feito aparece como não feito.
- Ao terminar tudo, ou às 7h30 de 26/10 (o que vier primeiro), escreva `docs/execucao/RELATORIO-FINAL.md`
  (spec 19), faça push de `develop` e registre o comentário final no ClickUp.
