# RH Core: visão geral

Status: spec aprovada para execução noturna em 25/10/2026 (pedido do Witor na conversa). Fonte de verdade
deste projeto. Se o código divergir da spec, a spec vence; se a spec estiver errada, registre em
`docs/execucao/PROGRESSO.md` na seção "Divergências" e siga a decisão mais conservadora.

## O que é

Um produto de RH instalável no Salesforce (unlocked package) para qualquer empresa brasileira gerir
pessoas: estrutura organizacional, férias pela CLT, promoções, recrutamento com portal público de vagas,
admissão e avaliação de desempenho. Cenário de demonstração: **Vetra Distribuidora**, empresa fictícia já
usada no portfólio.

Texto obrigatório no README e em toda tela de demo:
"Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas
por confidencialidade." As regras de férias seguem a CLT vigente com parâmetros configuráveis; convenção
coletiva pode alterá-las e o produto não substitui orientação jurídica.

## Personas

| Persona | Quem é | O que faz |
|---|---|---|
| Colaborador | Qualquer funcionário | Vê os próprios dados, saldo e histórico de férias, solicita férias, faz autoavaliação, acompanha onboarding |
| Gestor | Colaborador com equipe | Tudo do colaborador + vê a equipe direta e indireta, organograma, aprova férias, solicita promoções, avalia a equipe |
| RH | Time de pessoas | Vê tudo, inclusive salário; aprova etapa final; gere cargos, faixas, feriados, ciclos de avaliação e onboarding |
| Recrutador | RH focado em vagas | Gere vagas, candidatos e funil |
| Gestor contratante | Gestor dono de uma vaga | Vê e avalia candidaturas das próprias vagas |
| Candidato | Público externo, sem login | Vê vagas abertas e se inscreve pelo portal |

## Módulos e fases

| Fase | Módulo | Pasta | Spec |
|---|---|---|---|
| 0 | Fundação: modelo de dados completo, segurança, motor de aprovação, organograma | `force-app/core` | 10 |
| 1 | Férias CLT | `force-app/leave` | 11 |
| 1 | Promoções e histórico de cargo | `force-app/promotion` | 12 |
| 1 | Recrutamento (ATS) | `force-app/recruiting` | 13 |
| 1 | Avaliação de desempenho | `force-app/performance` | 16 |
| 2 | Portal público de vagas | `force-app/portal` + `unpackaged/site` | 14 |
| 2 | Admissão e onboarding | `force-app/onboarding` | 15 |
| 2 | Meu RH (experiência do colaborador e do gestor) | `force-app/myhr` | 17 |
| 2 | Relatórios, dashboards e dados de demonstração | `force-app/analytics` + `scripts/` | 18 |
| 3 | Pacote, README, CI e verificação final | raiz | 19 |

## Arquitetura em uma página

- **Modelo de dados inteiro criado na Fase 0** (spec 01). As fases seguintes só adicionam campos aos
  objetos que possuem, e de preferência nenhum. Isso permite trabalho paralelo sem conflito.
- **Apex em camadas**: Controller fino (`@AuraEnabled`), Service com regra de negócio, Selector com
  consulta `WITH USER_MODE`, Trigger único por objeto chamando Handler. Contexto de sistema só onde a spec
  manda, sempre com comentário explicando o motivo.
- **Segurança** (spec 02): OWD privado para dado de pessoa, compartilhamento por cadeia de gestores via
  Apex Managed Sharing, campos salariais restritos ao RH por FLS, objetos filhos controlados pelo pai.
- **Aprovação**: motor próprio em Apex (`ApprovalService`) configurado por Custom Metadata, usado por
  Férias e Promoções. Não usar Approval Process nativo.
- **Regras configuráveis**: parâmetros da CLT, etapas de recrutamento, etapas de aprovação e modelos de
  onboarding em Custom Metadata.
- **Interface**: LWC com SLDS, funcionando dentro do Lightning. Apps: "Meu RH" (todos) e "RH Core" (RH).
- **Portal de vagas**: Experience Cloud LWR, usuário convidado, Apex com DTO de campos permitidos.
- **Entrega**: unlocked package sem namespace para o conteúdo de `force-app`; site e dados de demo fora do
  pacote.

## Fora do escopo (não fazer)

Folha de pagamento, ponto e banco de horas, eSocial, benefícios, integração com sistemas externos, upload
de currículo pelo portal (v2), login de candidato, app mobile nativo, tradução para outros idiomas.

## Critério de pronto do projeto

1. Todas as fases com os critérios de aceite das specs atendidos ou com pendência documentada.
2. `sf project deploy start` do repositório inteiro numa scratch org limpa, sem erro.
3. Todos os testes Apex passando, cobertura de cada classe de pelo menos 85%, testes Jest passando.
4. Salesforce Code Analyzer sem violação de severidade 1 ou 2 sem justificativa no código.
5. Versão do pacote criada com `--code-coverage`, ou motivo documentado.
6. README completo no formato do portfólio (spec 19).
