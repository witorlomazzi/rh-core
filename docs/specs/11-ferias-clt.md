# 11. Fase 1: Férias CLT (leave)

Pasta: `force-app/leave`. Depende da Fase 0. Branch: `feat/leave`.

## Histórias

1. Como colaborador, vejo meus períodos aquisitivos, dias de direito, saldo e prazo para tirar férias.
2. Como colaborador, solicito férias escolhendo início, dias e se quero vender dias (abono). Antes de
   enviar vejo se o pedido respeita as regras, com a explicação de cada regra quebrada.
3. Como gestor, vejo um aviso quando o pedido coincide com férias de outra pessoa da equipe e aprovo ou
   rejeito com comentário.
4. Como RH, dou a aprovação final e acompanho quem está com prazo concessivo vencendo.
5. Como gestor, vejo o calendário de férias da equipe no mês.

## Regras (todas parametrizadas por `HR_Setting__mdt` e `HR_Absence_Rule__mdt`)

Fonte: CLT arts. 130, 134, 135, 137 e 143, com a redação da Lei 13.467/2017. Ver `docs/specs/91-fontes.md`.

**Períodos aquisitivos (`LeaveAccrualService`, `LeaveAccrualBatch` Schedulable diário)**
- R1. Primeiro período começa em `Hire_Date__c`; cada período dura `Accrual_Period_Months__c` meses
  (fim = início + 12 meses - 1 dia). Gerar todos os períodos até o atual, só para Employment_Type__c = CLT
  e Status__c diferente de Desligado. Idempotente por `Unique_Key__c` (upsert).
- R2. `Concession_Deadline__c` = fim do período + 12 meses.
- R3. `Entitled_Days__c` pela tabela de faltas (`HR_Absence_Rule__mdt`); acima de 32 faltas: 0 dias e
  Status__c = Perdido.
- R4. Status__c: Em_Aquisicao (hoje <= fim), Disponivel (adquirido e saldo > 0),
  Prazo_Proximo (saldo > 0 e faltam até `Concession_Warning_Days__c` dias para o prazo concessivo),
  Concluido (saldo = 0).

**Validação do pedido (`LeaveRuleEngine`, puro, sem SOQL)**
Entrada: período, pedidos já existentes do período (não cancelados nem rejeitados), datas de descanso e
feriados, configurações, data de hoje. Saída: lista de `RuleResult` com código, bloqueante sim/não e
mensagem em português.
- V1 `PERIODO_NAO_ADQUIRIDO`: o período ainda está em aquisição (hoje <= End_Date__c). Bloqueante.
- V2 `SALDO_INSUFICIENTE`: Days__c + Sold_Days__c maior que o saldo (descontando pendentes). Bloqueante.
- V3 `ANTECEDENCIA`: início com menos de `Leave_Min_Notice_Days__c` dias a partir de hoje. Bloqueante
  para colaborador; o RH pode enviar mesmo assim marcando "exceção" (campo de entrada do serviço
  `allowNoticeException`, só aceito para usuário com HR_Leave_Admin).
- V4 `INICIO_ANTES_DESCANSO`: início dentro dos `Leave_Block_Days_Before_Rest__c` dias que antecedem
  feriado (da localidade do colaborador ou nacional) ou dia de descanso semanal. Bloqueante.
  Exemplo com descanso no domingo: início na sexta ou no sábado é proibido.
- V5 `QUANTIDADE_PERIODOS`: o período passaria a ter mais de `Leave_Max_Splits__c` frações. Bloqueante.
- V6 `MINIMO_FRACAO`: fração com menos de `Leave_Min_Other_Period_Days__c` dias. Bloqueante.
- V7 `PERIODO_PRINCIPAL`: considerando os pedidos existentes e o novo, se as frações já usam todo o
  direito ou atingem o máximo de frações, pelo menos uma precisa ter `Leave_Min_Main_Period_Days__c` dias.
  Também bloqueia quando o saldo restante não permitiria mais cumprir a regra (ex.: já existem 2 frações
  de 5 dias e a terceira teria menos de 14). Bloqueante.
- V8 `ABONO_LIMITE`: Sold_Days__c somado ao já vendido no período maior que
  `Math.floor(Entitled_Days__c / Leave_Max_Sold_Days_Divisor__c)` (30 dias de direito permitem 10).
  Bloqueante.
- V9 `ABONO_PRAZO`: pedido com abono feito depois de `End_Date__c - Abono_Deadline_Days_Before_Period_End__c`.
  Não bloqueante (aviso "O abono pedido fora do prazo depende de concordância da empresa.").
- V10 `PRAZO_CONCESSIVO`: o fim das férias passa do `Concession_Deadline__c`. Não bloqueante, aviso
  forte "Férias após o prazo concessivo são devidas em dobro (art. 137 da CLT).".
- V11 `SOBREPOSICAO`: datas sobrepostas a outro pedido do mesmo colaborador (qualquer período). Bloqueante.
- V12 `CONFLITO_EQUIPE`: outra pessoa com o mesmo gestor direto tem férias aprovadas ou pendentes no
  intervalo. Não bloqueante; texto em `Team_Conflict_Warning__c`.

**Fluxo**
- Criar como Rascunho; `LeaveRequestService.submit(id)` roda o motor, grava `Rule_Check_Result__c`
  (JSON) e, sem bloqueios, chama `ApprovalService.submit(id, 'Leave')`.
- `LeaveApprovalHandler.onApproved`: Status__c = Aprovado; notifica o colaborador
  (`HR_Request_Decided`). `onRejected`: Status__c = Rejeitado; notifica.
- `LeaveStatusBatch` (diário, mesmo agendamento do accrual): Aprovado com início hoje vira Em_Gozo e o
  colaborador vira Status__c = Ferias; Em_Gozo com fim antes de hoje vira Concluido e o colaborador volta a
  Ativo (se estava Ferias).
- Edição de datas só em Rascunho (trigger bloqueia nos demais status, exceto pelo serviço).

## Componentes

Apex: `LeaveRuleEngine`, `LeaveRuleResult`, `LeaveAccrualService`, `LeaveAccrualBatch`,
`LeaveStatusBatch`, `LeaveScheduler` (agenda os dois batches), `LeaveRequestService`,
`LeaveRequestSelector`, `LeaveAccrualPeriodSelector`, `LeaveRequestController`, `LeaveApprovalHandler`,
`LeaveRequestTriggerHandler` + `LeaveRequestTrigger`, `LeaveTeamCalendarController` + testes.

LWC:
- `leaveBalanceCard`: períodos do colaborador (atual ou do registro), saldo, prazo, status com cor.
- `leaveRequestForm`: início, dias, abono; botão "Verificar regras" mostra cada regra com ícone SLDS
  (ok, aviso, bloqueio) e mensagem; "Enviar para aprovação" só habilitado sem bloqueio.
- `leaveRequestList`: pedidos do colaborador com status e etapa atual; cancelar se Pendente.
- `leaveTeamCalendar`: grade mensal (linhas = pessoas da equipe direta, colunas = dias), feriados e
  descanso destacados, navegação de mês, legenda; dados de `LeaveTeamCalendarController`.
- FlexiPage de registro de Employee__c recebe os componentes na Fase 2 (myhr). Aqui só os componentes.

## Critérios de aceite

- [ ] `LeaveRuleEngineTest` com pelo menos um caso positivo e um negativo por regra V1 a V12, incluindo
      os cenários: 14+10+6 válido; 5+5+20 válido; 5+5+5 inválido (V7); 4 dias inválido (V6); início sexta
      com descanso domingo inválido (V4); véspera de feriado inválido (V4); abono de 11 dias em 30 inválido (V8).
- [ ] `LeaveAccrualServiceTest`: admissão há 3 anos gera 3 períodos; reexecutar não duplica; 10 faltas
      gera 24 dias; 33 faltas gera Perdido; lote de 200 colaboradores.
- [ ] Fluxo completo: colaborador envia, gestor aprova, RH aprova, status Aprovado, roll-ups e saldo
      corretos; rejeição pelo gestor encerra.
- [ ] Segurança (spec 02): colaborador não vê pedido de colega; gestor vê da equipe; colaborador não
      consegue mudar Status__c por DML direto.
- [ ] Jest para os 4 LWCs.
- [ ] Gates da spec 03.
