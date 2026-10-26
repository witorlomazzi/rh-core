// RH Core, dados de demonstracao da Vetra Distribuidora (empresa ficticia). Fase 5: avaliacao de desempenho.
// Projeto demonstrativo, empresa e dados ficticios. Nenhum dado real.
//
// Cria o "Ciclo 2026" e o leva para a fase "Avaliacao do gestor" pelos proprios servicos do modulo
// (ReviewCycleService): avaliacao do gestor e autoavaliacao para os 39 colaboradores ativos, 3 metas por pessoa somando
// 100% e metade das autoavaliacoes enviadas. Algumas avaliacoes do gestor ficam Em_Andamento e Enviada para o
// relatorio por status ter varias barras; a equipe da Patricia (usuario admin) fica Pendente para a demonstracao
// do gestor. As gravacoes de situacao usam o modo "confiavel" dos servicos (beginTrusted), que existe para o
// lancamento do ciclo e pula as travas de quem edita, porque aqui a carga representa o historico ja ocorrido.
// Idempotente: se o ciclo "Ciclo 2026" ja existe, nada e alterado (o ciclo pode ter avancado na demonstracao).
// Pre-requisitos: fases 1 a 4. O usuario que executa precisa do acesso de RH (HR_Admin_Access).

List<Review_Cycle__c> existingCycle = [SELECT Id, Status__c FROM Review_Cycle__c WHERE Name = 'Ciclo 2026' LIMIT 1];
if (!existingCycle.isEmpty()) {
    System.debug('Fase 5: o Ciclo 2026 ja existe (' + existingCycle[0].Status__c + '); nada a fazer.');
    return;
}

List<Employee__c> employees = [
    SELECT Id, Name, Manager__c, User__c, Employee_Number__c, Department__r.Code__c
    FROM Employee__c
    WHERE Employee_Number__c LIKE 'VTR-%' AND Status__c IN ('Ativo', 'Ferias')
    ORDER BY Employee_Number__c
];
if (employees.isEmpty()) {
    throw new CalloutException('Rode antes a fase 1 (estrutura).');
}

Review_Cycle__c cycle = new Review_Cycle__c(
    Name = 'Ciclo 2026', Start_Date__c = Date.newInstance(2026, 1, 1), End_Date__c = Date.newInstance(2026, 12, 31),
    Self_Review_Due__c = Date.newInstance(2026, 11, 6), Manager_Review_Due__c = Date.newInstance(2026, 11, 20),
    Rating_Scale_Max__c = 5, Status__c = 'Planejado'
);
insert cycle;

// 1. Avaliacao do gestor (Pendente) e autoavaliacao por colaborador, como no lancamento real.
ReviewCycleService.LaunchResult launched = new ReviewCycleService.LaunchResult();
ReviewCycleService.createRecords(cycle, employees, launched);
ReviewCycleService.completeLaunch(cycle.Id);

// 2. Tres metas por pessoa (40, 30 e 30 por cento), por departamento.
Map<String, List<String>> goalNames = new Map<String, List<String>>{
    'COM' => new List<String>{ 'Atingir a meta trimestral de receita', 'Ampliar a carteira de clientes ativos', 'Manter o CRM atualizado' },
    'OPL' => new List<String>{ 'Reduzir o tempo médio de separação de pedidos', 'Manter a acuracidade de estoque acima de 98%', 'Cumprir o plano de entregas no prazo' },
    'FIN' => new List<String>{ 'Fechar o mês contábil até o 5º dia útil', 'Reduzir pendências de conciliação', 'Automatizar um relatório recorrente' },
    'PES' => new List<String>{ 'Reduzir o tempo médio de contratação', 'Concluir o plano de treinamento do trimestre', 'Acompanhar os indicadores de clima' },
    'TEC' => new List<String>{ 'Entregar as histórias priorizadas do trimestre', 'Manter a cobertura de testes acima de 85%', 'Reduzir chamados recorrentes' },
    'DIR' => new List<String>{ 'Cumprir o plano estratégico do ano', 'Desenvolver sucessores', 'Acompanhar o orçamento da área' }
};
List<Integer> weights = new List<Integer>{ 40, 30, 30 };
List<String> targets = new List<String>{ '100% da meta', '90% de adesão', 'Sem pendências' };
List<String> strengths = new List<String>{
    'Boa comunicação com a equipe e com clientes.', 'Entrega com qualidade e dentro do prazo.',
    'Toma iniciativa e propõe melhorias.', 'Organização e atenção aos detalhes.'
};
List<String> improvements = new List<String>{
    'Delegar mais e documentar decisões.', 'Planejar melhor as prioridades da semana.',
    'Aprofundar conhecimento técnico da área.', 'Dar feedback com mais frequência.'
};
List<Goal__c> goals = new List<Goal__c>();
Map<Id, Integer> numberOf = new Map<Id, Integer>();
for (Employee__c e : employees) {
    Integer num = Integer.valueOf(e.Employee_Number__c.substring(4));
    numberOf.put(e.Id, num);
    List<String> names = goalNames.get(e.Department__r.Code__c);
    Boolean sent = Math.mod(num, 2) == 0 || e.Employee_Number__c == 'VTR-0015';
    for (Integer i = 0; i < 3; i++) {
        goals.add(new Goal__c(
            Name = names[i], Employee__c = e.Id, Review_Cycle__c = cycle.Id, Weight__c = weights[i], Target__c = targets[i],
            Status__c = 'Ativa', Self_Score__c = sent ? 3 + Math.mod(num + i, 3) : null
        ));
    }
}
insert goals;

// 3. Metade das autoavaliacoes enviadas (matricula par, mais a Carolina, persona de colaboradora).
List<Self_Assessment__c> assessments = [
    SELECT Id, Employee__c, Employee__r.Employee_Number__c FROM Self_Assessment__c WHERE Review_Cycle__c = :cycle.Id
];
List<Self_Assessment__c> toSend = new List<Self_Assessment__c>();
for (Self_Assessment__c sa : assessments) {
    Integer num = numberOf.get(sa.Employee__c);
    if (Math.mod(num, 2) == 0 || sa.Employee__r.Employee_Number__c == 'VTR-0015') {
        sa.Self_Rating__c = 3 + Math.mod(num, 3);
        sa.Strengths__c = strengths[Math.mod(num, 4)];
        sa.Improvements__c = improvements[Math.mod(num, 4)];
        sa.Submitted__c = true;
        sa.Submitted_Date__c = Datetime.newInstance(Date.newInstance(2026, 10, 14 + Math.mod(num, 10)), Time.newInstance(15, 0, 0, 0));
        toSend.add(sa);
    }
}
SelfAssessmentService.beginTrusted();
try {
    update toSend;
} finally {
    SelfAssessmentService.endTrusted();
}

// 4. O ciclo passa para a avaliacao do gestor.
ReviewCycleService.advance(cycle.Id);

// 5. Avaliacoes do gestor em andamento: matricula multipla de 4 enviada, final 2 em andamento; a equipe da Patricia
// (VTR-0015 a VTR-0018) fica Pendente para a persona Gestor.
List<Performance_Review__c> reviews = [
    SELECT Id, Employee__c, Employee__r.Employee_Number__c, Reviewer__c FROM Performance_Review__c WHERE Review_Cycle__c = :cycle.Id
];
List<String> comments = new List<String>{
    'Entrega consistente no ciclo e boa relação com o time.', 'Superou as metas e ajudou a treinar colegas.',
    'Cumpriu o combinado; pode ganhar mais autonomia.', 'Resultado dentro do esperado, com espaço para evoluir em planejamento.'
};
List<Performance_Review__c> updates = new List<Performance_Review__c>();
for (Performance_Review__c r : reviews) {
    Integer num = numberOf.get(r.Employee__c);
    if (num >= 15 && num <= 18) {
        continue;
    }
    if (Math.mod(num, 4) == 0) {
        updates.add(new Performance_Review__c(
            Id = r.Id, Status__c = 'Enviada', Manager_Rating__c = 3 + Math.mod(num, 3), Manager_Comments__c = comments[Math.mod(num, 4)]
        ));
    } else if (Math.mod(num, 4) == 2) {
        updates.add(new Performance_Review__c(
            Id = r.Id, Status__c = 'Em_Andamento', Manager_Rating__c = 3 + Math.mod(num, 2), Manager_Comments__c = comments[Math.mod(num, 4)]
        ));
    }
}
PerformanceReviewService.beginTrusted();
try {
    update updates;
} finally {
    PerformanceReviewService.endTrusted();
}

System.debug('Fase 5: ciclo ' + cycle.Name + ' (Avaliacao_Gestor), avaliacoes ' + launched.reviewsCreated + ', autoavaliacoes '
    + launched.selfAssessmentsCreated + ', metas ' + goals.size() + ', enviadas ' + toSend.size() + ', avaliacoes alteradas ' + updates.size());
