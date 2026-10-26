# 02. Segurança e acesso

Esta é a parte que mais demonstra competência no projeto. Nada aqui é opcional.

## Princípios

1. Dado de pessoa é privado por padrão. Ninguém vê colega por acaso.
2. Acesso vem de três fontes, nesta ordem: o próprio registro (colaborador), a cadeia de gestores
   (Apex Managed Sharing) e o RH (View All por permission set).
3. Salário e faixa salarial (**[S]** na spec 01) só aparecem para os permission sets de RH. FLS, não
   esconder só na tela.
4. Leitura sempre `WITH USER_MODE` ou `Security.stripInaccessible`. Escrita `as user`, exceto os pontos
   listados em "Contexto de sistema permitido".
5. Mudança de status de solicitações só pelo serviço. O campo Status__c é somente leitura por FLS para
   colaborador e gestor; o serviço grava em contexto de sistema depois de validar quem pode decidir.

## Permission sets (criados na Fase 0, um por módulo e persona)

Cada arquivo fica na pasta do módulo dono. A Fase 0 cria todos com permissões de objeto e campo desta
matriz. O agente do módulo só acrescenta `classAccesses`, `tabSettings`, `customPermissions` e
`pageAccesses` no próprio arquivo.

| Permission set | Pasta | Objetos (C=create R=read E=edit D=delete VA=view all MA=modify all) |
|---|---|---|
| HR_Core_Employee | core | Employee__c R; Department__c R; Job_Position__c R; HR_Holiday__c R; Approval_Step__c R |
| HR_Core_Manager | core | igual Employee (o acesso à equipe vem do sharing) |
| HR_Core_Admin | core | Employee__c CREDVA MA; Department__c CRED; Job_Position__c CRED; Salary_Band__c CRED VA; HR_Holiday__c CRED; Approval_Step__c R VA; todos os campos [S] R/E |
| HR_Leave_Employee | leave | Leave_Accrual_Period__c R; Leave_Request__c CRE (Status__c, Current_Step__c, Rule_Check_Result__c somente leitura) |
| HR_Leave_Manager | leave | igual Employee |
| HR_Leave_Admin | leave | Leave_Accrual_Period__c CRED VA MA; Leave_Request__c CRED VA MA |
| HR_Promotion_Manager | promotion | Promotion_Request__c CRE (sem campos [S]; Status__c somente leitura); Position_History__c R (sem Salary__c) |
| HR_Promotion_Admin | promotion | Promotion_Request__c CRED VA MA com [S]; Position_History__c CRED VA com [S] |
| HR_Position_History_Employee | promotion | Position_History__c R (sem Salary__c) |
| HR_Recruiting_Recruiter | recruiting | Job_Opening__c CRED; Candidate__c CRED VA MA; Job_Application__c CRED VA MA; Application_Stage_History__c R |
| HR_Recruiting_Hiring_Manager | recruiting | Job_Opening__c R; Candidate__c R; Job_Application__c RE (Stage__c editável só via LWC/serviço); Application_Stage_History__c R |
| HR_Performance_Employee | performance | Review_Cycle__c R; Goal__c CRE; Self_Assessment__c CRE; Performance_Review__c R (sem Calibrated_Rating__c) |
| HR_Performance_Manager | performance | igual Employee + Performance_Review__c RE (sem Calibrated_Rating__c) |
| HR_Performance_Admin | performance | todos CRED VA MA, com Calibrated_Rating__c |
| HR_Onboarding_Employee | onboarding | Onboarding_Plan__c R; Onboarding_Task__c RE |
| HR_Onboarding_Admin | onboarding | Onboarding_Plan__c CRED VA MA; Onboarding_Task__c CRED VA MA |
| HR_MyHR_User | myhr | acesso ao app Meu RH e às classes do módulo |
| HR_Portal_Guest | portal | só classAccesses do controller do portal (atribuído ao perfil guest do site, fora do pacote) |

Permission Set Groups (pasta core, criados na Fase 0, referenciando todos os PS acima):
- `HR_Employee`: Core_Employee, Leave_Employee, Position_History_Employee, Performance_Employee,
  Onboarding_Employee, MyHR_User.
- `HR_Manager`: HR_Employee + Core_Manager, Leave_Manager, Promotion_Manager, Performance_Manager,
  Recruiting_Hiring_Manager.
- `HR_Admin`: todos os Admin + Recruiting_Recruiter + MyHR_User.
- `HR_Recruiter`: Core_Employee, Recruiting_Recruiter, MyHR_User.

## Compartilhamento

### Employee__c (Fase 0, `EmployeeSharingService`)
- Ao inserir ou mudar `User__c`: compartilhamento Read para o próprio usuário (motivo `Self__c`).
- Ao inserir ou mudar `Manager__c`: recalcular `Hierarchy_Path__c` e `Hierarchy_Depth__c` do colaborador
  e de toda a subárvore; compartilhamento Read para cada usuário da cadeia de gestores (motivo
  `Manager_Chain__c`), removendo os antigos.
- Subárvore com mais de 200 colaboradores: processar em Queueable encadeado.
- `EmployeeSharingRecalcBatch` implementa `Database.Batchable` e serve como classe de recálculo de
  sharing do objeto (botão Recalculate).
- Filhos master-detail (períodos, solicitações de férias, histórico de cargo, metas, autoavaliações,
  planos de onboarding) herdam esse acesso automaticamente.

### Approval_Step__c (Fase 0)
Read para o aprovador (`Approver__c`) ou para o grupo `HR_Team`, motivo `Approver__c`.

### Promotion_Request__c (Fase 1, promotion)
O dono é quem solicitou. Read para o gestor de segundo nível do colaborador (aprovador) e para o grupo
HR_Team, motivo `Approver_Chain__c`. O colaborador **não** tem acesso à solicitação. Depois de efetivada,
ele vê só o Position_History__c.

### Job_Application__c e Candidate__c (Fase 1, recruiting)
Owner = fila `HR_Recruiting_Queue`. Read/Edit no Job_Application__c e Read no Candidate__c para o usuário do
`Hiring_Manager__c` da vaga, motivo `Hiring_Manager__c`. Recalcular quando o gestor da vaga mudar.

### Performance_Review__c (Fase 1, performance)
Read/Edit para o gestor direto (Reviewer__c), Read para o restante da cadeia (`Manager_Chain__c`). Read
para o próprio colaborador **só depois** de Status__c = Liberada (`Employee_Release__c`).

## Contexto de sistema permitido (sempre com comentário no código)

| Onde | Por quê |
|---|---|
| `EmployeeSharingService`, `EmployeeSharingRecalcBatch` | Criar e remover share de qualquer colaborador |
| `ApprovalService.decide` (atualização de status) | O aprovador não tem Edit no Status__c; o serviço valida antes que ele é o aprovador da etapa |
| `LeaveAccrualService` e `LeaveAccrualBatch` | Gerar períodos aquisitivos para todos os colaboradores |
| `PromotionService` (snapshot de salário e efetivação) | O gestor não lê salário, mas o snapshot precisa existir |
| `JobPortalController` (portal, usuário convidado) | Guest não tem acesso a dados; o controller devolve DTO com campos permitidos e cria candidato e candidatura com validação |
| `CandidateRetentionBatch` | Anonimizar candidatos vencidos (LGPD) |
| `OnboardingService.createFromApplication` | Criar colaborador e plano a partir da candidatura contratada |
| `ReviewCycleService.launch` | Criar avaliações para todos os colaboradores ativos |

## Testes de segurança obrigatórios (em todos os módulos)

Para cada serviço que lê dado de pessoa, pelo menos:
1. Colaborador A não vê dado do colaborador B (mesmo nível, sem relação de gestão).
2. Gestor vê subordinado direto e indireto.
3. Gestor não vê colaborador de outra equipe.
4. Usuário sem o permission set recebe exceção ou lista vazia, nunca dado.
5. Gestor (sem PS de RH) não lê campo [S]: o valor volta nulo via `stripInaccessible` ou a consulta falha.

Use `System.runAs` com usuários criados pelo `HrTestDataFactory` (spec 03).
