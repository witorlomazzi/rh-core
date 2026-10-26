# 19. Fase 3: Pacote, README, CI e verificação final

Executor: orquestrador. Branch: `develop` (integração).

## Pacote

1. Garantir que `force-app` inteiro implanta numa scratch org limpa (INT recriada se necessário) e que
   `sf apex run test --test-level RunLocalTests --code-coverage --wait 60` passa com cobertura geral de
   pelo menos 85% e cada classe com pelo menos 85%.
2. `sf package create --name "RH Core" --package-type Unlocked --path force-app --no-namespace --target-dev-hub witor-dev`
   (só se ainda não existir; ver `sfdx-project.json`).
3. `sf package version create --package "RH Core" --installation-key-bypass --code-coverage --wait 90 --target-dev-hub witor-dev`.
   Limite: 6 versões por dia no Dev Hub. Máximo de 3 tentativas nesta noite.
4. Se houver tempo e limite de scratch org: criar org nova, instalar a versão
   (`sf package install --package <04t...> --wait 30 --target-org <nova>`), rodar o seed e o smoke.
5. Plano B: metadado recusado no pacote vai para `unpackaged/<nome>` com motivo em PROGRESSO.md.

## README (formato do portfólio)

Seções: título e frase; badge de CI; aviso de projeto demonstrativo (texto da spec 00); o problema; a
solução por módulo; arquitetura (diagrama Mermaid dos módulos e do fluxo de aprovação); modelo de dados
(diagrama Mermaid ER resumido); segurança (a matriz da spec 02 resumida e os testes de segurança);
decisões técnicas com trade-offs (motor de aprovação próprio em vez de Approval Process; sharing por
cadeia de gestores em vez da hierarquia de papéis; Custom Metadata para regras CLT; site fora do pacote);
regras da CLT implementadas com referência aos artigos e aviso de convenção coletiva; testes (números
recontados no código); como instalar (link do pacote se houver) e como rodar em scratch org; roteiro de
demo; por onde começar a ler o código; limitações e próximos passos. Sem travessão, sem emoji.

## CI (`.github/workflows/ci.yml`)

Mesmo padrão dos repositórios do portfólio: Jest (Node 20), Salesforce Code Analyzer (Node 22,
severidade 2), job Apex condicionado a `APEX_CI_ENABLED` e `SFDX_AUTH_URL`.

## Relatório final

`docs/execucao/RELATORIO-FINAL.md`: o que foi entregue por fase, critérios de aceite marcados, números
(classes, testes, cobertura, LWCs), pendências com motivo, URLs (site, pacote), comandos para
reproduzir, e o que precisa de decisão do Witor.
