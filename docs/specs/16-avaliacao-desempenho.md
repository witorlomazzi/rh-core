# 16. Fase 1: Avaliação de desempenho (performance)

Pasta: `force-app/performance`. Depende da Fase 0. Branch: `feat/performance`.

## Histórias

1. Como RH, crio um ciclo de avaliação e o lanço para todos os colaboradores ativos.
2. Como colaborador, registro minhas metas do ciclo e faço a autoavaliação até o prazo.
3. Como gestor, vejo a autoavaliação e as metas da equipe e registro minha avaliação.
4. Como RH, calibro as notas e libero o resultado; só então o colaborador vê a avaliação do gestor.

## Regras

- A1. `ReviewCycleService.launch(cycleId)`: só RH; ciclo em Planejado; cria um
  `Performance_Review__c` (Status__c Pendente, Reviewer__c = usuário do gestor direto) e um
  `Self_Assessment__c` por colaborador ativo com `User__c`; idempotente por `Unique_Key__c`; ciclo vira
  Autoavaliacao. Em lote (Batch se mais de 200 colaboradores). Contexto de sistema (spec 02).
- A2. Avançar fases do ciclo: Autoavaliacao → Avaliacao_Gestor → Calibracao → Concluido, só RH.
- A3. Autoavaliação só editável pelo próprio colaborador, com o ciclo em Autoavaliacao, e até enviar
  (Submitted__c = true bloqueia edição). Nota entre 1 e Rating_Scale_Max__c.
- A4. Metas: soma de Weight__c das metas ativas do colaborador no ciclo deve ser 100% para enviar a
  autoavaliação. Aviso no componente enquanto não fechar 100%.
- A5. Avaliação do gestor só editável pelo Reviewer__c, com o ciclo em Avaliacao_Gestor; Status__c
  Pendente → Em_Andamento → Enviada.
- A6. Calibração: RH ajusta `Calibrated_Rating__c` (Status__c = Calibrada).
- A7. Liberação (`ReviewCycleService.release(cycleId)`), só RH, com o ciclo em Calibracao: todas as
  avaliações Enviada ou Calibrada viram Liberada, criam share de leitura para o colaborador
  (`Employee_Release__c`) e o ciclo vira Concluido. Notificar colaboradores.
- A8. Compartilhamento conforme spec 02 (`PerformanceSharingService`).

## Componentes

Apex: `ReviewCycleService`, `ReviewCycleSelector`, `ReviewCycleController`, `PerformanceReviewService`,
`PerformanceReviewSelector`, `PerformanceReviewController`, `PerformanceSharingService`,
`SelfAssessmentService`, `GoalService`, `GoalSelector`, `ReviewLaunchBatch`, triggers e handlers dos
objetos do módulo, testes.

LWC:
- `performanceMyCycle`: para o colaborador, metas (adicionar, peso, soma), autoavaliação, prazo e status;
  depois de liberado, mostra a avaliação do gestor (nota final = calibrada, se houver).
- `performanceTeamReviews`: para o gestor, lista da equipe com status da autoavaliação e da avaliação;
  abre `performanceReviewForm`.
- `performanceReviewForm`: autoavaliação e metas do colaborador (leitura) e formulário do gestor.
- `performanceCycleAdmin`: para o RH, painel do ciclo com contagens por status e botões de avançar fase,
  calibrar e liberar.

## Critérios de aceite

- [ ] Ciclo completo em teste: lançar, metas com 100%, autoavaliação, avaliação do gestor, calibração,
      liberação; colaborador só lê a avaliação depois da liberação.
- [ ] A3, A4, A5 com testes negativos. Lançamento idempotente e com 200 colaboradores.
- [ ] Segurança: colaborador não lê Calibrated_Rating__c; gestor de outra equipe não vê avaliações.
- [ ] Jest para os 4 LWCs. Gates da spec 03.
