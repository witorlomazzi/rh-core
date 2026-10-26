# 01. Modelo de dados (completo, criado na Fase 0)

Regras gerais:
- API em inglês, rótulos em português do Brasil. Descrição em cada objeto e campo (até 255 caracteres).
- Todo objeto: `enableHistory` ligado para campos marcados com (H), `enableReports` true,
  `enableActivities` false, `enableSearch` true quando for de pessoa, `deploymentStatus` Deployed.
- `Name`: Text quando indicado, AutoNumber quando indicado (formato entre colchetes).
- Picklists: valores com API name sem acento e rótulo em português. Restritos (`restricted` true).
- Moeda: Currency(16,2). Percentual: Percent(5,2). Número de dias: Number(4,0).
- Campos salariais estão marcados com **[S]**: FLS somente para os permission sets de RH (spec 02).
- OWD indicado em cada objeto (`sharingModel` e `externalSharingModel` = Private quando houver).
- Pastas: cada objeto fica na pasta do módulo dono (coluna Dono). A Fase 0 cria todos os objetos e campos
  nas pastas dos donos; os agentes de módulo só alteram objetos que possuem.

Atenção a dependências: lookups entre módulos são criados na Fase 0 junto com tudo, por isso não há
deploy parcial que falhe por referência inexistente. Deploy da Fase 0 é de `force-app` inteiro.

---

## Módulo core (Dono: `force-app/core`)

### Department__c (Departamento). OWD: Public Read Only
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | Text(80) | Nome do departamento |
| Code__c | Text(20) | Único, External Id, obrigatório |
| Parent_Department__c | Lookup(Department__c) | Departamento pai |
| Head__c | Lookup(Employee__c) | Responsável |
| Cost_Center__c | Text(20) | |
| Active__c | Checkbox | Padrão true |

### Salary_Band__c (Faixa salarial). OWD: Private
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | Text(80) | Ex.: "Faixa P3" |
| Min_Salary__c | Currency **[S]** | obrigatório |
| Mid_Salary__c | Currency **[S]** | |
| Max_Salary__c | Currency **[S]** | obrigatório; validação Max >= Min |

### Job_Position__c (Cargo). OWD: Public Read Only
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | Text(80) | Ex.: "Analista de Vendas Pleno" |
| Code__c | Text(20) | Único, External Id |
| Level__c | Picklist | Estagio, Junior, Pleno, Senior, Especialista, Coordenacao, Gerencia, Diretoria |
| Career_Track__c | Picklist | Tecnica, Gestao |
| Salary_Band__c | Lookup(Salary_Band__c) | |
| Next_Position__c | Lookup(Job_Position__c) | Próximo passo natural da trilha |
| Active__c | Checkbox | Padrão true |

### Employee__c (Colaborador). OWD: Private
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | Text(120) | Nome completo |
| Employee_Number__c | Text(20) | Matrícula. Único, External Id, obrigatório |
| User__c | Lookup(User) | Usuário Salesforce do colaborador. Único (validado em Apex) |
| Email__c | Email | |
| Department__c | Lookup(Department__c) | (H) |
| Position__c | Lookup(Job_Position__c) | (H) |
| Manager__c | Lookup(Employee__c) | Gestor direto (H) |
| Manager_User_Id__c | Formula(Text) | `Manager__r.User__c` |
| Hire_Date__c | Date | obrigatório |
| Termination_Date__c | Date | |
| Status__c | Picklist | Pre_Admissao, Ativo, Ferias, Afastado, Desligado. Padrão Ativo (H) |
| Employment_Type__c | Picklist | CLT, Estagio, PJ. Padrão CLT |
| Salary__c | Currency **[S]** | (H) |
| Work_Location__c | Text(40) | Código da localidade para feriados (ex.: "SP-SAO_PAULO") |
| Direct_Reports_Count__c | Number(5,0) | Mantido por Apex |
| Hierarchy_Path__c | Long Text(4000) | Ids da cadeia de gestores, da raiz até o gestor direto, separados por ";". Mantido por Apex |
| Hierarchy_Depth__c | Number(3,0) | Mantido por Apex. Raiz = 0 |

Validações: gestor não pode ser o próprio colaborador; ciclo de hierarquia proibido (Apex);
Termination_Date__c >= Hire_Date__c.

### HR_Holiday__c (Feriado). OWD: Public Read Only
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | Text(80) | Ex.: "Proclamação da República" |
| Date__c | Date | obrigatório |
| Location__c | Text(40) | Vazio = vale para todas as localidades |
| Type__c | Picklist | Nacional, Estadual, Municipal, Empresa |
| Unique_Key__c | Text(80) | Único, External Id: `yyyy-MM-dd|Location` |

### Approval_Step__c (Etapa de aprovação). OWD: Private
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | AutoNumber | `AP-{000000}` |
| Request_Type__c | Picklist | Leave, Promotion |
| Leave_Request__c | Lookup(Leave_Request__c) | |
| Promotion_Request__c | Lookup(Promotion_Request__c) | |
| Step_Order__c | Number(2,0) | |
| Approver_Type__c | Picklist | Direct_Manager, Second_Level_Manager, HR_Team |
| Approver__c | Lookup(User) | Vazio quando Approver_Type__c = HR_Team |
| Status__c | Picklist | Pendente, Aprovado, Rejeitado, Cancelado |
| Decided_By__c | Lookup(User) | |
| Decision_Date__c | DateTime | |
| Comments__c | Long Text(4000) | |

### Custom Metadata (core)

**HR_Setting__mdt** (registro único `Default`)
| Campo | Tipo | Valor padrão do registro |
|---|---|---|
| Weekly_Rest_Days__c | Text(40) | `SUN` (lista separada por ";": MON..SUN) |
| Leave_Min_Notice_Days__c | Number | 30 |
| Leave_Max_Splits__c | Number | 3 |
| Leave_Min_Main_Period_Days__c | Number | 14 |
| Leave_Min_Other_Period_Days__c | Number | 5 |
| Leave_Block_Days_Before_Rest__c | Number | 2 |
| Leave_Max_Sold_Days_Divisor__c | Number | 3 (abono máximo = floor(dias de direito / 3)) |
| Abono_Deadline_Days_Before_Period_End__c | Number | 15 |
| Accrual_Period_Months__c | Number | 12 |
| Concession_Warning_Days__c | Number | 60 |
| Candidate_Retention_Days__c | Number | 180 |
| Portal_Min_Submit_Seconds__c | Number | 3 |
| Portal_Daily_Limit_Per_Email__c | Number | 3 |
| Consent_Text_Version__c | Text(20) | `2026-10` |
| HR_Group_Developer_Name__c | Text(80) | `HR_Team` |
| Recruiting_Queue_Developer_Name__c | Text(80) | `HR_Recruiting_Queue` |

**HR_Approval_Step__mdt**: Request_Type__c (Text: Leave/Promotion), Step_Order__c (Number),
Approver_Type__c (Text), Outcome_Handler__c (Text: classe Apex chamada ao final), Active__c (Checkbox).
Registros: `Leave_1` (Leave, 1, Direct_Manager, LeaveApprovalHandler), `Leave_2` (Leave, 2, HR_Team,
LeaveApprovalHandler), `Promotion_1` (Promotion, 1, Second_Level_Manager, PromotionApprovalHandler),
`Promotion_2` (Promotion, 2, HR_Team, PromotionApprovalHandler).

**HR_Absence_Rule__mdt** (tabela do art. 130 da CLT): Min_Absences__c, Max_Absences__c, Leave_Days__c.
Registros: `Ate_5` (0, 5, 30), `De_6_a_14` (6, 14, 24), `De_15_a_23` (15, 23, 18), `De_24_a_32`
(24, 32, 12). Acima de 32: perde o direito ao período (sem registro; o serviço trata).

### Outros metadados core
- Public Group `HR_Team` (RH). Queue `HR_Recruiting_Queue` (objetos Candidate__c e Job_Application__c).
- Custom Notification Type `HR_Approval_Pending` e `HR_Request_Decided`.
- Apex Sharing Reasons em Employee__c: `Self__c` ("Próprio colaborador"), `Manager_Chain__c` ("Cadeia de gestores").
- Apex Sharing Reasons em Approval_Step__c: `Approver__c`.
- Custom Permission `HR_Admin_Access` ("Acesso de RH"), incluída em todos os permission sets `*_Admin`.

---

## Módulo leave (Dono: `force-app/leave`)

### Leave_Accrual_Period__c (Período aquisitivo). Controlado pelo pai
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | AutoNumber | `PA-{000000}` |
| Employee__c | Master-Detail(Employee__c) | `writeRequiresMasterRead` false |
| Start_Date__c | Date | obrigatório |
| End_Date__c | Date | obrigatório |
| Concession_Deadline__c | Date | Fim do período concessivo (End + 12 meses). Mantido por Apex |
| Unjustified_Absences__c | Number(3,0) | Faltas injustificadas, padrão 0 |
| Entitled_Days__c | Number(4,0) | Dias de direito pela tabela do art. 130. Mantido por Apex |
| Days_Taken__c | Roll-Up SUM(Leave_Request__c.Days__c) | filtro Status__c em Aprovado, Em_Gozo, Concluido |
| Days_Sold__c | Roll-Up SUM(Leave_Request__c.Sold_Days__c) | mesmo filtro |
| Days_Pending__c | Roll-Up SUM(Leave_Request__c.Days__c) | filtro Status__c = Pendente |
| Balance_Days__c | Formula(Number) | Entitled - Taken - Sold - Pending |
| Status__c | Picklist | Em_Aquisicao, Disponivel, Prazo_Proximo, Concluido, Perdido |
| Unique_Key__c | Text(60) | Único, External Id: `EmployeeNumber|yyyy-MM-dd` |

### Leave_Request__c (Solicitação de férias). Controlado pelo pai
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | AutoNumber | `FE-{000000}` |
| Accrual_Period__c | Master-Detail(Leave_Accrual_Period__c) | `writeRequiresMasterRead` true |
| Employee__c | Lookup(Employee__c) | Preenchido por Apex a partir do período |
| Start_Date__c | Date | obrigatório |
| Days__c | Number(3,0) | Dias de gozo, obrigatório |
| End_Date__c | Formula(Date) | `Start_Date__c + Days__c - 1` |
| Sold_Days__c | Number(3,0) | Abono pecuniário, padrão 0 |
| Status__c | Picklist | Rascunho, Pendente, Aprovado, Rejeitado, Cancelado, Em_Gozo, Concluido (H) |
| Current_Step__c | Number(2,0) | |
| Requested_By__c | Lookup(User) | |
| Notes__c | Text Area(255) | |
| Rule_Check_Result__c | Long Text(4000) | JSON do último resultado do motor de regras |
| Team_Conflict_Warning__c | Text Area(255) | Aviso não bloqueante |

---

## Módulo promotion (Dono: `force-app/promotion`)

### Promotion_Request__c (Solicitação de promoção). OWD: Private
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | AutoNumber | `PR-{000000}` |
| Employee__c | Lookup(Employee__c) | obrigatório |
| Current_Position__c | Lookup(Job_Position__c) | Snapshot na criação |
| Proposed_Position__c | Lookup(Job_Position__c) | obrigatório |
| Current_Salary__c | Currency **[S]** | Snapshot na criação (Apex em sistema) |
| Proposed_Salary__c | Currency **[S]** | Preenchido pelo RH |
| Increase_Percent__c | Formula(Percent) **[S]** | |
| Justification__c | Long Text(4000) | obrigatório |
| Effective_Date__c | Date | obrigatório |
| Status__c | Picklist | Rascunho, Pendente, Aprovado, Rejeitado, Cancelado, Efetivado (H) |
| Current_Step__c | Number(2,0) | |
| Requested_By__c | Lookup(User) | |
Apex Sharing Reason: `Approver_Chain__c`.

### Position_History__c (Histórico de cargo). Controlado pelo pai
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | AutoNumber | `HC-{000000}` |
| Employee__c | Master-Detail(Employee__c) | |
| Position__c | Lookup(Job_Position__c) | |
| Department__c | Lookup(Department__c) | |
| Start_Date__c | Date | |
| End_Date__c | Date | |
| Salary__c | Currency **[S]** | |
| Change_Reason__c | Picklist | Admissao, Promocao, Merito, Transferencia |
| Promotion_Request__c | Lookup(Promotion_Request__c) | |

---

## Módulo recruiting (Dono: `force-app/recruiting`)

### Job_Opening__c (Vaga). OWD: Public Read Only
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | Text(120) | Título da vaga |
| Position__c | Lookup(Job_Position__c) | |
| Department__c | Lookup(Department__c) | |
| Hiring_Manager__c | Lookup(Employee__c) | |
| Recruiter__c | Lookup(User) | |
| Status__c | Picklist | Rascunho, Aberta, Pausada, Fechada, Cancelada |
| Publish_On_Portal__c | Checkbox | |
| Public_Slug__c | Text(80) | Único. Gerado por Apex a partir do título |
| Location__c | Text(80) | |
| Work_Model__c | Picklist | Presencial, Hibrido, Remoto |
| Employment_Type__c | Picklist | CLT, Estagio, PJ |
| Description__c | Rich Text(32000) | |
| Requirements__c | Rich Text(32000) | |
| Openings_Count__c | Number(3,0) | Padrão 1 |
| Opened_Date__c | Date | |
| Closed_Date__c | Date | |
| Applications_Count__c | Number(5,0) | Mantido por Apex (não é master-detail) |

### Candidate__c (Candidato). OWD: Private
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | Text(120) | |
| Email__c | Email | obrigatório |
| Email_Normalized__c | Text(120) | Único, External Id. Minúsculo e sem espaços |
| Phone__c | Phone | |
| LinkedIn_URL__c | URL | |
| City__c | Text(80) | |
| Source__c | Picklist | Portal, Indicacao, LinkedIn, Outro |
| Consent_Given__c | Checkbox | LGPD |
| Consent_Date__c | DateTime | |
| Consent_Text_Version__c | Text(20) | |
| Anonymized__c | Checkbox | |
| Anonymized_Date__c | DateTime | |
| Last_Activity_Date__c | Date | |
Apex Sharing Reason: `Hiring_Manager__c`.

### Job_Application__c (Candidatura). OWD: Private
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | AutoNumber | `CA-{000000}` |
| Candidate__c | Lookup(Candidate__c) | obrigatório |
| Job_Opening__c | Lookup(Job_Opening__c) | obrigatório |
| Stage__c | Picklist | Nova, Triagem, Entrevista_RH, Entrevista_Tecnica, Proposta, Contratado, Reprovado, Desistiu (H) |
| Stage_Entered_Date__c | DateTime | |
| Rejection_Reason__c | Picklist | Perfil, Salario, Localizacao, Desistencia, Outro |
| Score__c | Number(1,0) | 0 a 5 |
| Source__c | Picklist | igual ao Candidate__c |
| Cover_Letter__c | Long Text(5000) | |
| Unique_Key__c | Text(40) | Único, External Id: `CandidateId|OpeningId` |
| Employee__c | Lookup(Employee__c) | Preenchido na admissão |
Apex Sharing Reason: `Hiring_Manager__c`.

### Application_Stage_History__c. Controlado pelo pai
| Campo | Tipo | Detalhe |
|---|---|---|
| Name | AutoNumber | `EH-{000000}` |
| Job_Application__c | Master-Detail(Job_Application__c) | |
| From_Stage__c | Text(40) | |
| To_Stage__c | Text(40) | |
| Changed_By__c | Lookup(User) | |
| Changed_At__c | DateTime | |
| Days_In_Previous_Stage__c | Number(5,1) | |

### Recruiting_Stage__mdt
Stage_Value__c (Text), Order__c (Number), Is_Terminal__c (Checkbox), Allowed_Next_Stages__c (Text 255,
";"), Requires_Score__c (Checkbox), Requires_Rejection_Reason__c (Checkbox), Color__c (Text 20).
Registros para cada valor de Stage__c (spec 13 define as transições).

---

## Módulo performance (Dono: `force-app/performance`)

### Review_Cycle__c (Ciclo de avaliação). OWD: Public Read Only
Name Text(80); Start_Date__c, End_Date__c, Self_Review_Due__c, Manager_Review_Due__c (Date);
Status__c Picklist (Planejado, Autoavaliacao, Avaliacao_Gestor, Calibracao, Concluido);
Rating_Scale_Max__c Number(1,0) padrão 5.

### Goal__c (Meta). Controlado pelo pai
Name Text(120); Employee__c Master-Detail(Employee__c) `writeRequiresMasterRead` true;
Review_Cycle__c Lookup; Description__c Long Text(2000); Weight__c Percent; Target__c Text(255);
Self_Score__c Number(1,0); Status__c Picklist (Ativa, Concluida, Cancelada).

### Self_Assessment__c (Autoavaliação). Controlado pelo pai
Name AutoNumber `AA-{000000}`; Employee__c Master-Detail(Employee__c) `writeRequiresMasterRead` true;
Review_Cycle__c Lookup; Self_Rating__c Number(1,0); Strengths__c, Improvements__c Long Text(4000);
Submitted__c Checkbox; Submitted_Date__c DateTime; Unique_Key__c Text(40) único (`EmployeeId|CycleId`).

### Performance_Review__c (Avaliação do gestor). OWD: Private
Name AutoNumber `AV-{000000}`; Review_Cycle__c Lookup; Employee__c Lookup(Employee__c);
Reviewer__c Lookup(User); Manager_Rating__c Number(1,0); Manager_Comments__c Long Text(4000);
Calibrated_Rating__c Number(1,0) **[S]**; Status__c Picklist (Pendente, Em_Andamento, Enviada, Calibrada,
Liberada); Released_Date__c DateTime; Unique_Key__c Text(40) único (`EmployeeId|CycleId`).
Apex Sharing Reasons: `Manager_Chain__c`, `Employee_Release__c`.

---

## Módulo onboarding (Dono: `force-app/onboarding`)

### Onboarding_Plan__c (Plano de onboarding). Controlado pelo pai
Name AutoNumber `ON-{000000}`; Employee__c Master-Detail(Employee__c); Job_Application__c Lookup;
Start_Date__c Date; Status__c Picklist (Nao_Iniciado, Em_Andamento, Concluido);
Total_Tasks__c Roll-Up COUNT(Onboarding_Task__c); Completed_Tasks__c Roll-Up COUNT filtro
Status__c = Concluida; Progress_Percent__c Formula(Percent) com proteção para divisão por zero.

### Onboarding_Task__c (Tarefa de onboarding). Controlado pelo pai
Name Text(120); Plan__c Master-Detail(Onboarding_Plan__c) `writeRequiresMasterRead` true;
Description__c Long Text(2000); Owner_Role__c Picklist (RH, Gestor, TI, Colaborador);
Assigned_To__c Lookup(User); Due_Date__c Date; Status__c Picklist (Pendente, Concluida, Nao_Aplicavel);
Completed_Date__c DateTime; Order__c Number(3,0).

### Onboarding_Task_Template__mdt
Title__c Text(120); Description__c Text Area(255); Owner_Role__c Text(20); Due_Offset_Days__c Number
(negativo = antes do início); Order__c Number; Applies_To_Employment_Type__c Text(40) (vazio = todos).
Registros: 8 tarefas (spec 15).
