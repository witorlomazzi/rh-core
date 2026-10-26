# 03. Convenções, estrutura e gates de qualidade

## Estrutura do repositório

```
rh-core/
  sfdx-project.json          pacote "RH Core", path force-app, sourceApiVersion 62.0 (ou a mais alta aceita pela org)
  config/project-scratch-def.json
  force-app/
    core/        objects, classes, triggers, lwc, permissionsets, permissionsetgroups, customMetadata, ...
    leave/  promotion/  recruiting/  performance/  onboarding/  portal/  myhr/  analytics/
  unpackaged/
    site/        Experience Cloud (Network, CustomSite, DigitalExperienceBundle, perfil guest)
  scripts/apex/  seed-vetra-rh.apex e scripts de smoke
  docs/specs/  docs/execucao/
  .github/workflows/ci.yml
```

Dentro de cada módulo use a estrutura padrão de source format: `objects/`, `classes/`, `triggers/`,
`lwc/`, `permissionsets/`, `customMetadata/`, `flexipages/`, `tabs/`, `applications/`,
`notificationtypes/`, `reports/`, `dashboards/`.

Scratch org definition (base):
```json
{
  "orgName": "Vetra RH Core",
  "edition": "Developer",
  "language": "pt_BR",
  "country": "BR",
  "features": ["Communities", "EnableSetPasswordInApi"],
  "settings": {
    "lightningExperienceSettings": { "enableS1DesktopEnabled": true },
    "communitiesSettings": { "enableNetworksEnabled": true },
    "mobileSettings": { "enableS1EncryptedStoragePref2": false },
    "languageSettings": { "enableTranslationWorkbench": false }
  }
}
```
Se a org recusar algum item, remova o item, registre em PROGRESSO.md e siga.

## Nomenclatura

- Classes: `<Dominio><Papel>`: `LeaveRequestService`, `EmployeeSelector`, `LeaveRequestController`,
  `LeaveRequestTriggerHandler`. Testes: `<Classe>Test`. Prefixo de domínio por módulo:
  core `Employee*`, `Department*`, `Approval*`, `Hr*`; leave `Leave*`; promotion `Promotion*`,
  `PositionHistory*`; recruiting `JobOpening*`, `Candidate*`, `JobApplication*`, `Recruiting*`;
  performance `Review*`, `Goal*`, `SelfAssessment*`, `PerformanceReview*`; onboarding `Onboarding*`;
  portal `JobPortal*`; myhr `MyHr*`; analytics `HrAnalytics*`.
- LWC: camelCase com prefixo do módulo: `coreOrgChart`, `leaveRequestForm`, `leaveTeamCalendar`,
  `promotionRequestForm`, `recruitingKanban`, `performanceReviewForm`, `portalJobList`, `myHrHome`.
- Trigger: `<Objeto>Trigger` (ex.: `LeaveRequestTrigger`), um por objeto, sem lógica.
- Dados de teste com prefixo `ZZTEST-`. Dados de demonstração (seed) com nomes fictícios e matrícula
  iniciando em `VTR-`.

## Classes compartilhadas da Fase 0 (contrato que os módulos usam)

| Classe | Contrato |
|---|---|
| `HrSettings` | `HrSettings.get()` devolve `HR_Setting__mdt` Default. `@TestVisible static HR_Setting__mdt testOverride` para teste |
| `HrDateUtils` | `isWorkingDay(Date d, String location)`, `isRestDay(Date d)`, `isHoliday(Date d, String location)`, `addMonths`, `daysBetween` |
| `EmployeeSelector` | `byIds(Set<Id>)`, `byUserIds(Set<Id>)`, `currentUserEmployee()`, `directReports(Id)`, `subtree(Id)` (via Hierarchy_Path__c LIKE), todos `WITH USER_MODE` |
| `EmployeeHierarchyService` | `managerChainUserIds(Employee__c)`, `secondLevelManagerUserId(Employee__c)`, `isInChainOf(Id managerEmployeeId, Id employeeId)` |
| `ApprovalService` | `submit(Id requestId, String requestType)`, `decide(Id approvalStepId, Boolean approve, String comments)`, `cancel(Id requestId, String requestType)`, `pendingForCurrentUser()` |
| `ApprovalOutcomeHandler` | interface: `void onApproved(Id requestId)`, `void onRejected(Id requestId)`, `void onStepAdvanced(Id requestId, Integer newStep)` |
| `HrNotificationService` | `notify(Set<String> recipientIds, Id targetId, String title, String body, String typeDeveloperName)`, falha silenciosa registrada em debug |
| `HrTestDataFactory` | `department()`, `position()`, `employee(Id managerId, Id userId)`, `user(String alias, String psgDeveloperName)`, `orgTree()` (CEO, 2 gestores, 4 colaboradores com usuários), `holiday(Date, String)` |
| `TriggerHandler` | base simples com `beforeInsert`, `afterInsert`, `beforeUpdate`, `afterUpdate`, `afterDelete` e bypass estático `TriggerHandler.bypass('Nome')` |

Os módulos podem ler `ApprovalService` e as classes acima, mas não podem editá-las. Se precisarem de
mudança, registram em PROGRESSO.md ("Pedido ao core") e o orquestrador decide.

## Licenças e usuários de teste

Antes de criar usuários, consulte `SELECT Name, TotalLicenses, UsedLicenses FROM UserLicense`. Use o
perfil "Standard User" se houver licença Salesforce livre; senão "Standard Platform User" (licença
Salesforce Platform). Nos testes, crie no máximo 4 usuários por método e reutilize via `@TestSetup`.
Se aparecer `LICENSE_LIMIT_EXCEEDED`, troque o perfil para o que tiver licença e registre em PROGRESSO.md.

## Gates de qualidade (por módulo, antes do merge)

1. `sf project deploy start --source-dir force-app/<modulo> --target-org <org>` sem erro (ou o
   repositório inteiro, se o módulo depender de mudança fora da pasta).
2. `sf apex run test --class-names <testes do módulo> --code-coverage --result-format json --wait 30`:
   100% passando e cobertura de cada classe do módulo de pelo menos 85%.
3. `npm run test:unit -- force-app/<modulo>`: todos os testes Jest do módulo passando. Todo LWC tem teste.
4. `sf code-analyzer run --workspace force-app/<modulo> --rule-selector pmd:Recommended --severity-threshold 2`:
   sem violação de severidade 1 ou 2. Supressão só com `@SuppressWarnings('PMD.<Regra>')` e comentário
   do motivo (ex.: consulta a Custom Metadata, contexto de sistema documentado na spec 02).
5. Revisão com a skill `sf-code-reviewer` sem achado grave (bulkificação, SOQL em loop, injeção, CRUD/FLS,
   sharing, limites, cobertura).
6. Textos e documentação sem travessão (`—`): `grep -rc '—'` igual a zero nos arquivos do módulo.
7. Sem emoji em código, rótulo ou documentação.

## Commits

- Mensagens em português, padrão `tipo(modulo): descrição` (feat, fix, test, docs, chore, ci).
- **Sem linha `Co-Authored-By`** (regra do Witor: tudo sai em nome dele).
- Commits pequenos. Nunca `--no-verify`, nunca force push.
