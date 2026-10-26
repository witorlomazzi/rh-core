@IsTest
private class CandidateServiceTest {
    private static CandidateService.CandidateInput input(String name, String email) {
        CandidateService.CandidateInput i = new CandidateService.CandidateInput();
        i.name = name;
        i.email = email;
        return i;
    }

    @IsTest
    static void normalizeEmailLowercasesAndRemovesSpaces() {
        Assert.areEqual('maria.silva@exemplo.com', CandidateService.normalizeEmail('  Maria.Silva @Exemplo.COM '));
        Assert.isNull(CandidateService.normalizeEmail(null));
        Assert.isNull(CandidateService.normalizeEmail('   '));
    }

    @IsTest
    static void triggerNormalizesEmailAndSetsDefaults() {
        Candidate__c c = RecruitingTestData.candidate('trg');
        Candidate__c reloaded = RecruitingTestData.reloadCandidate(c.Id);
        Assert.areEqual(CandidateService.normalizeEmail(c.Email__c), reloaded.Email_Normalized__c);
        Assert.areEqual(Date.today(), reloaded.Last_Activity_Date__c);
        Assert.areEqual(RecruitingQueue.id(), reloaded.OwnerId, 'Dono e a fila de recrutamento');
        Assert.isNotNull(RecruitingQueue.id());

        reloaded.Email__c = 'Novo.Email@Zztest.Example.com';
        update reloaded;
        Assert.areEqual('novo.email@zztest.example.com', RecruitingTestData.reloadCandidate(c.Id).Email_Normalized__c);
    }

    @IsTest
    static void duplicateNormalizedEmailIsRejectedByUniqueness() {
        Candidate__c first = RecruitingTestData.candidate('dup');
        Candidate__c second = new Candidate__c(Name = 'ZZTEST-Outro', Email__c = first.Email__c.toUpperCase());
        try {
            insert second;
            Assert.fail('E-mail normalizado repetido deve falhar');
        } catch (DmlException e) {
            Assert.areEqual(StatusCode.DUPLICATE_VALUE, e.getDmlType(0), e.getMessage());
        }
    }

    @IsTest
    static void upsertCreatesNewCandidateWithConsent() {
        CandidateService.CandidateInput i = input('ZZTEST-Ana Souza', 'ZZTEST.Ana@Exemplo.com');
        i.phone = '(11) 99999-0000';
        i.city = 'Sao Paulo';
        i.source = 'Portal';
        i.consentGiven = true;
        Candidate__c created = CandidateService.upsertByEmail(i);
        Candidate__c reloaded = RecruitingTestData.reloadCandidate(created.Id);
        Assert.areEqual('zztest.ana@exemplo.com', reloaded.Email_Normalized__c);
        Assert.areEqual('(11) 99999-0000', reloaded.Phone__c);
        Assert.isTrue(reloaded.Consent_Given__c);
        Assert.isNotNull(reloaded.Consent_Date__c);
        Assert.areEqual(HrSettings.get().Consent_Text_Version__c, reloaded.Consent_Text_Version__c);
    }

    @IsTest
    static void upsertReusesExistingCandidateAndKeepsTheirData() {
        CandidateService.CandidateInput first = input('ZZTEST-Bruno Lima', 'zztest.bruno@exemplo.com');
        first.phone = '(21) 98888-1111';
        Candidate__c created = CandidateService.upsertByEmail(first);
        RecruitingTestData.ageCandidate(created.Id, 30);

        CandidateService.CandidateInput second = input('ZZTEST-Outro Nome', ' ZZTEST.Bruno@Exemplo.com ');
        second.phone = '(99) 90000-0000';
        second.city = 'Niteroi';
        second.consentGiven = true;
        second.consentTextVersion = '2099-01';
        Candidate__c reused = CandidateService.upsertByEmail(second);

        Assert.areEqual(created.Id, reused.Id, 'Mesma pessoa, mesmo registro');
        Assert.areEqual(1, [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c = 'zztest.bruno@exemplo.com']);
        Candidate__c reloaded = RecruitingTestData.reloadCandidate(created.Id);
        Assert.areEqual('(21) 98888-1111', reloaded.Phone__c, 'Dado existente nao e sobrescrito');
        Assert.areEqual('ZZTEST-Bruno Lima', reloaded.Name);
        Assert.areEqual('Niteroi', reloaded.City__c, 'Campo vazio e preenchido');
        Assert.isTrue(reloaded.Consent_Given__c);
        Assert.areEqual('2099-01', reloaded.Consent_Text_Version__c);
        Assert.areEqual(Date.today(), reloaded.Last_Activity_Date__c, 'Ultima atividade renovada');
    }

    @IsTest
    static void upsertBulkMergesRepeatedEmails() {
        List<CandidateService.CandidateInput> inputs = new List<CandidateService.CandidateInput>();
        for (Integer i = 0; i < 50; i++) {
            inputs.add(input('ZZTEST-Lote ' + i, 'zztest.lote' + i + '@exemplo.com'));
        }
        inputs.add(input('ZZTEST-Lote Repetido', 'ZZTEST.LOTE0@exemplo.com'));
        Map<String, Candidate__c> result = CandidateService.upsertByEmail(inputs);
        Assert.areEqual(50, result.size());
        Assert.areEqual(50, [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c LIKE 'zztest.lote%']);
    }

    @IsTest
    static void upsertValidatesNameAndEmail() {
        for (CandidateService.CandidateInput bad : new List<CandidateService.CandidateInput>{
            input(null, 'a@b.com'),
            input('ZZTEST-Sem email', null),
            input('ZZTEST-Email ruim', 'sem-arroba'),
            input('ZZTEST-Email ruim', 'a@b')
        }) {
            try {
                CandidateService.upsertByEmail(bad);
                Assert.fail('Entrada invalida deve falhar');
            } catch (JobApplicationService.RecruitingException e) {
                Assert.isTrue(e.getMessage().startsWith('Informe'), e.getMessage());
            }
        }
        try {
            CandidateService.upsertByEmail(new List<CandidateService.CandidateInput>{ null });
            Assert.fail('Entrada nula deve falhar');
        } catch (JobApplicationService.RecruitingException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void anonymizeClearsPersonalDataButKeepsActiveCandidates() {
        Job_Opening__c opening = RecruitingTestData.opening('Anon', null, 'Aberta');
        Candidate__c idle = RecruitingTestData.buildCandidate('idle');
        idle.Phone__c = '(11) 90000-0000';
        idle.City__c = 'Campinas';
        idle.LinkedIn_URL__c = 'https://linkedin.example.com/in/zztest';
        insert idle;
        RecruitingTestData.useRecorder();
        List<Candidate__c> others = RecruitingTestData.candidates('o', 3);
        Candidate__c active = others[0];
        Candidate__c hired = others[1];
        Candidate__c rejected = others[2];
        List<Job_Application__c> apps = RecruitingTestData.applications(others, opening.Id);
        Job_Application__c activeApp = apps[0];
        Job_Application__c hiredApp = apps[1];
        Job_Application__c rejectedApp = apps[2];
        RecruitingTestData.advanceTo(hiredApp.Id, 'Contratado');
        update new Job_Application__c(Id = rejectedApp.Id, Cover_Letter__c = 'Mensagem pessoal do candidato');
        update new Job_Application__c(Id = rejectedApp.Id, Stage__c = 'Reprovado', Rejection_Reason__c = 'Perfil');

        Integer done = CandidateService.anonymize(new Set<Id>{ idle.Id, active.Id, hired.Id, rejected.Id });

        Assert.areEqual(2, done, 'Sem candidatura (idle) e so reprovado');
        Candidate__c anon = RecruitingTestData.reloadCandidate(idle.Id);
        Assert.areEqual('Candidato anonimizado', anon.Name);
        Assert.areEqual(('anon-' + idle.Id + '@anon.invalid').toLowerCase(), anon.Email__c);
        Assert.areEqual(anon.Email__c, anon.Email_Normalized__c);
        Assert.isNull(anon.Phone__c);
        Assert.isNull(anon.LinkedIn_URL__c);
        Assert.isNull(anon.City__c);
        Assert.isTrue(anon.Anonymized__c);
        Assert.isNotNull(anon.Anonymized_Date__c);

        Assert.isFalse(RecruitingTestData.reloadCandidate(active.Id).Anonymized__c, 'Candidatura ativa protege');
        Assert.isFalse(RecruitingTestData.reloadCandidate(hired.Id).Anonymized__c, 'Contratado nunca e anonimizado');
        Assert.isTrue(RecruitingTestData.reloadCandidate(rejected.Id).Anonymized__c);
        Assert.isNull(RecruitingTestData.reloadApplication(rejectedApp.Id).Cover_Letter__c, 'Mensagem apagada');
        Assert.areEqual(0, CandidateService.anonymize(new Set<Id>{ idle.Id }), 'Ja anonimizado nao repete');
        Assert.areEqual(0, CandidateService.anonymize(new Set<Id>()));
        Assert.areEqual(0, CandidateService.anonymize(null));
        Assert.isNotNull(activeApp.Id);
    }

    @IsTest
    static void anonymizedCandidateKeepsEmailEvenWhenUpdated() {
        Candidate__c c = RecruitingTestData.candidate('keep');
        CandidateService.anonymize(new Set<Id>{ c.Id });
        Candidate__c anon = RecruitingTestData.reloadCandidate(c.Id);
        anon.Source__c = 'Outro';
        update anon;
        Candidate__c again = RecruitingTestData.reloadCandidate(c.Id);
        Assert.areEqual(again.Email__c, again.Email_Normalized__c);
    }
}
