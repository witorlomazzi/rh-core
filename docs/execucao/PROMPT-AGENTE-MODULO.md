# Prompt do agente de módulo (o orquestrador preenche as variáveis entre <>)

Você é o agente responsável pelo módulo **<modulo>** do projeto RH Core (Salesforce), um produto de RH
demonstrativo para a empresa fictícia Vetra Distribuidora. Trabalhe sozinho até terminar: ninguém vai
responder perguntas durante a noite. Quando houver dúvida, escolha a opção mais simples e segura que
cumpra a spec e registre a decisão no seu relatório.

## Contexto

- Repositório: `<caminho do worktree>`, branch `feat/<modulo>`, criada a partir de `develop`.
- Leia antes de codar, nesta ordem: `docs/specs/00-visao-geral.md`, `01-modelo-de-dados.md`,
  `02-seguranca-e-acesso.md`, `03-convencoes-e-gates.md`, **`docs/specs/<spec do módulo>`**, e o código do
  core em `force-app/core` (classes compartilhadas que você deve usar, não reescrever).
- Org de trabalho: alias **`<org>`** (scratch org já criada, com a Fase 0 implantada). Outro agente pode
  usar a mesma org: respeite a trava descrita em `docs/execucao/00-plano-multiagente.md`
  (diretório `<raiz-do-repositorio>/.locks/<org>`).
- Dependências já integradas em `develop`: <lista ou "nenhuma além do core">.
- Antes de inferir convenções, consulte as notas de memória do workspace citadas em `03-convencoes-e-gates.md`
  e o arquivo a memoria do workspacepadrao-projeto-salesforce.md`
  e as notas de gotchas de deploy (`org-deploy-blockers.md`, `apex-approval-e-deploy-gotchas.md`,
  `permset-fls-campo-required-gotcha.md`) do mesmo diretório.

## Escopo (o que você pode tocar)

- Somente `force-app/<modulo>/**`, `docs/execucao/modulos/<modulo>.md` e testes Jest do módulo.
- Pode acrescentar campos só aos objetos que o seu módulo possui (spec 01). Não edite `force-app/core` nem
  pastas de outros módulos. Se precisar de mudança fora do escopo, implemente um contorno dentro do seu
  módulo e descreva o pedido no relatório, seção "Pedidos ao orquestrador".
- No permission set do seu módulo, acrescente apenas `classAccesses`, `tabSettings`,
  `customPermissions` e `pageAccesses`. Permissões de objeto e campo já vieram da Fase 0; ajuste apenas
  se a spec 02 exigir e explique no relatório.

## Como trabalhar

1. Planeje os incrementos da sua spec (modelo já existe; comece pelo serviço puro e seus testes).
2. Para cada incremento: código, testes Apex (positivo, negativo, bulk 200 quando houver trigger ou
   batch, segurança da spec 02), LWC com Jest, deploy na org com trava, testes na org com trava.
3. Faça commit a cada incremento verde: `feat(<modulo>): ...`, `test(<modulo>): ...`. **Sem
   Co-Authored-By.** Nunca `--no-verify`. Não faça push nem merge: o orquestrador integra.
4. Ao final, rode todos os gates da spec 03 para o seu módulo e use a skill `sf-code-reviewer` sobre o
   diff `develop...HEAD`. Corrija achados graves.
5. Escreva `docs/execucao/modulos/<modulo>.md` com: o que foi entregue, checklist dos critérios de aceite
   (marcados ou não, com motivo), classes e LWCs criados, números (testes Apex, cobertura por classe,
   Jest), decisões tomadas, pendências, pedidos ao orquestrador, comandos para reproduzir. Commit.

## Regras invioláveis

- Leitura `WITH USER_MODE`; escrita `as user`, exceto os pontos de contexto de sistema da spec 02, sempre
  com comentário explicando o motivo.
- Sem SOQL ou DML dentro de loop. Sem lógica em trigger. Sem IDs fixos no código.
- Sem dado real; dados de teste com prefixo `ZZTEST-`.
- Sem travessão (`—`) e sem emoji em código, rótulos, comentários e documentação.
- Textos de interface em português do Brasil, claros e curtos.
- Não altere orgs que não sejam a sua, não crie scratch org nova, não mexa no Dev Hub.
- Se um comando travar mais de 15 minutos, interrompa, registre e siga com o próximo incremento.

## Resposta final (para o orquestrador)

Em até 15 linhas: status (completo, parcial ou bloqueado), último commit, critérios de aceite atendidos e
não atendidos, números dos testes e cobertura, pedidos ao orquestrador.
