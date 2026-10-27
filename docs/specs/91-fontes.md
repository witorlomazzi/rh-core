# 91. Fontes e decisões da pesquisa (25/10/2026)

## Regras de férias (CLT, redação da Lei 13.467/2017)

| Regra | Artigo | Como entra no produto |
|---|---|---|
| Dias de férias conforme faltas injustificadas no período aquisitivo: até 5 = 30; 6 a 14 = 24; 15 a 23 = 18; 24 a 32 = 12 | art. 130 | `HR_Absence_Rule__mdt` |
| Acima de 32 faltas, perde o direito daquele período | art. 130 (interpretação corrente) | período Status__c = Perdido |
| Concessão nos 12 meses seguintes ao período aquisitivo | art. 134, caput | `Concession_Deadline__c` |
| Fracionamento com concordância do empregado: até 3 períodos, um com pelo menos 14 dias corridos e os demais com pelo menos 5 | art. 134, §1º | V5, V6, V7 |
| Vedado iniciar no período de 2 dias que antecede feriado ou repouso semanal remunerado | art. 134, §3º | V4 |
| Aviso de férias com antecedência mínima de 30 dias | art. 135 | V3 |
| Férias fora do prazo concessivo são devidas em dobro | art. 137 | V10 (aviso) |
| Conversão de 1/3 em abono pecuniário, pedido até 15 dias antes do fim do período aquisitivo | art. 143, caput e §1º | V8, V9 |

Notas:
- A regra antiga de período único para menores de 18 e maiores de 50 anos (antigo §2º do art. 134) foi
  revogada pela reforma de 2017 e não entra.
- O pagamento em dobro por atraso no pagamento das férias (Súmula 450 do TST) foi afastado pelo STF em
  2022; o produto não trata pagamento.
- Convenção ou acordo coletivo pode alterar pontos da regra geral; por isso tudo é parâmetro.
- Fontes consultadas: [Contábeis: férias fracionadas](https://www.contabeis.com.br/artigos/78476/ferias-fracionadas-evite-passivo-trabalhista-na-clt/),
  [Migalhas: reforma trabalhista e férias](https://www.migalhas.com.br/depeso/260806/reforma-trabalhista---ferias),
  [Modelo Inicial: CLT art. 130](https://modeloinicial.com.br/lei/CLT/array-0x55e12e93c008/art-130),
  [FINDES: STF e Súmula 450](https://findes.com.br/wp-content/uploads/2022/08/Informe-Estrategico-–-Decisao-do-STF-sobre-a-Sumula-450-do-TST-Pagamento-em-dobro-da-remuneracao-das-ferias.pdf).
  Conferir no texto compilado do Planalto antes de publicar o README (o acesso falhou durante a pesquisa).

## Plataforma

- **Experience Cloud para funcionários internos**: guias de licenciamento indicam que licenças de
  comunidade são para público externo e não devem substituir licenças internas. Decisão: Meu RH é app
  Lightning interno; Experience Cloud só no portal público de vagas.
  [SalesforceBen: licenças Experience Cloud](https://www.salesforceben.com/salesforce-experience-cloud-licences/).
- **Scratch org com Experience Cloud**: feature `Communities` e setting
  `communitiesSettings.enableNetworksEnabled`.
  [Salesforce DX: scratch org definition](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_scratch_orgs_def_file.htm).
- **Site em unlocked package**: relatos de que workspaces de site LWR não são empacotáveis; prática comum
  é empacotar objetos, Apex e LWC e implantar o site à parte. Decisão: `unpackaged/site`.
  [Trailblazer Community](https://trailhead.salesforce.com/trailblazer-community/feed/0D5KX00000jAEAW0A4).
- **Aprovação**: motor próprio em Apex para não depender do suporte de Approval Process no pacote e para
  ser testável de ponta a ponta.

## Ambiente (verificado em 25/10/2026)

- Dev Hub: `witor-dev`. Limites: 3 scratch orgs ativas, 6 criações por dia,
  6 versões de pacote por dia. Nenhum pacote criado ainda.
- Node local 22.11 (o Astro do site exige 22.12; para este projeto basta o Node instalado). sf CLI
  2.142.7 com plugin code-analyzer 5.14.0. Java 21.
