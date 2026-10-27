# Módulo portal (spec 14)

Branch `feat/portal`. Org de trabalho `rh-w2`. Projeto demonstrativo, empresa e dados fictícios.

## O que foi entregue

- Controller público `JobPortalController` (`without sharing`, comentado conforme a spec 02) e serviço `JobPortalService` com as regras G1 a G5.
- DTOs `PortalJobDto` (só título, slug, departamento, localização, modelo de trabalho, tipo de contratação, descrição, requisitos e data de abertura) e `PortalApplicationInput`.
- Três LWCs expostos ao Experience Cloud (`lightningCommunity__Page` e `lightningCommunity__Default`): `portalJobList`, `portalJobDetail`, `portalApplicationForm`, mais o módulo de apoio `portalUtils` (sem interface).
- Site LWR "Vagas Vetra" criado, retrievado para `unpackaged/site`, ajustado (home com `portalJobList`, página `vaga` com `portalJobDetail`), implantado e publicado na `rh-w2`.
- `scripts/apex/assign-guest-ps.apex`: atribui `HR_Portal_Guest` ao usuário convidado do site (idempotente). Executado com sucesso: a org aceita permission set no usuário convidado, então não foi preciso editar o perfil.

## URL do site (rh-w2, scratch org, expira em 02/11/2026)

- Lista: https://computing-ruby-4189-dev-ed.scratch.my.site.com/vagas/
- Detalhe: https://computing-ruby-4189-dev-ed.scratch.my.site.com/vagas/vaga?vaga=<slug>
- Smoke: `curl -L` na lista e `curl` no detalhe respondem HTTP 200 (a lista redireciona `/vagas` para `/vagas/` com 301). O conteúdo é montado no navegador, então o conteúdo foi conferido no navegador embutido: lista com as 2 vagas abertas e publicadas da org, detalhe com texto e formulário, e uma candidatura real como visitante anônimo (candidato e candidatura criados na etapa Nova, origem Portal, dono a fila `HR_Recruiting_Queue`, consentimento e versão do termo gravados, mensagem gravada).
- O `Network` continua com status `UnderConstruction` (publicado, acessível sem login). Para ir ao ar de fato em outra org, mudar `status` para `Live` em `unpackaged/site/networks/Vagas Vetra.network-meta.xml` e reimplantar.

## Checklist dos critérios de aceite

- [x] Testes de G2, G3 (cada validação, honeypot, tempo mínimo, limite diário, duplicidade, reaproveitar candidato) e prova de que o DTO não expõe campos internos (`dtoExposesOnlyAllowedFields` compara o conjunto exato de chaves e procura Ids).
- [x] Jest para os 3 LWCs (mais o `portalUtils`), com erro de validação, erro do servidor e sucesso.
- [x] Site publicado com URL registrada (acima). Plano B não foi necessário; `docs/execucao/SITE-MANUAL.md` não foi criado.
- [x] Gates da spec 03: deploy sem erro; testes Apex 100% e cobertura acima de 85% nas classes com código; Jest; Code Analyzer sem severidade 1 ou 2; sem travessão nem emoji; ESLint dos LWCs limpo. Ressalva: `sf-code-reviewer` aplicado como autorrevisão do diff (sem SOQL ou DML em loop, binds em todas as consultas, nenhum Id exposto, contexto de sistema comentado, mensagens sem detalhe técnico).

## Classes e LWCs

Apex: `JobPortalController`, `JobPortalService`, `PortalJobDto`, `PortalApplicationInput`, testes `JobPortalControllerTest` e `JobPortalServiceTest`.
LWC: `portalJobList`, `portalJobDetail`, `portalApplicationForm`, `portalUtils`.
Permission set: `HR_Portal_Guest` com `classAccesses` só do `JobPortalController`.
Site: `unpackaged/site` (`digitalExperiences/site/Vagas_Vetra1`, `digitalExperienceConfigs`, `networks`, `sites`). Rota personalizada `Vaga__c` (o sufixo `__c` é exigido pela plataforma).

## Números

- Testes Apex: 20, 100% passando (rh-w2). Cobertura: JobPortalController 90%, JobPortalService 98%; `PortalJobDto` e `PortalApplicationInput` só têm declarações de campo (nenhuma linha executável, 0 linhas cobríveis). Linhas sem cobertura: o `catch (Exception)` genérico do controller e o ramo de tradução genérica de erro do recrutamento, que não há como provocar de forma determinística.
- Jest: 4 suítes, 27 testes.
- Code Analyzer (pmd:Recommended): 0 violações de severidade 1 ou 2; restam avisos de severidade 3 e 4 (complexidade do `submit`, ApexDoc, parâmetros).

## Decisões

1. A candidatura chega ao controller como texto JSON (`submitApplication(String payload)`), não como `PortalApplicationInput`. No runtime LWR do site, o parâmetro de classe Apex chegava com todos os campos nulos (diagnosticado serializando o objeto no servidor); texto atravessa sem perda. O controller desserializa para `PortalApplicationInput`, que continua sendo o contrato do serviço. Payload ilegível devolve a mensagem genérica.
2. `renderedAt` é `String` com o epoch em milissegundos: o runtime não entregava número grande a campo `Long` nem `Decimal`. O valor é emitido pelo servidor (`getFormConfig`), então relógio errado do visitante não bloqueia o envio. Um robô pode forjar o valor; a defesa serve contra robôs ingênuos, junto com o honeypot e o limite diário.
3. A versão do termo de privacidade e a data do consentimento vêm do servidor (`HR_Setting__mdt`), nunca do navegador.
4. Limite diário: rejeita quando já existem `Portal_Daily_Limit_Per_Email__c` ou mais candidaturas criadas hoje para o e-mail (com limite 3, a quarta é recusada).
5. A lista devolve `description` e `requirements` vazios (resposta pequena); o detalhe devolve o texto completo, renderizado por `lightning-formatted-rich-text` (sanitiza HTML).
6. Mensagens do recrutamento só chegam ao visitante se forem a de candidatura duplicada (C5) ou de vaga fechada; qualquer outra vira a mensagem genérica. Consequência assumida: a mensagem de duplicidade e a de limite diário permitem saber que um e-mail já se candidatou; a spec pede essas mensagens.
7. Os LWCs usam HTML e CSS próprios (sem depender de componentes `lightning-*` de formulário), para renderizar igual em sites LWR sem SLDS carregado. O endereço da vaga usa `@salesforce/community/basePath` e a propriedade `detailPath` (padrão `vaga`).
8. Metadados do site: removi o e-mail pessoal retrievado (`newSenderAddress`; `emailSenderAddress` virou `noreply@vetra.example.com`). `sites/Vagas_Vetra.site-meta.xml` mantém o usuário da scratch org em `siteAdmin` e `siteGuestRecordDefaultOwner`; ajustar ao reimplantar em outra org. `geoBotsAllowed` foi removido do conteúdo do site porque o deploy o recusa com `AUTHENTICATED_WITH_PUBLIC_ACCESS_ENABLED`.
9. Dados criados pelo smoke na rh-w2 (`ZZTEST-Maria Portal`, `ZZTEST-Anon Check`) foram deixados na org de trabalho.

## Pendências

- Verificação visual fina (layout em celular, contraste) só por inspeção do texto e do DOM; falta uma pessoa olhar a tela.
- Status `Live` do site e domínio próprio ficam para a integração (rh-int) e para o Witor.
- Reimplantação em rh-int: ajustar `siteAdmin` e `siteGuestRecordDefaultOwner`, implantar `force-app` e depois `unpackaged/site`, rodar `scripts/apex/assign-guest-ps.apex` e publicar.

## Pedidos ao orquestrador

- Se o `PROGRESSO.md` deve registrar a URL do site, usar a seção acima (a spec pede o registro; o prompt do módulo restringia a escrita ao relatório).
- Se quiser os componentes do portal no `RH_Core.app`, nada a fazer: o portal não tem aba nem app.

## Como reproduzir

```bash
LOCK="<raiz-do-repositorio>/.locks/rh-w2"
until mkdir "$LOCK" 2>/dev/null; do sleep 30; done; trap 'rmdir "$LOCK"' EXIT
sf project deploy start --source-dir force-app/portal --target-org rh-w2 --ignore-conflicts --wait 20
sf apex run test --target-org rh-w2 --code-coverage --result-format human --wait 30 \
  --class-names JobPortalControllerTest JobPortalServiceTest
sf project deploy start --source-dir unpackaged/site --target-org rh-w2 --ignore-conflicts --wait 20
sf apex run --file scripts/apex/assign-guest-ps.apex --target-org rh-w2
sf community publish --name "Vagas Vetra" --target-org rh-w2
# fora da trava
npm run test:unit -- force-app/portal
sf code-analyzer run --workspace force-app/portal --rule-selector pmd:Recommended --severity-threshold 2
npx eslint --resolve-plugins-relative-to . "force-app/portal/lwc/**/*.js"
curl -sL -o /dev/null -w "%{http_code}\n" https://computing-ruby-4189-dev-ed.scratch.my.site.com/vagas/
```
