# Progresso da execução

Atualizado pelo orquestrador a cada marco. Quem retomar a sessão começa por aqui.

## Estado atual

- Fase: Onda 1 (leave, promotion, recruiting, performance) disparada
- Último passo concluído: Onda 0 (core) com gate cumprido nas 3 orgs
- Próximo passo: integrar cada agente da Onda 1 que terminar (Integração 1)

## Orgs

| Alias | Username | Criada em | Uso |
|---|---|---|---|
| rh-int | test-8kjx0xy2njvy@example.com | 26/10/2026 (expira 02/11) | integração |
| rh-w1 | test-5p5g4wqyhqno@example.com | 26/10/2026 (expira 02/11) | trabalho: leave, promotion, onboarding |
| rh-w2 | test-xfuy1c8uujoe@example.com | 26/10/2026 (expira 02/11) | trabalho: recruiting, performance, portal, analytics |

Nas três orgs o admin recebeu os PSG `HR_Admin` e `HR_Manager` e entrou no grupo `HR_Team`
(`scripts/apex/assign-admin-psg.apex`). Sem isso o admin não enxerga os campos (ver decisão 1).

## Ondas

| Onda | Módulo | Agente/branch | Status | Último commit | Observação |
|---|---|---|---|---|---|
| 0 | core | orquestrador / develop | concluída | ver git log develop | 43 testes Apex, cobertura 97%; 16 Jest; analyzer sem sev 1-2 |
| 1 | leave | feat/leave | em execução | | rh-w1 |
| 1 | promotion | feat/promotion | em execução | | rh-w1 |
| 1 | recruiting | feat/recruiting | em execução | | rh-w2 |
| 1 | performance | feat/performance | em execução | | rh-w2 |
| 2 | portal | feat/portal | pendente | | |
| 2 | onboarding | feat/onboarding | pendente | | |
| 2 | analytics | feat/analytics | pendente | | |
| 2 | myhr | feat/myhr | pendente | | |
| 3 | pacote, README, CI | develop | pendente | | |

## Linha do tempo

| Horário | Evento |
|---|---|
| 25/10 23:15 | Witor autorizou seguir sem pausas. Preparação confirmada: repo privado existe, develop no origin, orgs ativas. Licenças rh-int: Salesforce 1 livre, Salesforce Platform 3 livres (usar perfil Usuário de plataforma padrão). |
| 25/10 23:15 | Orquestrador (sessão local_21cc0677) registrou EM EXECUÇÃO no ClickUp 868mn2r18. |
| 25/10 23:20 | Modelo de dados completo (20 objetos, 5 CMDT, 18 PS, 4 PSG) gerado por script e implantado em rh-int sem erro. |
| 25/10 23:30 | Descoberta: campos sem FLS ficam invisíveis ao Apex anônimo e ao describe do próprio admin (decisão 1). |
| 25/10 23:41 | Apex do core verde em rh-int: 43 testes, 97% de cobertura, todas as classes acima de 85%. |
| 25/10 23:50 | LWCs coreOrgChart e coreApprovalInbox (16 Jest), app RH_Core, páginas Organograma e Aprovações. Analyzer sem violação sev 1-2. force-app implantado em rh-w1 e rh-w2. |
| 25/10 23:55 | Onda 1 disparada: 4 agentes em worktree (leave, promotion, recruiting, performance). |

## Divergências e decisões

- Trava de 30 min: o commit 8429dc5 tinha 4 min; o Witor mandou seguir mesmo assim (sessão de planejamento era a autora).
- Duas sessões de orquestração: a sessão "RH Core Salesforce orchestration" (local_32da5421) fez o commit 7a5b459
  às 23:14 e ficou ociosa. A sessão local_21cc0677 seguiu como orquestradora e avisou a outra para não agir em rh-core.
- **Decisão 1 (FLS e "campo que não materializa")**: campo implantado sem permission set fica sem FLS até para o
  admin, e o Apex anônimo e o describe só enxergam campos com FLS. Isso explica o "bug de materialização" das notas
  antigas. Todo campo novo precisa de fieldPermissions num PS atribuído a quem roda e testa.
- **Decisão 2 (Hierarchy_Path__c)**: a spec pedia Long Text(4000), que não é filtrável por LIKE em SOQL, e
  `EmployeeSelector.subtree` depende de LIKE. Virou Text(255): até 13 níveis de hierarquia. Acima disso o serviço
  recusa com "A hierarquia excede a profundidade máxima suportada.".
- **Decisão 3 (contexto de sistema extra)**: `EmployeeHierarchyService` lê campos estruturais (Id, Manager__c, User__c,
  Hierarchy_Path__c) em modo sistema, porque o colaborador não lê o registro do próprio gestor e o motor de aprovação
  precisa resolver o aprovador. `OrgChartController` lê em modo sistema só nome, cargo e departamento do gestor
  direto para o cartão do organograma. Ambos comentados no código.
- **Decisão 4 (ApprovalStepSelector)**: em vez de USER_MODE usa `with sharing` + `Security.stripInaccessible`, porque
  o campo de pesquisa Promotion_Request__c fica invisível para quem não lê o objeto de promoção e derrubava a consulta
  inteira em USER_MODE.
- **Decisão 5 (etapa pulada)**: etapa com aprovador indisponível ou igual ao solicitante é gravada como Aprovado com
  o comentário "Etapa pulada: aprovador indisponível". Se todas forem puladas, o pedido é aprovado na hora.
- **Decisão 6 (registros de CMDT dos módulos)**: a Fase 0 já criou os registros de `Recruiting_Stage__mdt` (8 etapas,
  transições da spec 13) e de `Onboarding_Task_Template__mdt` (8 modelos da spec 15) nas pastas dos donos.
- **Decisão 7 (usuários de teste)**: `HrTestDataFactory.orgTree()` cria exatamente 4 usuários (gestor 1, colaboradores
  1 e 2, RH), o limite de licenças por transação. O CEO, o gestor 2 e os colaboradores 3 e 4 não têm usuário. Testes
  que precisam de usuário sem permission set ficam em classe própria (ex.: `EmployeeNoAccessTest`).
- **Decisão 8 (bypass nos testes do core)**: os testes do core que usam Leave_Request__c e Promotion_Request__c como
  veículo chamam `TriggerHandler.bypass('LeaveRequestTriggerHandler')`, `'LeaveAccrualPeriodTriggerHandler'` e
  `'PromotionRequestTriggerHandler'`. Os módulos devem usar exatamente esses nomes de handler.

## Pedidos ao core

## Pendências para o Witor

- Avaliar se quer abrir o repositório ao público (hoje privado, como autorizado).
