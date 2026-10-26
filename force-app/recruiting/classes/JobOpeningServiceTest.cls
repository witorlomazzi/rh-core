@IsTest
private class JobOpeningServiceTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    @IsTest
    static void slugifyRemovesAccentsAndSymbols() {
        Assert.areEqual('analista-de-sistemas-sr', JobOpeningService.slugify('Analista de Sistemas (Sr.)'));
        Assert.areEqual('coordenacao-de-producao-e-logistica', JobOpeningService.slugify('Coordenação de Produção e Logística'));
        Assert.areEqual('auxiliar-de-estoque', JobOpeningService.slugify('  --Auxiliar   de ESTOQUE!!  '));
        Assert.areEqual('vaga', JobOpeningService.slugify('@@@ !!!'));
        Assert.areEqual('vaga', JobOpeningService.slugify(null));
        Assert.areEqual('vaga', JobOpeningService.slugify(''));
        String longSlug = JobOpeningService.slugify('a'.repeat(60) + ' ' + 'b'.repeat(60));
        Assert.isTrue(longSlug.length() <= 70, 'Limite da base do identificador: ' + longSlug.length());
        Assert.isFalse(longSlug.endsWith('-'));
    }

    @IsTest
    static void repeatedTitlesGetNumericSuffix() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c first = RecruitingTestData.opening('Analista Fiscal', t.mgr1.Id, 'Rascunho');
        Job_Opening__c second = RecruitingTestData.opening('Analista Fiscal', t.mgr1.Id, 'Rascunho');
        Job_Opening__c third = RecruitingTestData.opening('Analista Fiscal', t.mgr1.Id, 'Rascunho');
        Assert.areEqual('zztest-analista-fiscal', first.Public_Slug__c);
        Assert.areEqual('zztest-analista-fiscal-2', second.Public_Slug__c);
        Assert.areEqual('zztest-analista-fiscal-3', third.Public_Slug__c);
    }

    @IsTest
    static void repeatedTitlesInTheSameBatchAreUnique() {
        List<Job_Opening__c> batch = new List<Job_Opening__c>();
        for (Integer i = 0; i < 5; i++) {
            batch.add(new Job_Opening__c(Name = 'ZZTEST-Lote Igual', Status__c = 'Rascunho'));
        }
        insert batch;
        Set<String> slugs = new Set<String>();
        for (Job_Opening__c o : [SELECT Public_Slug__c FROM Job_Opening__c WHERE Name = 'ZZTEST-Lote Igual']) {
            slugs.add(o.Public_Slug__c);
        }
        Assert.areEqual(5, slugs.size(), 'Cinco identificadores distintos');
        Assert.isTrue(slugs.contains('zztest-lote-igual'));
        Assert.isTrue(slugs.contains('zztest-lote-igual-5'));
    }

    @IsTest
    static void slugStaysStableWhenTitleChanges() {
        Job_Opening__c o = RecruitingTestData.opening('Titulo Original', null, 'Rascunho');
        String slug = o.Public_Slug__c;
        o.Name = 'ZZTEST-Titulo Novo';
        update o;
        Assert.areEqual(slug, RecruitingTestData.reloadOpening(o.Id).Public_Slug__c, 'A URL publica nao muda');
    }

    @IsTest
    static void statusDatesFollowTheLifecycle() {
        Job_Opening__c draft = RecruitingTestData.opening('Datas', null, 'Rascunho');
        Assert.isNull(draft.Opened_Date__c);
        Assert.areEqual(0, draft.Applications_Count__c);

        draft.Status__c = 'Aberta';
        update draft;
        Assert.areEqual(Date.today(), RecruitingTestData.reloadOpening(draft.Id).Opened_Date__c);

        draft.Status__c = 'Fechada';
        update draft;
        Job_Opening__c closed = RecruitingTestData.reloadOpening(draft.Id);
        Assert.areEqual(Date.today(), closed.Closed_Date__c);

        closed.Status__c = 'Pausada';
        update closed;
        Assert.isNull(RecruitingTestData.reloadOpening(draft.Id).Closed_Date__c, 'Reabrir limpa o encerramento');

        Job_Opening__c openAtBirth = RecruitingTestData.opening('Ja Aberta', null, 'Aberta');
        Assert.areEqual(Date.today(), openAtBirth.Opened_Date__c);
        Job_Opening__c cancelled = RecruitingTestData.opening('Cancelada', null, 'Cancelada');
        Assert.areEqual(Date.today(), cancelled.Closed_Date__c);
    }

    @IsTest
    static void closingTheOpeningRejectsActiveApplications() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Job_Opening__c opening = RecruitingTestData.opening('Encerrar', t.mgr1.Id, 'Aberta');
        List<Job_Application__c> apps = RecruitingTestData.applications(RecruitingTestData.candidates('enc', 4), opening.Id);
        Job_Application__c nova = apps[0];
        Job_Application__c proposta = apps[1];
        Job_Application__c hired = apps[2];
        Job_Application__c quit = apps[3];
        RecruitingTestData.advanceTo(proposta.Id, 'Proposta');
        RecruitingTestData.advanceTo(hired.Id, 'Contratado');
        update new Job_Application__c(Id = quit.Id, Stage__c = 'Desistiu');

        Test.startTest();
        opening.Status__c = 'Fechada';
        update opening;
        Test.stopTest();

        Job_Application__c rejectedNova = RecruitingTestData.reloadApplication(nova.Id);
        Assert.areEqual('Reprovado', rejectedNova.Stage__c);
        Assert.areEqual('Outro', rejectedNova.Rejection_Reason__c);
        List<Application_Stage_History__c> history = RecruitingTestData.history(nova.Id);
        Assert.areEqual('Vaga encerrada', history[history.size() - 1].Note__c);
        Assert.areEqual('Reprovado', history[history.size() - 1].To_Stage__c);
        Assert.areEqual('Reprovado', RecruitingTestData.reloadApplication(proposta.Id).Stage__c);
        Assert.areEqual('Contratado', RecruitingTestData.reloadApplication(hired.Id).Stage__c, 'Terminal nao muda');
        Assert.areEqual('Desistiu', RecruitingTestData.reloadApplication(quit.Id).Stage__c, 'Terminal nao muda');
    }

    @IsTest
    static void cancellingTheOpeningAlsoRejectsApplications() {
        Job_Opening__c opening = RecruitingTestData.opening('Cancelar', null, 'Aberta');
        Job_Application__c app = RecruitingTestData.application(RecruitingTestData.candidate('canc').Id, opening.Id);
        opening.Status__c = 'Cancelada';
        update opening;
        Assert.areEqual('Reprovado', RecruitingTestData.reloadApplication(app.Id).Stage__c);
    }

    @IsTest
    static void applicationCountFollowsInsertDeleteAndUndelete() {
        Job_Opening__c opening = RecruitingTestData.opening('Contagem', null, 'Aberta');
        List<Job_Application__c> apps = RecruitingTestData.applications(RecruitingTestData.candidates('c', 3), opening.Id);
        Assert.areEqual(3, RecruitingTestData.reloadOpening(opening.Id).Applications_Count__c);

        delete apps[0];
        Assert.areEqual(2, RecruitingTestData.reloadOpening(opening.Id).Applications_Count__c);

        undelete apps[0];
        Assert.areEqual(3, RecruitingTestData.reloadOpening(opening.Id).Applications_Count__c);

        JobOpeningService.refreshApplicationCounts(new Set<Id>());
        JobOpeningService.refreshApplicationCounts(new Set<Id>{ null });
    }

    @IsTest
    static void movingAnApplicationBetweenOpeningsUpdatesBothCounts() {
        Job_Opening__c a = RecruitingTestData.opening('Origem', null, 'Aberta');
        Job_Opening__c b = RecruitingTestData.opening('Destino', null, 'Aberta');
        Job_Application__c app = RecruitingTestData.application(RecruitingTestData.candidate('mov').Id, a.Id);
        app.Job_Opening__c = b.Id;
        update app;
        Assert.areEqual(0, RecruitingTestData.reloadOpening(a.Id).Applications_Count__c);
        Assert.areEqual(1, RecruitingTestData.reloadOpening(b.Id).Applications_Count__c);
        Assert.areEqual(String.valueOf(app.Candidate__c) + '|' + String.valueOf(b.Id), RecruitingTestData.reloadApplication(app.Id).Unique_Key__c);
    }
}
