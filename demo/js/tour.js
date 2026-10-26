/* RH Core demo: roteiro guiado, 10 passos por persona. Os textos descrevem o que a demonstracao realmente faz.
   O mesmo arquivo gera demo/ROTEIRO.md (node demo/tools/gen-roteiro.js). */
(function (g) {
  'use strict';
  var RH = (g.RH = g.RH || {});

  var TOURS = {
    colaborador: {
      title: 'Colaborador: Carolina Fontes, analista sênior de vendas',
      steps: [
        { title: 'Seu Meu RH', text: 'Veja o resumo: gestora Patrícia Lemos, tempo de casa e o saldo de férias. O período 01/03/2025 a 28/02/2026 tem 30 dias e prazo concessivo até 28/02/2027.', go: { view: 'home' } },
        { title: 'Salário protegido por FLS', text: 'O campo Salário aparece mascarado para você. Ele existe no cadastro, mas só os permission sets de RH o leem. Mais adiante, compare com a persona RH.', go: { view: 'home' } },
        { title: 'Organograma privado', text: 'Você enxerga apenas o seu cartão e a cadeia de gestores acima (Patrícia, Rodrigo e Helena). Colegas de equipe não aparecem: dado de pessoa é privado por padrão.', go: { view: 'org' } },
        { title: 'Busca sem vazamento', text: 'Digite "Lucas" na busca. Ele é seu colega de equipe e não aparece. Depois digite "Rodrigo": o diretor, que está na sua cadeia de gestores, aparece.', go: { view: 'org' } },
        { title: 'Períodos aquisitivos', text: 'Em Férias, cada período mostra direito, gozados, pendentes, abono e prazo. Períodos antigos já quitados ficam resumidos.', go: { view: 'leave', tab: 'mine' } },
        { title: 'Regra da CLT em ação', text: 'Clique em "Começar numa sexta" e depois em "Verificar regras". O motor bloqueia: as férias não podem começar nos 2 dias antes do descanso semanal (art. 134, §3º). Teste também a fração de 4 dias e o abono de 11 dias.', go: { view: 'leave', tab: 'mine' } },
        { title: 'Pedido válido', text: 'Clique em "Pedido válido" (14 dias a partir de 14/12/2026), verifique e envie. Há um aviso de conflito com o Lucas, que não impede o envio. O pedido segue para Patrícia.', go: { view: 'leave', tab: 'mine' } },
        { title: 'Acompanhe as etapas', text: 'Em "Meus pedidos" o pedido mostra as duas etapas: gestora direta e RH. Para aprovar, troque para a persona Gestor (roteiro dela, passo 3).', go: { view: 'leave', tab: 'mine' } },
        { title: 'Metas e autoavaliação', text: 'Em Desempenho, suas metas somam 70%. O envio da autoavaliação é recusado até fechar 100%. Adicione uma meta de 30% e envie a autoavaliação com nota e comentários.', go: { view: 'performance', tab: 'mine' } },
        { title: 'Resultado só depois de liberado', text: 'A avaliação do seu gestor fica oculta até o RH calibrar e liberar o ciclo (roteiro do RH, passo 8). Depois de liberada, volte aqui e veja a nota final.', go: { view: 'performance', tab: 'mine' } }
      ]
    },
    gestor: {
      title: 'Gestor: Patrícia Lemos, coordenadora comercial',
      steps: [
        { title: 'Sua equipe', text: 'O início mostra a equipe direta com saldo de férias, próximas férias e alertas de prazo. Diego está em férias hoje.', go: { view: 'home' } },
        { title: 'Subárvore visível', text: 'No organograma você vê a sua equipe e a cadeia acima. Fernanda Rocha, de outra coordenação, não aparece. Alterne para "Lista": o salário está mascarado em todas as linhas.', go: { view: 'org' } },
        { title: 'Aprovar férias', text: 'Em Aprovações está o pedido FE-000003 da Bruna. Aprove: ele segue para a etapa do RH. Se você enviou o pedido da Carolina no roteiro dela, ele também está aqui, com o aviso de conflito de equipe.', go: { view: 'approvals' } },
        { title: 'Rejeição exige comentário', text: 'Clique em Rejeitar e tente confirmar sem escrever nada: a regra recusa. Com comentário, a rejeição encerra as demais etapas e o motivo fica visível para o solicitante.', go: { view: 'approvals' } },
        { title: 'Calendário da equipe', text: 'Em Férias, aba Calendário, navegue até dezembro de 2026. Lucas (aprovado) e Bruna (pendente) aparecem. Dias com duas ou mais ausências ficam destacados.', go: { view: 'leave', tab: 'team' } },
        { title: 'Solicitar promoção', text: 'Em Promoções, escolha Lucas Andrade e o cargo Analista Sênior (próximo da trilha). Você não vê nem informa salário. Envie a solicitação.', go: { view: 'promotions' } },
        { title: 'Segunda etapa e atalho', text: 'A primeira etapa é do gestor de segundo nível (Rodrigo), que não é uma persona. Use "Simular aprovação de Rodrigo" e depois siga para o RH (roteiro dele, passo 5).', go: { view: 'promotions' } },
        { title: 'Vagas que você contrata', text: 'Em Recrutamento você vê só a vaga Analista de Vendas Pleno, da sua área. Abra um cartão em entrevista, dê uma nota e mova entre as etapas de entrevista. Os cartões fora das etapas de entrevista ficam bloqueados para você.', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Avaliar a equipe', text: 'Em Desempenho > Minha equipe, tente enviar a avaliação da Carolina agora: o ciclo está em autoavaliação e o envio é recusado. Peça ao RH para avançar a fase (roteiro dele, passo 8) e tente de novo.', go: { view: 'performance', tab: 'team' } },
        { title: 'Onboarding da sua equipe', text: 'Gabriel Nakamura, contratado para a sua área, está em pré-admissão. Conclua as tarefas do Gestor. Ao tentar concluir uma tarefa do RH, a regra O5 recusa.', go: { view: 'onboarding' } }
      ]
    },
    rh: {
      title: 'RH: Cláudia Rezende, analista de pessoas',
      steps: [
        { title: 'Painel do RH', text: 'KPIs e gráficos em SVG calculados sobre o estado atual: headcount por departamento, funil, avaliações e promoções. Volte aqui no final para ver os números mudarem.', go: { view: 'dashboard' } },
        { title: 'Visão completa e salário', text: 'No organograma você vê a empresa inteira. Na Lista, a coluna Salário aparece de verdade para você (FLS liberado). Marque "Mostrar desligados" para ver Otávio.', go: { view: 'org' } },
        { title: 'Etapa final das férias', text: 'Em Aprovações, o pedido FE-000005 da Fernanda já passou pelo gestor e aguarda o RH. Aprove: o status vira Aprovado.', go: { view: 'approvals' } },
        { title: 'Prazos concessivos', text: 'Em Férias > Prazos concessivos aparecem Priscila Vieira (prazo em 03/11/2026) e Rafael Brandão (01/12/2026). Mateus Pires perdeu o período por 35 faltas (art. 130).', go: { view: 'leave', tab: 'deadlines' } },
        { title: 'Salário fora da faixa', text: 'Em Promoções, abra a solicitação do Henrique Dantas (Analista Sênior, faixa de R$ 8.000 a R$ 12.000, campo visível só para o RH). Informe 7.000 e tente aprovar: o sistema exige a justificativa da exceção.', go: { view: 'promotions' } },
        { title: 'Aprovar e efetivar', text: 'Corrija o salário para 8.800 (dentro da faixa) e aprove: a promoção fica aprovada para 16/11/2026. Use "Rodar a efetivação agora" para ver o histórico de cargos fechar o cargo antigo e abrir o novo.', go: { view: 'promotions' } },
        { title: 'LGPD: retenção', text: 'Em Recrutamento > Retenção LGPD, dois candidatos estão parados há mais de 180 dias. Execute a rotina: nome, e-mail, telefone e cidade são apagados. O candidato contratado nunca é anonimizado.', go: { view: 'recruiting', tab: 'lgpd' } },
        { title: 'Ciclo de avaliação', text: 'Em Desempenho, avance a fase do ciclo, calibre as notas enviadas pelos gestores e libere os resultados. Só então o colaborador vê a avaliação.', go: { view: 'performance', tab: 'admin' } },
        { title: 'Ativar a admissão', text: 'Em Onboarding, ative Gabriel Nakamura com a matrícula VTR-0041 e uma data de admissão diferente. As tarefas pendentes têm as datas recalculadas e ele entra no organograma.', go: { view: 'onboarding' } },
        { title: 'Feche o ciclo da demo', text: 'Volte ao Painel e veja o headcount e as avaliações atualizados. Use "Reiniciar demo" no topo para voltar ao estado inicial.', go: { view: 'dashboard' } }
      ]
    },
    recrutador: {
      title: 'Recrutador: Marcelo Ibrahim, recrutamento',
      steps: [
        { title: 'Funil da vaga', text: 'O kanban mostra a vaga Analista de Vendas Pleno com uma coluna por etapa, nota e dias na etapa. Cartões parados há 7 dias ou mais ficam destacados.', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Transição inválida', text: 'Arraste um cartão de Nova direto para Proposta. A máquina de etapas recusa: "Mudança de etapa não permitida: de Nova para Proposta."', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Alternativa por teclado', text: 'Use o menu "Mover para" do cartão (acessível por teclado) para levar um candidato de Nova para Triagem. As colunas permitidas ficam destacadas durante o arraste.', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Reprovar exige motivo', text: 'Mova um cartão para Reprovado: um diálogo pede o motivo, que é obrigatório. O candidato fica com o motivo no cartão.', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Proposta exige nota', text: 'Leve Letícia Coutinho de Entrevista técnica para Proposta: a regra pede a nota de 0 a 5 antes de seguir.', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Histórico com dias na etapa', text: 'Clique no nome de um candidato. A linha do tempo lista cada mudança de etapa e quantos dias ele ficou na anterior, além do consentimento LGPD.', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Contratar', text: 'Mova Ricardo Sampaio de Proposta para Contratado. O sistema cria Ricardo em pré-admissão com plano de onboarding de 8 tarefas e o avisa na tela. Repetir o movimento não duplica.', go: { view: 'recruiting', tab: 'board', job: 'JOB-1' } },
        { title: 'Gerir vagas', text: 'Em Vagas, pause, publique ou retire uma vaga do portal. Ao encerrar a vaga de logística, as candidaturas ativas são reprovadas com o histórico "Vaga encerrada".', go: { view: 'recruiting', tab: 'jobs' } },
        { title: 'O portal público', text: 'Veja a pré-visualização do portal que o candidato usa. Só vagas Abertas e publicadas aparecem: logística e fiscal ficam de fora.', go: { view: 'portal' } },
        { title: 'Indicadores', text: 'No Painel, veja o funil de todas as vagas e o tempo médio por etapa. Indicadores de pessoas e salário não aparecem para o recrutador.', go: { view: 'dashboard' } }
      ]
    },
    candidato: {
      title: 'Candidato: visitante do portal, sem login',
      steps: [
        { title: 'Vagas abertas', text: 'A lista mostra só as vagas Abertas e publicadas no portal: duas. As demais vagas da empresa não vazam.', go: { view: 'portal' } },
        { title: 'Filtros', text: 'Filtre por modelo de trabalho (Remoto) ou busque por "sistemas". A contagem e os cartões atualizam na hora.', go: { view: 'portal' } },
        { title: 'Detalhe da vaga', text: 'Abra Analista de Vendas Pleno. A página mostra descrição, requisitos e o formulário, sem expor gestor, recrutador ou qualquer identificador interno.', go: { view: 'portal' } },
        { title: 'Consentimento LGPD', text: 'Tente enviar o formulário sem aceitar o termo de privacidade: o campo é marcado com erro e a candidatura não é enviada.', go: { view: 'portal' } },
        { title: 'Envie a candidatura', text: 'Preencha nome e e-mail, aceite o termo e envie. O envio precisa levar pelo menos 3 segundos desde que a página abriu (proteção contra robôs).', go: { view: 'portal' } },
        { title: 'Confirmação e bastidores', text: 'O candidato vê uma confirmação genérica. O painel "Nos bastidores" mostra que a candidatura entrou na etapa Nova, com origem Portal e o consentimento registrado.', go: { view: 'portal' } },
        { title: 'Veja no funil', text: 'Clique em "Ver no funil como Recrutador": a candidatura que você acabou de enviar está na coluna Nova do kanban, no mesmo estado compartilhado.', go: { view: 'portal' } },
        { title: 'Candidatura duplicada', text: 'Volte ao portal como Candidato e envie de novo para a mesma vaga com o mesmo e-mail: "Este candidato já se inscreveu nesta vaga." O mesmo e-mail em outra vaga reaproveita o cadastro do candidato.', go: { view: 'portal' } },
        { title: 'Defesa contra robôs', text: 'Abra "Como o portal se defende" e envie como robô: o visitante vê sucesso, mas o servidor descarta em silêncio. Envie rápido demais: o envio é rejeitado.', go: { view: 'portal' } },
        { title: 'Limite diário', text: 'Simule o limite diário: depois de 3 candidaturas no dia para o mesmo e-mail, o servidor responde "Limite diário de candidaturas atingido." e nada é gravado.', go: { view: 'portal' } }
      ]
    }
  };

  RH.tour = { TOURS: TOURS };
  if (typeof module !== 'undefined' && module.exports) module.exports = RH.tour;
})(globalThis);
