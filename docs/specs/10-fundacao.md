# 10. Fase 0: Fundação (core)

Executor: orquestrador (ou um único agente "core"). Nada da Fase 1 começa antes deste gate.

## Entregas

1. Projeto SFDX (spec 03), `package.json` com `@salesforce/sfdx-lwc-jest`, eslint e prettier padrão do
   template `sf project generate`, `.gitignore`, `.forceignore`.
2. **Modelo de dados completo da spec 01**, em todas as pastas de módulo, com objetos, campos,
   validações, roll-ups, fórmulas, Custom Metadata (tipos e registros), sharing reasons, grupo, fila e
   notification types.
3. **Todos os permission sets e permission set groups da spec 02**, com permissões de objeto e campo.
4. Classes compartilhadas da spec 03: `HrSettings`, `HrDateUtils`, `EmployeeSelector`,
   `EmployeeHierarchyService`, `EmployeeSharingService`, `EmployeeSharingRecalcBatch`,
   `EmployeeTriggerHandler` + `EmployeeTrigger`, `TriggerHandler`, `ApprovalService`,
   `ApprovalOutcomeHandler`, `ApprovalStepSelector`, `ApprovalController`, `HrNotificationService`,
   `HrTestDataFactory`, `DepartmentSelector`, `JobPositionSelector`, `HolidaySelector`.
5. **Organograma** LWC `coreOrgChart` + `OrgChartController`.
6. LWC `coreApprovalInbox` (caixa de aprovações pendentes do usuário) + `ApprovalController`.
7. Tabs para todos os objetos (pastas dos donos) e app Lightning `RH_Core` (RH) com as tabs do core. O app
   `Meu_RH` é criado na Fase 2 (spec 17).
8. Deploy inteiro em INT, WORK1 e WORK2 (spec 90), testes do core passando.

## Regras do core

**Hierarquia**
- Ao inserir colaborador ou mudar `Manager__c`: proibir ciclo (A gestor de B e B gestor de A, em
  qualquer profundidade) com erro "O gestor escolhido está abaixo deste colaborador na hierarquia.";
  recalcular `Hierarchy_Path__c`, `Hierarchy_Depth__c` do colaborador e da subárvore; atualizar
  `Direct_Reports_Count__c` do gestor antigo e do novo.
- `User__c` não pode estar em dois colaboradores (erro "Este usuário já está vinculado a outro colaborador.").
- Bulk: 200 colaboradores inseridos de uma vez, com hierarquia entre eles no mesmo lote, deve funcionar.
  Dica: processar em ordem de profundidade dentro do lote.

**Motor de aprovação (`ApprovalService`)**
- `submit`: lê `HR_Approval_Step__mdt` ativos do tipo, em ordem; resolve o aprovador da etapa 1
  (Direct_Manager = `Manager__r.User__c`; Second_Level_Manager = gestor do gestor, ou o gestor direto se
  não houver; HR_Team = grupo); cria `Approval_Step__c` Pendente com share; muda o Status__c do pedido para
  Pendente e Current_Step__c = 1; notifica o aprovador (`HR_Approval_Pending`).
- Se o aprovador resolvido for o próprio solicitante ou estiver vazio, pular para a próxima etapa e
  registrar o motivo em Comments__c ("Etapa pulada: aprovador indisponível").
- `decide`: valida que o usuário atual é o aprovador da etapa (ou membro do HR_Team quando a etapa for do
  grupo); senão lança `ApprovalService.ApprovalException("Você não é o aprovador desta etapa.")`.
  Aprovado: avança para a próxima etapa ou, se era a última, Status__c = Aprovado e chama
  `Outcome_Handler__c.onApproved`. Rejeitado: Status__c = Rejeitado, encerra as demais etapas e chama
  `onRejected`. Comentário obrigatório na rejeição.
- `cancel`: só o solicitante, só com Status__c Pendente; etapas pendentes viram Cancelado.
- O handler é resolvido com `Type.forName`. Os handlers concretos (`LeaveApprovalHandler`,
  `PromotionApprovalHandler`) são criados pelos módulos. Para o core compilar e testar sozinho, crie no
  core um `NoopApprovalHandler` usado nos testes e trate handler inexistente com erro claro.

**Organograma (`coreOrgChart`)**
- Mostra a partir do colaborador do usuário atual: gestor (um nível acima), ele, e os subordinados
  diretos; cada cartão expande para carregar o próximo nível sob demanda (`OrgChartController.children`).
- Busca por nome entre os colaboradores visíveis ao usuário (USER_MODE garante o filtro).
- Cartão: iniciais, nome, cargo, departamento, número de subordinados. Sem salário.
- RH vê a árvore a partir da raiz (colaborador sem gestor).
- Acessível: navegação por teclado, `aria-expanded`, foco visível.
- Funciona em Lightning App Page, Home e Record Page do colaborador.

## Critérios de aceite

- [ ] Deploy de `force-app` inteiro sem erro em scratch org limpa.
- [ ] Testes de `EmployeeSharingService` cobrem: novo colaborador, troca de gestor (shares antigos
      removidos), subárvore de 3 níveis, ciclo proibido, lote de 200.
- [ ] Testes de segurança da spec 02 (itens 1 a 5) para `EmployeeSelector` e `OrgChartController`.
- [ ] `ApprovalService` testado com o fluxo de 2 etapas, rejeição, cancelamento, aprovador errado e etapa
      pulada.
- [ ] Jest para `coreOrgChart` (carregar, expandir, busca, erro) e `coreApprovalInbox`.
- [ ] Gates da spec 03.
