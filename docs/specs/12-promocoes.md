# 12. Fase 1: Promoções e histórico de cargo (promotion)

Pasta: `force-app/promotion`. Depende da Fase 0. Branch: `feat/promotion`.

## Histórias

1. Como gestor, solicito a promoção de alguém da minha equipe (direta ou indireta), escolhendo o novo
   cargo, a data de efetivação e a justificativa. Não vejo nem informo salário.
2. Como gestor do gestor, aprovo ou rejeito a solicitação.
3. Como RH, informo o novo salário (validado contra a faixa do cargo), dou a aprovação final e a promoção
   é efetivada na data.
4. Como colaborador, vejo meu histórico de cargos (sem valores de salário).

## Regras

- P1. Só pode solicitar quem está na cadeia de gestores do colaborador
  (`EmployeeHierarchyService.isInChainOf`). Senão: "Você só pode solicitar promoção para alguém da sua equipe."
- P2. Novo cargo diferente do atual e ativo. Aviso não bloqueante se não for o `Next_Position__c` do cargo
  atual ("Promoção fora da trilha prevista.").
- P3. Effective_Date__c não pode ser no passado.
- P4. Um colaborador não pode ter duas solicitações Pendente ao mesmo tempo.
- P5. Na criação, o serviço grava em contexto de sistema o snapshot `Current_Position__c` e
  `Current_Salary__c`.
- P6. Etapa do RH: antes de aprovar, o RH precisa preencher `Proposed_Salary__c`. Se estiver fora da
  faixa (`Salary_Band__c` do novo cargo), exige comentário de justificativa na decisão (validado no
  `PromotionService.hrApprove`, que chama `ApprovalService.decide`).
- P7. Aprovado: Status__c = Aprovado. Se Effective_Date__c <= hoje, efetivar na hora; senão
  `PromotionEffectivationBatch` (diário) efetiva na data.
- P8. Efetivar: atualiza `Position__c` e `Salary__c` do colaborador, fecha o `Position_History__c` aberto
  (End_Date__c = data - 1) e cria um novo com Change_Reason__c = Promocao; Status__c = Efetivado; notifica
  colaborador e gestor.
- P9. O histórico inicial (Change_Reason__c = Admissao) é criado por
  `PositionHistoryService.createAdmission(Set<Id> employeeIds)`, chamado pelo seed (spec 18) e pela
  admissão (spec 15). Não alterar a trigger do core para isso.
- Compartilhamento da solicitação conforme spec 02 (`PromotionSharingService`).

## Componentes

Apex: `PromotionService`, `PromotionRequestSelector`, `PromotionRequestController`,
`PromotionApprovalHandler`, `PromotionSharingService`, `PromotionEffectivationBatch` (+ Schedulable),
`PositionHistoryService`, `PositionHistorySelector`, `PromotionRequestTriggerHandler` + trigger, testes.

LWC:
- `promotionRequestForm`: seleção de colaborador da equipe (lista vinda do controller), cargo proposto
  (com destaque para o próximo da trilha), data, justificativa; aviso de P2.
- `promotionHrReview`: para o RH, mostra solicitação, faixa do cargo, salário atual e campo de salário
  proposto com percentual de aumento calculado e indicador dentro/fora da faixa; aprovar/rejeitar.
- `positionHistoryTimeline`: linha do tempo do colaborador (cargo, departamento, data, motivo). Salário só
  aparece se o usuário tiver acesso ao campo (`stripInaccessible`).

## Critérios de aceite

- [ ] Fluxo: gestor solicita, gestor do gestor aprova, RH informa salário e aprova, efetivação imediata
      e agendada; histórico fechado e aberto corretamente.
- [ ] P1, P3, P4, P6 com testes negativos.
- [ ] Segurança: o colaborador não lê a solicitação; o gestor solicitante não lê Current_Salary__c nem
      Proposed_Salary__c; outro gestor fora da cadeia não vê a solicitação.
- [ ] Lote: efetivação de 200 promoções no batch.
- [ ] Jest para os 3 LWCs. Gates da spec 03.
