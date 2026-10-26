# Plano de execução multiagente (noite de 25 para 26/10/2026)

Objetivo: entregar o máximo das specs 10 a 19 até a manhã, com qualidade de produção, sem depender do
Witor durante a noite. Quando algo travar, documentar e seguir para o próximo item. Nunca ficar parado.

## Papéis

- **Orquestrador** (a sessão principal): cria o repositório e as orgs, executa a Fase 0, dispara os
  agentes de módulo em paralelo, revisa e integra cada entrega, roda a verificação de integração, mantém
  `PROGRESSO.md` e faz a Fase 3.
- **Agentes de módulo** (subagentes `general-purpose`, em segundo plano, um por módulo): implementam uma
  spec dentro da própria pasta, numa branch própria, num worktree próprio, e entregam com os gates da
  spec 03 cumpridos. Usam `docs/execucao/PROMPT-AGENTE-MODULO.md` como instrução.

## Orgs (limite do Dev Hub: 3 ativas, 6 criações por dia)

| Alias | Uso | Quem implanta |
|---|---|---|
| `rh-int` | Integração: `develop` inteiro, testes completos, site, seed, demo | só o orquestrador |
| `rh-w1` | Trabalho: leave e promotion (Fase 1), onboarding (Fase 2) | agentes desses módulos |
| `rh-w2` | Trabalho: recruiting e performance (Fase 1), portal e analytics (Fase 2) | agentes desses módulos |

Criação: `sf org create scratch --definition-file config/project-scratch-def.json --alias <alias> --duration-days 7 --target-dev-hub witor-dev --wait 30`.
Na Fase 2, myhr usa `rh-int` depois que o orquestrador integrar a Fase 1 (o orquestrador implanta a
branch do agente em `rh-int` ao revisar).

**Trava de deploy por org** (dois agentes na mesma org): antes de `deploy` ou `apex run test`, criar o
diretório de trava de forma atômica; se já existir, esperar 30 segundos e tentar de novo (até 20 minutos;
trava com mais de 40 minutos é considerada abandonada e pode ser removida, registrando no PROGRESSO):
```bash
LOCK="C:/Users/sousa/Desktop/Claudio/Salesforce/rh-core/.locks/<alias>"
until mkdir "$LOCK" 2>/dev/null; do sleep 30; done
# ... deploy e testes ...
rmdir "$LOCK"
```
`.locks/` está no `.gitignore`. Liberar a trava sempre, inclusive em erro (`trap 'rmdir "$LOCK"' EXIT`).

## Ondas

**Onda 0 (orquestrador, sequencial, ~1h30):** spec 10 inteira. Gate: deploy de `force-app` nas três orgs,
testes do core verdes, commit em `develop`. Sem este gate, nada da Onda 1 começa.

**Onda 1 (4 agentes em paralelo):** leave (spec 11, `rh-w1`), promotion (spec 12, `rh-w1`), recruiting
(spec 13, `rh-w2`), performance (spec 16, `rh-w2`). Cada um em `feat/<modulo>`.

**Integração 1 (orquestrador):** para cada agente que terminar: revisar o diff (só a pasta do módulo,
exceções justificadas), merge `--no-ff` em `develop`, deploy de `develop` em `rh-int`, rodar
`RunLocalTests` em `rh-int`. Quebrou: corrigir ou devolver ao agente com o erro (SendMessage), sem
bloquear os outros merges.

**Onda 2 (3 agentes em paralelo, assim que as dependências estiverem em `develop`):** portal (spec 14,
`rh-w2`, depende de recruiting), onboarding (spec 15, `rh-w1`, depende de recruiting e promotion),
analytics (spec 18, `rh-w2`, depende de todos da Fase 1; o seed roda em `rh-int` pelo orquestrador).
myhr (spec 17) começa quando leave, promotion, performance e onboarding estiverem em `develop`; usa
`rh-int` com trava.

**Integração 2 e Onda 3 (orquestrador):** merges da Onda 2, seed em `rh-int`, site, spec 19 (pacote,
README, CI, relatório final).

## Repositório e GitHub

- Repositório local: `C:\Users\sousa\Desktop\Claudio\Salesforce\rh-core`. Branch `main` contém só as specs
  (commit inicial). Integração em `develop`. Módulos em `feat/<modulo>`.
- GitHub: criar `witorlomazzi/rh-core` **privado** (`gh repo create witorlomazzi/rh-core --private --source . --push`
  a partir de `main`) e fazer push de `develop` e das branches `feat/*` ao fim de cada onda, como backup.
  **Proibido**: tornar o repositório público, push em `main` depois do commit inicial, force push, merge
  em `main`. Abrir o repositório ao público é decisão do Witor pela manhã.

## Agentes: como disparar

Use a ferramenta Agent com `subagent_type: "general-purpose"`, `isolation: "worktree"`, e o prompt:
o conteúdo de `PROMPT-AGENTE-MODULO.md` com as variáveis preenchidas (módulo, spec, org, branch,
dependências). Dispare os agentes da mesma onda na mesma mensagem para rodarem em paralelo. Eles rodam em
segundo plano; você é notificado quando cada um terminar. Enquanto isso, avance a integração dos que já
terminaram.

Se a ferramenta de worktree não estiver disponível, crie à mão:
`git worktree add ../rh-core-<modulo> -b feat/<modulo> develop` e passe o caminho absoluto ao agente.

## Quando algo trava

| Situação | Ação |
|---|---|
| Limite de scratch org | Reusar org existente (módulos de orgs diferentes passam a dividir com trava) |
| Metadado recusado pela org | Simplificar seguindo a spec (ex.: trocar componente por equivalente), registrar em Divergências |
| Licença insuficiente para usuários de teste | Spec 03, seção de licenças |
| Teste de outro módulo quebra na integração | Corrigir no menor escopo; se for do core, o orquestrador corrige e avisa os agentes |
| Agente falhou ou parou | Ler o relatório, relançar com o contexto do que já foi feito (a branch existe) ou o orquestrador termina |
| Limite de uso do modelo | Antes de cada passo, PROGRESSO.md atualizado; a próxima sessão retoma do último passo marcado |
| Site não cria | Plano B da spec 14 |
| Pacote não cria | Plano B da spec 19 |

## Registro

`docs/execucao/PROGRESSO.md` é atualizado pelo orquestrador a cada marco (início e fim de onda, merge,
falha, decisão). Os agentes escrevem só `docs/execucao/modulos/<modulo>.md` (relatório do módulo) dentro
da própria branch.
