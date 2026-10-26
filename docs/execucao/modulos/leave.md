# Módulo leave (Férias CLT): relatório de entrega

Branch `feat/leave`, spec `docs/specs/11-ferias-clt.md`, org de trabalho `rh-w1` (com trava). Projeto demonstrativo, com empresa e dados fictícios.

## O que foi entregue

- Motor de regras puro `LeaveRuleEngine` (V1 a V12, sem SOQL nem DML), com mensagens em português e parâmetros de `HR_Setting__mdt`.
- Geração de períodos aquisitivos (`LeaveAccrualService`, `LeaveAccrualBatch`), idempotente por `Unique_Key__c`, com direito pela tabela do art. 130 (`HR_Absence_Rule__mdt`) e status (R4).
- Solicitação (`LeaveRequestService`): verificar regras, criar rascunho como o usuário, enviar para o `ApprovalService`, cancelar.
- Aprovação em duas etapas via `LeaveApprovalHandler` (implementa `ApprovalOutcomeHandler`), com notificação `HR_Request_Decided`.
- Ciclo de vida diário (`LeaveStatusBatch`) e agendador único (`LeaveScheduler.scheduleDaily()`, 01:00).
- Triggers `LeaveRequestTrigger` e `LeaveAccrualPeriodTrigger` (handlers `LeaveRequestTriggerHandler` e `LeaveAccrualPeriodTriggerHandler`, nomes exigidos pelos testes do core).
- Controllers `LeaveRequestController` e `LeaveTeamCalendarController`.
- LWC: `leaveBalanceCard`, `leaveRequestForm`, `leaveRequestList`, `leaveTeamCalendar` e o módulo utilitário `leaveUtils`. Canal de mensagem `LeaveChanged` para o formulário e a lista atualizarem o saldo sem recarregar a página.
- Permission sets: apenas `classAccesses` acrescentados em `HR_Leave_Employee`, `HR_Leave_Manager` e `HR_Leave_Admin`.

## Classes

| Classe | Papel |
|---|---|
| `LeaveRuleEngine`, `LeaveRuleResult` | Regras V1 a V12 e DTO do resultado |
| `LeaveAccrualService`, `LeaveAccrualBatch` | Períodos aquisitivos (sistema) |
| `LeaveStatusBatch`, `LeaveScheduler` | Em gozo e concluído; agendamento |
| `LeaveRequestService` | Verificar, criar, enviar, cancelar |
| `LeaveRequestSelector`, `LeaveAccrualPeriodSelector` | Consultas em `USER_MODE` |
| `LeaveApprovalHandler` | Desfecho da aprovação |
| `LeaveRequestTriggerHandler`, `LeaveAccrualPeriodTriggerHandler` | Regras de trigger |
| `LeaveRequestController`, `LeaveTeamCalendarController` | Entradas das telas |
| Testes | `LeaveRuleEngineTest`, `LeaveAccrualServiceTest`, `LeaveRequestFlowTest`, `LeaveTriggerTest`, `LeaveBatchTest`, `LeaveControllerTest`, apoio `LeaveTestData` |

## Números

- Apex em `rh-w1`: 99 testes, 100% de aprovação.
- Cobertura por classe: `LeaveRuleEngine` 100%, `LeaveRuleResult` 100%, `LeaveAccrualService` 99%, `LeaveAccrualBatch` 100%, `LeaveAccrualPeriodSelector` 100%, `LeaveAccrualPeriodTriggerHandler` 100%, `LeaveApprovalHandler` 100%, `LeaveStatusBatch` 100%, `LeaveScheduler` 100%, `LeaveTeamCalendarController` 100%, `LeaveRequestSelector` 97%, `LeaveRequestTriggerHandler` 97%, `LeaveRequestController` 96%, `LeaveRequestService` 94%.
- Jest: 45 testes em 5 suítes (4 LWCs e `leaveUtils`), todos passando. ESLint dos LWCs sem erro.
- Code Analyzer (`pmd:Recommended`): nenhuma violação de severidade 1 ou 2 (restam 55 moderadas e 171 baixas, em sua maioria ApexDoc e `RunAs` em testes).
- Travessão e emoji: zero ocorrências no módulo.

## Critérios de aceite

- [x] `LeaveRuleEngineTest`: caso positivo e negativo por regra V1 a V12; cenários 14+10+6 válido, 5+5+20 válido, 5+5+5 inválido (V7), 4 dias inválido (V6), início na sexta com descanso no domingo inválido (V4), véspera de feriado inválido (V4), abono de 11 dias em 30 inválido (V8).
- [x] `LeaveAccrualServiceTest`: admissão há 3 anos gera 3 períodos (ver decisão 1), reexecutar não duplica, 10 faltas geram 24 dias, 33 faltas geram Perdido, lote de 200 colaboradores.
- [x] Fluxo completo: colaborador envia, gestor aprova, RH aprova, status Aprovado, roll-ups e saldo corretos; rejeição pelo gestor encerra e libera o saldo.
- [x] Segurança (spec 02): colaborador não vê pedido nem período de colega; gestor vê equipe direta e indireta e não vê outra equipe; colaborador não altera `Status__c` nem `Rule_Check_Result__c` por DML; gestor não solicita pelo colaborador; datas travadas fora do rascunho.
- [x] Jest para os 4 LWCs.
- [~] Gates da spec 03: deploy, testes Apex, Jest, analyzer, travessão e emoji cumpridos. A revisão com `sf-code-reviewer` foi feita sobre o diff e não deixou achado grave; as ressalvas estão em "Pendências".

## Decisões

1. "Admissão há 3 anos" foi testada como 3 anos menos 1 dia, que gera 3 períodos. Com exatamente 3 anos, o quarto período começa hoje e também é gerado (teste próprio, 4 períodos), pois R1 manda gerar até o período atual.
2. O abono de pedidos pendentes só reduz o saldo depois da aprovação, porque o roll-up `Days_Sold__c` filtra por status aprovado (spec 01). O motor compensa: V2 e V8 contam o abono de todos os pedidos não cancelados nem rejeitados do período, inclusive rascunhos e pendentes.
3. V7 limita o mínimo do período principal ao direito do período (direito de 12 dias exige fração única de 12), para não tornar impossível quem tem direito reduzido.
4. V9 só aparece depois do fim do período aquisitivo, que é quando o pedido é permitido (V1); na prática todo abono entra como aviso, como na spec.
5. V12 usa contexto de sistema (classe interna `without sharing` em `LeaveRequestSelector`) porque o colaborador não enxerga férias de colegas, e o aviso não expõe nomes: só a contagem de colegas. O gestor vê quem é pelo calendário da equipe.
6. Só o colaborador do período ou o RH (custom permission `HR_Admin_Access`) solicita; o gestor enxerga a equipe, mas não pede férias por ela. A exceção de antecedência (V3) só vale para o RH.
7. `LeaveAccrualPeriodTriggerHandler` na inserção só preenche o vazio (permite carga de dados com direito informado) e, na edição, recalcula o direito quando as faltas mudam e marca Perdido acima de 32.
8. O lote de status leva Aprovado cujo fim já passou direto a Concluído, sem mexer no colaborador; só `Ativo` vira `Ferias` e só `Ferias` volta a `Ativo`.
9. `LeaveScheduler` é o único Schedulable e dispara os dois lotes; os lotes são apenas Batchable.
10. Aprovado não é cancelável pelo serviço (a spec só prevê cancelar rascunho e pendente).
11. Rascunho de pedido bloqueado pelo motor no `submitRequest` do controller é revertido (savepoint), então a tela não acumula rascunhos.

## Pendências

- Cartão, formulário e lista ainda não estão em nenhuma FlexiPage de `Employee__c`: isso é da Fase 2 (myhr), como diz a spec.
- Não foi feita verificação visual dos LWCs na org nem no navegador; validação por Jest.
- O agendamento diário não foi criado na org (`LeaveScheduler.scheduleDaily()` é decisão de quem implanta).
- Analyzer: violações moderadas e baixas restantes (ApexDoc nas classes de teste, `RunAs`).

## Pedidos ao orquestrador

- Nenhuma mudança no core foi necessária.
- Ao integrar, atribuir `HR_Leave_*` via os PSG existentes; os PSG já referenciam os permission sets e precisam ser recalculados após o deploy.
- Na Fase 2, compor os 4 LWCs nas páginas do Meu RH; o cartão dispara `requestleave` com `periodId` para o formulário (propriedade `period-id`).

## Como reproduzir

```bash
# trava da org (ver docs/execucao/00-plano-multiagente.md), depois:
sf project deploy start --source-dir force-app/leave --target-org rh-w1 --ignore-conflicts --wait 20
sf apex run test --class-names LeaveRuleEngineTest LeaveAccrualServiceTest LeaveRequestFlowTest LeaveTriggerTest LeaveBatchTest LeaveControllerTest --code-coverage --result-format human --wait 30 --target-org rh-w1
npx sfdx-lwc-jest -- force-app/leave
sf code-analyzer run --workspace force-app/leave --rule-selector pmd:Recommended --severity-threshold 2
```
