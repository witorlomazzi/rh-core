# Módulo analytics (relatórios, painel e dados de demonstração): relatório de entrega

Spec: `docs/specs/18-analytics-e-demo.md`. Branch `feat/analytics`. Org de trabalho `rh-w2` (com trava). Projeto demonstrativo, com empresa e dados fictícios.

## O que foi entregue

- **Seed da Vetra em 6 fases** (`scripts/apex/seed-vetra-rh-*.apex`) mais o executor `scripts/seed-vetra-rh.sh <alias> [--agendar]`. Cada fase é idempotente. O Apex anônimo aceita no máximo cerca de 32 mil caracteres por script (medido: 31 mil compila, 62 mil não), e usuários são DML de configuração que não pode ser misturado com DML de dados (MIXED_DML), por isso a divisão.
- **`schedule-jobs.apex`**: agenda `LeaveScheduler`, `PromotionEffectivationBatch` e `CandidateRetentionBatch`, preservando o que já estiver agendado.
- **4 report types** em `force-app/analytics/reportTypes`: Colaboradores com Períodos Aquisitivos, Candidaturas com Candidato e Vaga, Avaliações com Ciclo e Candidaturas com Histórico de Etapas.
- **7 relatórios** na pasta "RH Core" e o dashboard **Painel do RH** (6 componentes: relatórios 1, 2, 4, 5, 6 e 7), pastas compartilhadas com o grupo `HR_Team`.
- Permission set `HR_Analytics_Admin` (RunReports e ViewDashboards) e o teste `HrAnalyticsMetadataTest`.
- `docs/execucao/DEMO.md`: roteiro de 10 passos por persona (Colaborador, Gestor, RH, Recrutador, Candidato), alinhado a `demo/ROTEIRO.md`.

## Fases do seed

| Fase | Arquivo | Conteúdo |
|---|---|---|
| 0 | `seed-vetra-rh-0-usuarios.apex` | 3 usuários da licença Salesforce Platform (Carolina Fontes, Marcelo Ibrahim, Cláudia Rezende) com os grupos HR_Employee, HR_Recruiter e HR_Admin; Cláudia entra no grupo HR_Team. Username leva sufixo da org (único entre orgs). |
| 1 | `seed-vetra-rh-1-estrutura.apex` | 6 departamentos, 14 faixas, 14 cargos (2 trilhas, `Next_Position__c`), 40 colaboradores em 4 níveis (1 CEO, 5 diretores/gerentes, 8 coordenadores, 26 analistas e assistentes; 2 estagiários, 1 desligado, 1 em férias), 26 feriados (nacionais, 1 estadual e 2 municipais de SP por ano). O admin vira VTR-0007 (Patrícia Lemos, nível 2 da hierarquia de profundidade). |
| 2 | `seed-vetra-rh-2-ferias.apex` | 216 períodos (`LeaveAccrualService`), faltas 8, 16 e 35 (esta vira Perdido), 12 pedidos em todos os estados com etapas de aprovação, gozo histórico (140) para quitar períodos já vencidos. |
| 3 | `seed-vetra-rh-3-promocoes.apex` | 3 promoções (efetivada, aprovada futura, pendente no RH) com etapas; histórico de cargo (trajetórias de 4 pessoas e `createAdmission` para os 36 demais). |
| 4 | `seed-vetra-rh-4-recrutamento.apex` | 4 vagas (2 no portal), 25 candidatos, 30 candidaturas em todas as etapas com histórico e dias na etapa, contratado Gabriel Nakamura (PRE-000001) e, se o onboarding existir, plano com 8 tarefas. |
| 5 | `seed-vetra-rh-5-desempenho.apex` | Ciclo 2026 em Avaliacao_Gestor: 39 avaliações e autoavaliações (via `ReviewCycleService`), 117 metas, 21 autoavaliações enviadas, avaliações Pendente/Em andamento/Enviada. |

Números verificados na rh-w2: 40 colaboradores VTR + 1 pré-admissão, 38 ativos, 216 períodos (Concluído 142, Disponível 34, Em aquisição 37, Prazo próximo 2, Perdido 1), 12 pedidos de demonstração, 30 candidaturas.

## Critérios de aceite

- [x] Seed roda duas vezes seguidas sem erro e sem duplicar (`scripts/seed-vetra-rh.sh rh-w2 --agendar` rodado após a carga inicial: todas as fases reportam 0 criados).
- [x] Relatórios e dashboard implantados e com dados, via Analytics API (`GET /analytics/reports/<id>`): Headcount 6 grupos/38; Prazo concessivo 2 (Priscila, Rafael); Saldo 36 colaboradores; Funil 8 etapas/30; Tempo médio 5 etapas (média geral 4,6 dias); Avaliações 3 grupos/39; Promoções 3. Dashboard com 6 componentes.
- [x] `docs/execucao/DEMO.md` com o roteiro de 10 passos por persona.
- [x] Report types customizados no pacote (nenhum precisou do plano B `unpackaged/analytics`).

## Gates

- Deploy de `force-app/analytics` sem erro em rh-w2. Teste Apex `HrAnalyticsMetadataTest`: 2 de 2 passando (não há classe de produção neste módulo, logo não há cobertura a medir). Jest: não aplicável (sem LWC).
- Code Analyzer (`pmd:Recommended`, limiar 2): zero severidade 1 ou 2 (restam 2 de severidade 4: `RunAs` no teste de metadados). O `SeeAllData` do teste tem supressão justificada, pois Report e Dashboard só são visíveis ao Apex assim.
- Travessão e emoji: zero ocorrências em `force-app/analytics`, `scripts` e docs do módulo.
- Revisão `sf-code-reviewer`: feita manualmente contra a lista (a skill não foi invocada como ferramenta). Scripts sem SOQL ou DML em loop (consultas e DML antes e depois dos laços, em lote), sem Ids fixos, leitura de Custom Metadata apenas; contexto de sistema só nos serviços dos outros módulos.

## Decisões

1. **Seed dividido em 6 fases e um executor** em vez de um único `seed-vetra-rh.apex` (limite de 32 mil caracteres e MIXED_DML).
2. **Persona Gestor = admin que roda a carga**, vinculado a VTR-0007 (Patrícia Lemos). Só 3 usuários extras porque a licença Salesforce Platform tem 3 livres (a Salesforce tem 1). Os demais colaboradores não têm usuário; o motor pula as etapas cujo aprovador não existe.
3. **Pedidos de férias, promoções e candidaturas entram por DML direto** (pedidos de férias com o trigger ativo, que só valida e preenche o colaborador; promoções e candidaturas com bypass dos handlers, como sugerido pelos relatórios de promotion e recruiting), e o que o trigger faria é refeito a mão: snapshot, contagem da vaga, compartilhamento, fila dona. As etapas de aprovação são criadas no mesmo formato do motor (só a etapa corrente fica Pendente).
4. **Gozo histórico**: o status de período do `LeaveAccrualService` marca como Prazo_Proximo todo período com prazo já vencido e saldo. Para o relatório de prazos mostrar só os dois casos reais, os períodos vencidos são quitados com um pedido Concluído do saldo restante. Não há pedido para período Perdido.
5. **Ciclo 2026 em Avaliacao_Gestor** (spec 18), diferente da demo pública (autoavaliação). O ciclo é criado Planejado e avançado pelos serviços `completeLaunch` e `advance`. Avaliações e autoavaliações usam o modo confiável (`beginTrusted`) dos serviços, que existe para o lançamento e para cargas. Equipe da Patrícia (VTR-0015 a 0018) fica Pendente; as demais variam. Se o ciclo já existe, a fase não altera nada.
6. **Onboarding opcional**: o plano e as 8 tarefas só são criados quando a classe `OnboardingHiredHandler` existe (`Type.forName`); há a variável `createOnboardingPlan` no topo da fase 4 para forçar. O bloco foi validado em rh-w2 forçando `true` (8 tarefas, idempotente). Sem o módulo, o colaborador PRE-000001 e a candidatura Contratado existem sem plano; rodar a fase de novo depois da integração cria o plano.
7. **Tokens de relatório em tipos customizados** usam `Objeto$Campo` (`Employee__c.Accrual_Periods__r$Status__c` para filhos); em tipos de objeto único usam `CustomEntity$Objeto__c` e `Objeto__c.Campo`. Relacionamentos de lookup não entram como join de report type: os campos do pai entram como `Campo__c.Campo`.
8. **Ciclo atual** no relatório 6 = ciclo com início até hoje e fim de hoje em diante, para o relatório continuar com dados depois da liberação.
9. **Dashboard** usa `LoggedInUser` e `useReportChart` verdadeiro, para não depender de usuário nomeado e de colunas por componente.
10. O Headcount conta `Status__c = Ativo` (38); quem está em férias (Diego) fica fora, como a spec define o filtro.

## Pendências

- Não verifiquei os gráficos visualmente em navegador, só por Analytics API e deploy.
- Janela de calibração dos dados: prazos e férias em gozo valem para 26/10/2026.
- A carga não foi validada em org totalmente limpa (a rh-w2 estava vazia de dados do HR no início, e as fases rodaram em ordem).

## Pedidos ao orquestrador

1. **Core, PSG `HR_Admin`**: incluir o permission set `HR_Analytics_Admin` (RunReports e ViewDashboards). Sem ele, quem não é administrador do sistema não executa os relatórios mesmo com acesso à pasta. Opcional também em `HR_Manager`, se gestores devem ver o painel.
2. **Core, app `RH Core`**: acrescentar as abas padrão `standard-Dashboard` e `standard-report` (ou uma aba de painel) à navegação.
3. **Integração**: depois de integrar o onboarding em `develop` e implantar na `rh-int`, rodar `scripts/seed-vetra-rh.sh rh-int --agendar` uma vez (cria usuários, dados, plano de onboarding e jobs). Em `rh-int` o username dos usuários leva o sufixo da própria org.
4. Observação: o `RH_Core.reportFolder` e o `RH_Core.dashboardFolder` ficam compartilhados com o grupo `HR_Team` (View); o grupo existe no core.

## Como reproduzir

```bash
# trava da org (docs/execucao/00-plano-multiagente.md), depois, da raiz do repositório:
sf project deploy start --source-dir force-app --target-org rh-w2 --ignore-conflicts --wait 30
scripts/seed-vetra-rh.sh rh-w2 --agendar        # rode duas vezes para provar a idempotência
sf apex run test --class-names HrAnalyticsMetadataTest --result-format human --wait 20 --target-org rh-w2
sf code-analyzer run --workspace force-app/analytics --rule-selector pmd:Recommended --severity-threshold 2
# smoke dos relatórios (Git Bash: MSYS_NO_PATHCONV=1)
sf api request rest "/services/data/v62.0/analytics/reports/<id>" --target-org rh-w2
```
