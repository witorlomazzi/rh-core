# 18. Fase 2: Relatórios, dashboard e dados de demonstração (analytics)

Pasta: `force-app/analytics` e `scripts/`. Depende de todos os módulos. Branch: `feat/analytics`.

## Dados de demonstração (`scripts/apex/seed-vetra-rh.apex`, fora do pacote)

Idempotente (upsert por External Id), sem dado real. Todos os nomes fictícios.
- 6 departamentos: Diretoria, Comercial, Operações e Logística, Financeiro, Pessoas (RH), Tecnologia.
- 14 cargos em 2 trilhas, com faixas salariais e `Next_Position__c`.
- 40 colaboradores (matrícula `VTR-0001` em diante) em árvore de 4 níveis: 1 CEO, 5 diretores ou
  gerentes, 8 coordenadores, 26 analistas e assistentes; admissões entre 2019 e 2026; 3 com faltas
  (8, 16 e 35); 2 estagiários; 1 desligado.
- Vincular `User__c` aos usuários disponíveis na org (usuário admin = um gestor de nível 2 para a demo
  mostrar a visão de gestor; usuários extras conforme licenças) e atribuir os PSG: admin recebe
  `HR_Admin` e `HR_Manager`.
- Feriados nacionais de 2026 e 2027 e 2 municipais de São Paulo (`SP-SAO_PAULO`).
- Rodar `LeaveAccrualService` para gerar períodos; 12 pedidos de férias em estados variados.
- Histórico de admissão para todos (`PositionHistoryService.createAdmission`); 3 promoções (1 pendente,
  1 aprovada futura, 1 efetivada).
- 4 vagas (2 publicadas no portal), 25 candidatos e 30 candidaturas espalhadas pelo funil; 1 contratado
  com plano de onboarding.
- 1 ciclo de avaliação "Ciclo 2026" em Avaliacao_Gestor com metade das autoavaliações enviadas.
- Agendar `LeaveScheduler`, `PromotionEffectivationBatch`, `CandidateRetentionBatch` (script separado
  `scripts/apex/schedule-jobs.apex`).

## Relatórios (pasta de relatórios "RH Core", no pacote)

Report types customizados quando necessário (no pacote): Colaboradores com Períodos Aquisitivos;
Candidaturas com Candidato e Vaga; Avaliações com Ciclo.
1. Headcount por departamento (Employee__c Status__c = Ativo).
2. Férias com prazo concessivo vencendo (período Status__c = Prazo_Proximo).
3. Saldo de férias por colaborador.
4. Funil de recrutamento por etapa (Job_Application__c).
5. Tempo médio por etapa (Application_Stage_History__c).
6. Avaliações por status no ciclo atual.
7. Promoções por status.

Dashboard "Painel do RH" (pasta "RH Core"): 6 componentes com os relatórios 1, 2, 4, 5, 6, 7.
Plano B: se relatórios ou dashboard não forem aceitos no pacote, mover para `unpackaged/analytics` e
registrar.

## Critérios de aceite

- [ ] Seed roda duas vezes seguidas sem erro e sem duplicar.
- [ ] Relatórios e dashboard implantados e com dados depois do seed (smoke via Analytics API:
      `sf api request rest /services/data/v62.0/analytics/reports/<id>`).
- [ ] Documentado em `docs/execucao/DEMO.md` o roteiro de demonstração em 10 passos por persona.
