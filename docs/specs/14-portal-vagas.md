# 14. Fase 2: Portal público de vagas (portal)

Pastas: `force-app/portal` (Apex, LWC, permission set) e `unpackaged/site` (site, fora do pacote).
Depende de recruiting. Branch: `feat/portal`.

## Histórias

1. Como candidato, sem login, vejo as vagas abertas da Vetra, filtro por modelo de trabalho e área, e
   abro a página da vaga.
2. Como candidato, me inscrevo com nome, e-mail, telefone, cidade, LinkedIn e uma mensagem, aceitando o
   termo de privacidade.
3. Como RH, recebo a candidatura na fila de recrutamento, na etapa Nova, com origem Portal.

## Regras de segurança (o centro deste módulo)

- G1. O usuário convidado não recebe acesso de objeto. Tudo passa por `JobPortalController`
  (`without sharing`, comentário explicando), que devolve DTOs só com: título, slug, departamento (nome),
  localização, modelo de trabalho, tipo de contratação, descrição, requisitos, data de abertura. Nunca Ids
  de usuário, gestor ou recrutador.
- G2. Só vagas com Status__c = Aberta e Publish_On_Portal__c = true.
- G3. `submitApplication(PortalApplicationInput input)`:
  - validar slug de vaga elegível (G2);
  - campos obrigatórios: nome (2 a 120), e-mail válido, consentimento = true;
  - limites de tamanho em todos os campos; remover HTML de texto livre;
  - honeypot: campo `website` precisa vir vazio; senão responder sucesso falso (sem gravar) para não
    ensinar o robô;
  - tempo mínimo: `renderedAt` (epoch ms enviado pelo LWC) com menos de `Portal_Min_Submit_Seconds__c`
    segundos antes do envio é rejeitado como robô;
  - limite diário por e-mail: mais de `Portal_Daily_Limit_Per_Email__c` candidaturas criadas hoje para o
    mesmo `Email_Normalized__c` é rejeitado com "Limite diário de candidaturas atingido.";
  - reaproveitar candidato por e-mail (C4 da spec 13) e respeitar candidatura única (C5);
  - gravar consentimento: Consent_Given__c, Consent_Date__c, Consent_Text_Version__c;
  - OwnerId de candidato e candidatura = fila `HR_Recruiting_Queue`; Source__c = Portal; Stage__c = Nova;
  - resposta genérica de sucesso; erros devolvem mensagem amigável sem detalhe técnico.
- G4. Sem upload de arquivo nesta versão.
- G5. Texto de privacidade visível no formulário, com versão `Consent_Text_Version__c`.

## Componentes

Apex: `JobPortalController`, `JobPortalService`, `PortalApplicationInput`, `PortalJobDto`, testes
(rodar como usuário convidado em teste: criar usuário com perfil de guest não é possível; testar via
`System.runAs` de um usuário sem permissões de objeto e com o PS `HR_Portal_Guest`, provando que o
controller funciona sem acesso a objeto).

LWC (expostos para Experience Cloud, `lightningCommunity__Page` e `lightningCommunity__Default`):
- `portalJobList`: lista de cartões com filtros, estado vazio, carregamento.
- `portalJobDetail`: lê o slug do parâmetro de URL (`?vaga=slug`), mostra a vaga e o formulário.
- `portalApplicationForm`: formulário acessível (labels, mensagens de erro ligadas ao campo), honeypot
  escondido de leitores de tela (`aria-hidden`, `tabindex=-1`), checkbox de consentimento, sucesso.

## Site (fora do pacote, `unpackaged/site`)

1. `sf community create --name "Vagas Vetra" --template-name "Build Your Own (LWR)" --url-path-prefix vagas --target-org <org>`.
2. Aguardar a criação, `sf project retrieve start --metadata DigitalExperienceBundle Network CustomSite --target-org <org>`
   para `unpackaged/site` (ajustar os nomes reais retornados).
3. Montar páginas: Home com `portalJobList`; página "vaga" com `portalJobDetail`.
4. Perfil guest do site: atribuir o PS `HR_Portal_Guest` ao usuário guest (Apex anônimo em
   `scripts/apex/assign-guest-ps.apex`) ou incluir o acesso à classe no perfil guest recuperado.
5. Publicar: `sf community publish --name "Vagas Vetra" --target-org <org>`.
6. Smoke: abrir a URL pública do site com `curl` e conferir HTTP 200; registrar a URL em PROGRESSO.md.

Plano B se a criação do site falhar na org: entregar os LWCs, o controller e os testes, documentar os
passos manuais em `docs/execucao/SITE-MANUAL.md` e seguir. Não bloquear o restante.

## Critérios de aceite

- [ ] Testes de G2, G3 (cada validação, honeypot, tempo mínimo, limite diário, duplicidade, reaproveitar
      candidato) e prova de que o DTO não expõe campos internos.
- [ ] Jest para os 3 LWCs (incluindo erro de validação e sucesso).
- [ ] Site publicado com URL registrada, ou plano B documentado.
- [ ] Gates da spec 03.
