# Roteiro de demonstração do RH Core (org Salesforce)

Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

Este roteiro acompanha a carga de dados de `scripts/seed-vetra-rh.sh` e é o par, na org, do `demo/ROTEIRO.md` (a demo pública em HTML). Os personagens, as matrículas e os cenários são os mesmos; aqui os passos usam as telas reais do produto instalado.

## Preparação

1. Implante `force-app` e rode a carga: `scripts/seed-vetra-rh.sh <alias-da-org> --agendar`. Pode rodar de novo sem duplicar nada.
2. A data de referência dos dados é **segunda-feira, 26/10/2026**. Prazos concessivos, férias em gozo e o funil foram calibrados para ela; em outro dia os números mudam (por exemplo, o prazo da Priscila Vieira vence em 03/11/2026).
3. Personas e como entrar:

| Persona | Quem | Matrícula | Acesso |
|---|---|---|---|
| Gestor | Patrícia Lemos, coordenadora comercial | VTR-0007 | o próprio admin que rodou a carga (HR_Admin e HR_Manager) |
| Colaborador | Carolina Fontes, analista sênior de vendas | VTR-0015 | usuário `carolina.fontes.<sufixo>@vetra-rh.example`, grupo HR_Employee |
| RH | Cláudia Rezende, analista de pessoas | VTR-0031 | usuário `claudia.rezende.<sufixo>@vetra-rh.example`, grupo HR_Admin |
| Recrutador | Marcelo Ibrahim | VTR-0032 | usuário `marcelo.ibrahim.<sufixo>@vetra-rh.example`, grupo HR_Recruiter |
| Candidato | visitante sem login | n/a | site público de vagas (módulo portal) |

   O sufixo são os 6 últimos caracteres do Id da org. Os usuários não têm senha: entre pelo admin em Configuração, Usuários, "Acessar como" (ou defina uma senha). Os demais colaboradores (inclusive o CEO e os diretores) existem só como registro, sem usuário, e isso é proposital: as etapas de aprovação cujo aprovador não tem usuário são puladas pelo motor.
4. Cenário nos dados: 6 departamentos, 14 cargos em 2 trilhas, 40 colaboradores em 4 níveis (1 desligado, 2 estagiários, 3 com faltas de 8, 16 e 35), 12 pedidos de férias, 3 promoções, 4 vagas (2 no portal), 25 candidatos, 30 candidaturas, o contratado Gabriel Nakamura em pré-admissão e o Ciclo 2026 em **Avaliação do gestor**. Diferença para a demo pública: lá o ciclo está em autoavaliação; aqui, seguindo a spec 18, já está na fase do gestor com metade das autoavaliações enviadas.

Aplicativo principal: **RH Core**. Para recrutamento há também o aplicativo **RH Recrutamento**. Relatórios e painel: pasta **RH Core** (aba Relatórios e aba Painéis).

## Colaborador: Carolina Fontes

1. **Quem eu sou.** Abra Colaboradores e o seu registro. Você enxerga o próprio cadastro (gestora Patrícia Lemos, cargo, admissão em 01/03/2021). O campo Salário não aparece: ele é restrito ao RH por permissão de campo, não só escondido na tela.
2. **Organograma privado.** Abra Organograma. Aparecem o seu cartão e a cadeia de gestores acima (Patrícia, Rodrigo e Helena). Colegas de equipe como o Lucas Andrade não aparecem: dado de pessoa é privado por padrão.
3. **Períodos aquisitivos.** Abra Períodos aquisitivos. Você vê só os seus: o período 01/03/2025 a 28/02/2026 tem 30 dias de direito e prazo concessivo até 28/02/2027. Períodos antigos estão concluídos.
4. **Histórico de férias.** Em Solicitações de férias está o pedido de fim de ano de 2025 (20 dias com 10 de abono, concluído). Os pedidos de colegas não aparecem.
5. **Trilha de carreira.** Abra Históricos de cargo. A linha do tempo mostra analista pleno desde 2021 e analista sênior desde 04/2024 (promoção). A coluna de salário não vem para você.
6. **Metas.** Abra Meu desempenho. Há 3 metas ativas somando 100% e a autoavaliação já enviada. O ciclo está em Avaliação do gestor, então ela não pode mais ser alterada.
7. **Resultado só depois de liberado.** Na mesma tela, a avaliação do gestor aparece como pendente. Ela só é lida pelo colaborador depois que o RH calibra e libera o ciclo (passo 8 do RH).
8. **Sem acesso a promoções e recrutamento.** Abra a aba Solicitações de promoção: nenhuma linha. Candidatos e candidaturas também não. Quem não tem a permissão recebe lista vazia, nunca dado.
9. **Aprovações do dia a dia.** A aba Aprovações fica vazia para você (não é aprovadora). Volte nela depois do passo 2 do Gestor para ver a diferença.
10. **Tentativa de burlar.** Tente editar o status de uma solicitação de férias pela API ou pela lista: o campo é somente leitura por permissão e só o serviço de aprovação o altera.

## Gestor: Patrícia Lemos

1. **Sua equipe.** Abra Colaboradores. Você vê a equipe direta e indireta: Carolina, Lucas, Bruna e Diego (em férias hoje). Fernanda Rocha, de outra coordenação, não aparece.
2. **Aprovar férias.** Abra Aprovações. O pedido da Bruna Teixeira (10 dias a partir de 07/12/2026) espera a sua decisão. Aprove: ele segue para a etapa do RH.
3. **Rejeição exige comentário.** Rejeite um pedido sem escrever nada: a regra recusa. Com comentário, a rejeição encerra as demais etapas e o motivo fica no registro (veja o pedido do Vinícius Azevedo, já rejeitado por André Siqueira).
4. **Calendário e saldos.** Abra Períodos aquisitivos da equipe: Lucas tem férias aprovadas de 14/12/2026 e Diego está em gozo desde 19/10/2026 (15 dias).
5. **Subárvore e salário.** No Organograma, na lista, o salário aparece mascarado em todas as linhas: gestor não lê salário.
6. **Solicitar promoção.** Abra Solicitar promoção, escolha o Lucas Andrade e o cargo Analista Sênior (próximo passo da trilha). Você não vê nem informa salário. Como o aprovador de segundo nível (Rodrigo Tavares) não tem usuário, a etapa dele é pulada e a solicitação segue para o RH.
7. **Promoção da sua equipe.** Em Solicitações de promoção está a da Bruna Teixeira (Analista Júnior para Pleno), já aprovada e efetiva em 01/12/2026.
8. **Avaliar a equipe.** Abra Avaliar equipe: com o ciclo na fase do gestor, as 4 avaliações da sua equipe estão pendentes. Preencha uma nota e um comentário e envie.
9. **Vaga sob sua gestão.** No aplicativo RH Recrutamento, o Funil mostra só a vaga Analista de Vendas Pleno (você é a gestora contratante). Dê uma nota a um candidato em entrevista; os cartões de outras vagas não aparecem.
10. **Painel.** Abra o Painel do RH: se você tiver o acesso ao painel, os números de headcount do seu departamento aparecem no gráfico por departamento.

## RH: Cláudia Rezende

1. **Painel do RH.** Abra a aba Painéis, pasta RH Core, Painel do RH: headcount por departamento (38 ativos), prazos de férias, funil, tempo médio por etapa, avaliações e promoções. Volte aqui no fim para ver os números mudarem.
2. **Visão completa e salário.** Em Colaboradores você vê a empresa inteira, com o campo Salário liberado. Abra Otávio Leal (desligado em 14/08/2026).
3. **Etapa final das férias.** Em Aprovações está o pedido da Fernanda Rocha (20 dias a partir de 30/11/2026), que já passou pelo gestor André Siqueira. Aprove: o status vira Aprovado e o período passa a refletir os dias.
4. **Prazos concessivos.** Rode o relatório "Férias com prazo concessivo vencendo": Priscila Vieira (prazo 03/11/2026) e Rafael Brandão (01/12/2026), 30 dias cada. O relatório "Saldo de férias por colaborador" mostra o saldo de cada um. Mateus Pires perdeu o período por 35 faltas (art. 130).
5. **Salário fora da faixa.** Em Revisão de promoções abra a do Henrique Dantas (Analista Pleno para Sênior, faixa de R$ 8.000 a R$ 12.000, visível só ao RH). Informe 7.000 e tente aprovar: a regra de faixa exige justificativa.
6. **Aprovar e efetivar.** Corrija para 8.800 e aprove: a promoção fica aprovada para 16/11/2026. A efetivação diária (`PromotionEffectivationBatch`) fecha o histórico antigo e abre o novo na data; rode-a pelo Apex anônimo para ver o histórico mudar.
7. **LGPD: retenção.** Dois candidatos estão parados há mais de 180 dias (candidaturas reprovadas em março e abril). Rode `Database.executeBatch(new CandidateRetentionBatch())`: nome, e-mail, telefone e cidade são apagados. O contratado nunca é anonimizado.
8. **Ciclo de avaliação.** Em Ciclos de avaliação (painel), avance a fase para Calibração, calibre as notas enviadas e libere os resultados. O ciclo vira Concluído e o colaborador passa a ler a avaliação.
9. **Ativar a admissão.** Com o módulo de onboarding instalado, ative o Gabriel Nakamura (PRE-000001) com a matrícula VTR-0041 e uma data de admissão. As tarefas pendentes têm as datas recalculadas e ele entra no organograma com histórico de admissão.
10. **Fechar o ciclo da demo.** Volte ao Painel do RH: avaliações, promoções e headcount refletem o que você fez. Para repetir a demonstração, rode de novo o seed (os passos 3, 6 e 8 já alteraram dados; reponha numa org nova).

## Recrutador: Marcelo Ibrahim

1. **Funil da vaga.** No aplicativo RH Recrutamento, abra Funil de recrutamento. O kanban mostra as vagas abertas com uma coluna por etapa e a nota de cada candidatura.
2. **Transição inválida.** Arraste um cartão de Nova direto para Proposta. A máquina de etapas recusa e explica a transição não permitida.
3. **Alternativa por teclado.** Use o menu "Mover para" do cartão para levar um candidato de Nova para Triagem.
4. **Reprovar exige motivo.** Mova um cartão para Reprovado: o motivo é obrigatório.
5. **Proposta exige nota.** Leve Letícia Coutinho de Entrevista técnica para Proposta: a regra pede nota de 0 a 5 antes.
6. **Histórico com dias na etapa.** Abra uma candidatura: o histórico lista cada mudança de etapa e quantos dias o candidato ficou na anterior.
7. **Contratar.** Mova Ricardo Sampaio de Proposta para Contratado. Com o módulo de onboarding, o sistema cria o colaborador em pré-admissão com o plano de 8 tarefas; repetir o movimento não duplica.
8. **Gerir vagas.** Em Vagas, pause, publique no portal ou feche uma vaga. Ao fechar a de logística, as candidaturas ativas são reprovadas com "Vaga encerrada".
9. **O portal público.** Só vagas Abertas e publicadas aparecem no site: Analista de Vendas Pleno e Analista de Sistemas Pleno (Salesforce). Logística e fiscal ficam de fora.
10. **Indicadores.** Rode os relatórios "Funil de recrutamento por etapa" e "Tempo médio por etapa": 30 candidaturas no funil e a média de dias por etapa (cerca de 3 em Nova, 5 em Triagem, 6 em Entrevista RH, 7 em Entrevista técnica).

## Candidato: visitante do portal

Depende do módulo portal e do site (`unpackaged/site`) implantados. Sem login.

1. **Vagas abertas.** A lista mostra só as 2 vagas Abertas e publicadas; as demais não vazam.
2. **Filtros.** Filtre por modelo de trabalho (Remoto) ou busque por "sistemas".
3. **Detalhe da vaga.** Abra Analista de Vendas Pleno: descrição, requisitos e formulário, sem expor gestor, recrutador ou identificador interno.
4. **Consentimento LGPD.** Tente enviar sem aceitar o termo: o envio é bloqueado.
5. **Envie a candidatura.** Preencha nome e e-mail, aceite o termo e envie. O envio precisa levar alguns segundos desde que a página abriu (proteção contra robôs).
6. **Confirmação genérica.** O candidato vê uma confirmação sem detalhes internos. No Salesforce a candidatura entra na etapa Nova, origem Portal, com o consentimento registrado.
7. **Veja no funil.** Como Recrutador, abra o Funil: a candidatura nova está na coluna Nova, dona da fila de recrutamento.
8. **Candidatura duplicada.** Envie de novo para a mesma vaga com o mesmo e-mail: "Este candidato já se inscreveu nesta vaga." Em outra vaga, o cadastro do candidato é reaproveitado.
9. **Defesa contra robôs.** O campo oculto preenchido faz o servidor descartar em silêncio; envio rápido demais é rejeitado.
10. **Limite diário.** Depois de 3 candidaturas no dia para o mesmo e-mail, o servidor responde que o limite foi atingido e nada é gravado.

## Relatórios e painel de apoio

| Relatório (pasta RH Core) | Mostra |
|---|---|
| Headcount por departamento | 38 colaboradores ativos por departamento |
| Férias com prazo concessivo vencendo | Priscila Vieira e Rafael Brandão, 60 dias de saldo em risco |
| Saldo de férias por colaborador | saldo dos períodos já adquiridos, por pessoa |
| Funil de recrutamento por etapa | 30 candidaturas por etapa |
| Tempo médio por etapa | média de dias na etapa anterior |
| Avaliações por status no ciclo atual | Pendente, Em andamento e Enviada no Ciclo 2026 |
| Promoções por status | Pendente, Aprovado e Efetivado |

O painel "Painel do RH" reúne seis relatórios (todos, menos o de saldo por colaborador). Quem não é do grupo HR_Team não vê a pasta; o acesso a relatórios e painéis vem do permission set `HR_Analytics_Admin` (ver pedidos no relatório do módulo).
