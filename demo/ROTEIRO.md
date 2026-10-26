# Roteiro da demonstração do RH Core

Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.

A data da demonstração é fixa (segunda-feira, 26/10/2026), para que os prazos e as regras sejam sempre os mesmos. Cada persona tem 10 passos. Na interface, o botão "Roteiro guiado" abre este mesmo roteiro e leva você à tela de cada passo. "Reiniciar demo" devolve os dados ao estado inicial.

Os personagens estão vinculados à árvore de 40 colaboradores fictícios da Vetra Distribuidora (matrículas VTR-0001 em diante). Os fluxos se encadeiam: o pedido de férias enviado pelo Colaborador chega ao Gestor, depois ao RH; a candidatura enviada pelo Candidato aparece no funil do Recrutador.

Arquivo gerado por `node demo/tools/gen-roteiro.js` a partir de `demo/js/tour.js`. Não edite à mão.

## Colaborador

Colaborador: Carolina Fontes, analista sênior de vendas

1. **Seu Meu RH** (tela: Meu RH). Veja o resumo: gestora Patrícia Lemos, tempo de casa e o saldo de férias. O período 01/03/2025 a 28/02/2026 tem 30 dias e prazo concessivo até 28/02/2027.
2. **Salário protegido por FLS** (tela: Meu RH). O campo Salário aparece mascarado para você. Ele existe no cadastro, mas só os permission sets de RH o leem. Mais adiante, compare com a persona RH.
3. **Organograma privado** (tela: Organograma). Você enxerga apenas o seu cartão e a cadeia de gestores acima (Patrícia, Rodrigo e Helena). Colegas de equipe não aparecem: dado de pessoa é privado por padrão.
4. **Busca sem vazamento** (tela: Organograma). Digite "Lucas" na busca. Ele é seu colega de equipe e não aparece. Depois digite "Rodrigo": o diretor, que está na sua cadeia de gestores, aparece.
5. **Períodos aquisitivos** (tela: Férias, aba Minhas férias). Em Férias, cada período mostra direito, gozados, pendentes, abono e prazo. Períodos antigos já quitados ficam resumidos.
6. **Regra da CLT em ação** (tela: Férias, aba Minhas férias). Clique em "Começar numa sexta" e depois em "Verificar regras". O motor bloqueia: as férias não podem começar nos 2 dias antes do descanso semanal (art. 134, §3º). Teste também a fração de 4 dias e o abono de 11 dias.
7. **Pedido válido** (tela: Férias, aba Minhas férias). Clique em "Pedido válido" (14 dias a partir de 14/12/2026), verifique e envie. Há um aviso de conflito com o Lucas, que não impede o envio. O pedido segue para Patrícia.
8. **Acompanhe as etapas** (tela: Férias, aba Minhas férias). Em "Meus pedidos" o pedido mostra as duas etapas: gestora direta e RH. Para aprovar, troque para a persona Gestor (roteiro dela, passo 3).
9. **Metas e autoavaliação** (tela: Desempenho, aba Minha avaliação). Em Desempenho, suas metas somam 70%. O envio da autoavaliação é recusado até fechar 100%. Adicione uma meta de 30% e envie a autoavaliação com nota e comentários.
10. **Resultado só depois de liberado** (tela: Desempenho, aba Minha avaliação). A avaliação do seu gestor fica oculta até o RH calibrar e liberar o ciclo (roteiro do RH, passo 8). Depois de liberada, volte aqui e veja a nota final.

## Gestor

Gestor: Patrícia Lemos, coordenadora comercial

1. **Sua equipe** (tela: Meu RH). O início mostra a equipe direta com saldo de férias, próximas férias e alertas de prazo. Diego está em férias hoje.
2. **Subárvore visível** (tela: Organograma). No organograma você vê a sua equipe e a cadeia acima. Fernanda Rocha, de outra coordenação, não aparece. Alterne para "Lista": o salário está mascarado em todas as linhas.
3. **Aprovar férias** (tela: Aprovações). Em Aprovações está o pedido FE-000003 da Bruna. Aprove: ele segue para a etapa do RH. Se você enviou o pedido da Carolina no roteiro dela, ele também está aqui, com o aviso de conflito de equipe.
4. **Rejeição exige comentário** (tela: Aprovações). Clique em Rejeitar e tente confirmar sem escrever nada: a regra recusa. Com comentário, a rejeição encerra as demais etapas e o motivo fica visível para o solicitante.
5. **Calendário da equipe** (tela: Férias, aba Calendário da equipe). Em Férias, aba Calendário, navegue até dezembro de 2026. Lucas (aprovado) e Bruna (pendente) aparecem. Dias com duas ou mais ausências ficam destacados.
6. **Solicitar promoção** (tela: Promoções). Em Promoções, escolha Lucas Andrade e o cargo Analista Sênior (próximo da trilha). Você não vê nem informa salário. Envie a solicitação.
7. **Segunda etapa e atalho** (tela: Promoções). A primeira etapa é do gestor de segundo nível (Rodrigo), que não é uma persona. Use "Simular aprovação de Rodrigo" e depois siga para o RH (roteiro dele, passo 5).
8. **Vagas que você contrata** (tela: Recrutamento, aba Funil). Em Recrutamento você vê só a vaga Analista de Vendas Pleno, da sua área. Abra um cartão em entrevista, dê uma nota e mova entre as etapas de entrevista. Os cartões fora das etapas de entrevista ficam bloqueados para você.
9. **Avaliar a equipe** (tela: Desempenho, aba Minha equipe). Em Desempenho > Minha equipe, tente enviar a avaliação da Carolina agora: o ciclo está em autoavaliação e o envio é recusado. Peça ao RH para avançar a fase (roteiro dele, passo 8) e tente de novo.
10. **Onboarding da sua equipe** (tela: Onboarding). Gabriel Nakamura, contratado para a sua área, está em pré-admissão. Conclua as tarefas do Gestor. Ao tentar concluir uma tarefa do RH, a regra O5 recusa.

## RH

RH: Cláudia Rezende, analista de pessoas

1. **Painel do RH** (tela: Painel). KPIs e gráficos em SVG calculados sobre o estado atual: headcount por departamento, funil, avaliações e promoções. Volte aqui no final para ver os números mudarem.
2. **Visão completa e salário** (tela: Organograma). No organograma você vê a empresa inteira. Na Lista, a coluna Salário aparece de verdade para você (FLS liberado). Marque "Mostrar desligados" para ver Otávio.
3. **Etapa final das férias** (tela: Aprovações). Em Aprovações, o pedido FE-000005 da Fernanda já passou pelo gestor e aguarda o RH. Aprove: o status vira Aprovado.
4. **Prazos concessivos** (tela: Férias, aba Prazos concessivos). Em Férias > Prazos concessivos aparecem Priscila Vieira (prazo em 03/11/2026) e Rafael Brandão (01/12/2026). Mateus Pires perdeu o período por 35 faltas (art. 130).
5. **Salário fora da faixa** (tela: Promoções). Em Promoções, abra a solicitação do Henrique Dantas (Analista Sênior, faixa de R$ 8.000 a R$ 12.000, campo visível só para o RH). Informe 7.000 e tente aprovar: o sistema exige a justificativa da exceção.
6. **Aprovar e efetivar** (tela: Promoções). Corrija o salário para 8.800 (dentro da faixa) e aprove: a promoção fica aprovada para 16/11/2026. Use "Rodar a efetivação agora" para ver o histórico de cargos fechar o cargo antigo e abrir o novo.
7. **LGPD: retenção** (tela: Recrutamento, aba Retenção LGPD). Em Recrutamento > Retenção LGPD, dois candidatos estão parados há mais de 180 dias. Execute a rotina: nome, e-mail, telefone e cidade são apagados. O candidato contratado nunca é anonimizado.
8. **Ciclo de avaliação** (tela: Desempenho, aba Painel do ciclo). Em Desempenho, avance a fase do ciclo, calibre as notas enviadas pelos gestores e libere os resultados. Só então o colaborador vê a avaliação.
9. **Ativar a admissão** (tela: Onboarding). Em Onboarding, ative Gabriel Nakamura com a matrícula VTR-0041 e uma data de admissão diferente. As tarefas pendentes têm as datas recalculadas e ele entra no organograma.
10. **Feche o ciclo da demo** (tela: Painel). Volte ao Painel e veja o headcount e as avaliações atualizados. Use "Reiniciar demo" no topo para voltar ao estado inicial.

## Recrutador

Recrutador: Marcelo Ibrahim, recrutamento

1. **Funil da vaga** (tela: Recrutamento, aba Funil). O kanban mostra a vaga Analista de Vendas Pleno com uma coluna por etapa, nota e dias na etapa. Cartões parados há 7 dias ou mais ficam destacados.
2. **Transição inválida** (tela: Recrutamento, aba Funil). Arraste um cartão de Nova direto para Proposta. A máquina de etapas recusa: "Mudança de etapa não permitida: de Nova para Proposta."
3. **Alternativa por teclado** (tela: Recrutamento, aba Funil). Use o menu "Mover para" do cartão (acessível por teclado) para levar um candidato de Nova para Triagem. As colunas permitidas ficam destacadas durante o arraste.
4. **Reprovar exige motivo** (tela: Recrutamento, aba Funil). Mova um cartão para Reprovado: um diálogo pede o motivo, que é obrigatório. O candidato fica com o motivo no cartão.
5. **Proposta exige nota** (tela: Recrutamento, aba Funil). Leve Letícia Coutinho de Entrevista técnica para Proposta: a regra pede a nota de 0 a 5 antes de seguir.
6. **Histórico com dias na etapa** (tela: Recrutamento, aba Funil). Clique no nome de um candidato. A linha do tempo lista cada mudança de etapa e quantos dias ele ficou na anterior, além do consentimento LGPD.
7. **Contratar** (tela: Recrutamento, aba Funil). Mova Ricardo Sampaio de Proposta para Contratado. O sistema cria Ricardo em pré-admissão com plano de onboarding de 8 tarefas e o avisa na tela. Repetir o movimento não duplica.
8. **Gerir vagas** (tela: Recrutamento, aba Vagas). Em Vagas, pause, publique ou retire uma vaga do portal. Ao encerrar a vaga de logística, as candidaturas ativas são reprovadas com o histórico "Vaga encerrada".
9. **O portal público** (tela: Portal de vagas). Veja a pré-visualização do portal que o candidato usa. Só vagas Abertas e publicadas aparecem: logística e fiscal ficam de fora.
10. **Indicadores** (tela: Painel). No Painel, veja o funil de todas as vagas e o tempo médio por etapa. Indicadores de pessoas e salário não aparecem para o recrutador.

## Candidato

Candidato: visitante do portal, sem login

1. **Vagas abertas** (tela: Portal de vagas). A lista mostra só as vagas Abertas e publicadas no portal: duas. As demais vagas da empresa não vazam.
2. **Filtros** (tela: Portal de vagas). Filtre por modelo de trabalho (Remoto) ou busque por "sistemas". A contagem e os cartões atualizam na hora.
3. **Detalhe da vaga** (tela: Portal de vagas). Abra Analista de Vendas Pleno. A página mostra descrição, requisitos e o formulário, sem expor gestor, recrutador ou qualquer identificador interno.
4. **Consentimento LGPD** (tela: Portal de vagas). Tente enviar o formulário sem aceitar o termo de privacidade: o campo é marcado com erro e a candidatura não é enviada.
5. **Envie a candidatura** (tela: Portal de vagas). Preencha nome e e-mail, aceite o termo e envie. O envio precisa levar pelo menos 3 segundos desde que a página abriu (proteção contra robôs).
6. **Confirmação e bastidores** (tela: Portal de vagas). O candidato vê uma confirmação genérica. O painel "Nos bastidores" mostra que a candidatura entrou na etapa Nova, com origem Portal e o consentimento registrado.
7. **Veja no funil** (tela: Portal de vagas). Clique em "Ver no funil como Recrutador": a candidatura que você acabou de enviar está na coluna Nova do kanban, no mesmo estado compartilhado.
8. **Candidatura duplicada** (tela: Portal de vagas). Volte ao portal como Candidato e envie de novo para a mesma vaga com o mesmo e-mail: "Este candidato já se inscreveu nesta vaga." O mesmo e-mail em outra vaga reaproveita o cadastro do candidato.
9. **Defesa contra robôs** (tela: Portal de vagas). Abra "Como o portal se defende" e envie como robô: o visitante vê sucesso, mas o servidor descarta em silêncio. Envie rápido demais: o envio é rejeitado.
10. **Limite diário** (tela: Portal de vagas). Simule o limite diário: depois de 3 candidaturas no dia para o mesmo e-mail, o servidor responde "Limite diário de candidaturas atingido." e nada é gravado.
