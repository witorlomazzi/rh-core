/**
 * Testes do portal publico (spec 14, G1 a G3). As chamadas rodam como um usuario sem nenhuma permissao de objeto,
 * apenas com o permission set HR_Portal_Guest: prova que o controller (without sharing) funciona para quem nao
 * tem acesso a dados, que e a situacao do usuario convidado do site. Dados com prefixo ZZTEST-.
 */
@IsTest
private class JobPortalControllerTest {
    private static final String ALIAS = 'zzguest';

    @TestSetup
    static void setup() {
        HrTestDataFactory.userWithPermissionSets(ALIAS, new List<String>{ 'HR_Portal_Guest' });
        Department__c dept = HrTestDataFactory.department();
        List<Job_Opening__c> openings = new List<Job_Opening__c>{
            opening('Analista Fiscal', 'Aberta', true, dept.Id, 'Remoto'),
            opening('Analista de Logistica', 'Aberta', true, dept.Id, 'Presencial'),
            opening('Oculta do portal', 'Aberta', false, dept.Id, 'Hibrido'),
            opening('Rascunho publicado', 'Rascunho', true, dept.Id, 'Remoto'),
            opening('Vaga encerrada', 'Fechada', true, dept.Id, 'Remoto')
        };
        insert openings;
    }

    private static Job_Opening__c opening(String title, String status, Boolean publish, Id deptId, String model) {
        return new Job_Opening__c(
            Name = 'ZZTEST-' + title,
            Status__c = status,
            Publish_On_Portal__c = publish,
            Department__c = deptId,
            Location__c = 'Sao Paulo',
            Work_Model__c = model,
            Employment_Type__c = 'CLT',
            Description__c = '<p>Descricao da vaga</p>',
            Requirements__c = '<ul><li>Requisito</li></ul>',
            Openings_Count__c = 1
        );
    }

    private static User guest() {
        return [SELECT Id FROM User WHERE Alias = :ALIAS AND FirstName = 'ZZTEST' LIMIT 1];
    }

    private static String slugOf(String title) {
        return [SELECT Public_Slug__c FROM Job_Opening__c WHERE Name = :('ZZTEST-' + title) LIMIT 1].Public_Slug__c;
    }

    private static PortalApplicationInput input(String slug, String email) {
        PortalApplicationInput i = new PortalApplicationInput();
        i.slug = slug;
        i.name = 'ZZTEST-Maria Souza';
        i.email = email;
        i.phone = '(11) 91234-5678';
        i.city = 'Sao Paulo';
        i.linkedInUrl = 'https://www.linkedin.com/in/zztest-maria';
        i.message = 'Tenho interesse na vaga.';
        i.consent = true;
        i.website = '';
        i.renderedAt = String.valueOf(Datetime.now().getTime() - 10000);
        return i;
    }

    private static JobPortalController.SubmitResult send(PortalApplicationInput data) {
        return JobPortalController.submitApplication(JSON.serialize(data));
    }

    private static void overrideSettings(Map<String, Object> changes) {
        Map<String, Object> values = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(HrSettings.get()));
        values.putAll(changes);
        HrSettings.testOverride = (HR_Setting__mdt) JSON.deserialize(JSON.serialize(values), HR_Setting__mdt.class);
    }

    @IsTest
    static void guestHasNoObjectAccessButListsOnlyEligibleJobs() {
        List<PortalJobDto> jobs;
        System.runAs(guest()) {
            System.assertEquals(false, Schema.sObjectType.Job_Opening__c.isAccessible(), 'convidado nao le vagas');
            System.assertEquals(false, Schema.sObjectType.Candidate__c.isCreateable(), 'convidado nao cria candidato');
            System.assertEquals(false, Schema.sObjectType.Job_Application__c.isCreateable(), 'nem candidatura');
            jobs = JobPortalController.getJobs();
        }
        Set<String> titles = new Set<String>();
        for (PortalJobDto dto : jobs) {
            titles.add(dto.title);
        }
        System.assertEquals(2, jobs.size(), 'so Aberta e publicada (G2)');
        System.assert(titles.contains('ZZTEST-Analista Fiscal'));
        System.assert(titles.contains('ZZTEST-Analista de Logistica'));
        PortalJobDto first = jobs[0];
        System.assertNotEquals(null, first.slug);
        System.assert(String.isNotBlank(first.department));
        System.assertEquals('Sao Paulo', first.location);
        System.assertEquals('CLT', first.employmentType);
        System.assertNotEquals(null, first.openedDate);
        System.assertEquals(null, first.description, 'a lista nao leva o texto longo');
        System.assertEquals(null, first.requirements);
    }

    @IsTest
    static void detailReturnsFullTextOnlyForEligibleJob() {
        String slug = slugOf('Analista Fiscal');
        PortalJobDto found;
        PortalJobDto hidden;
        PortalJobDto draft;
        PortalJobDto closed;
        PortalJobDto unknown;
        PortalJobDto blank;
        System.runAs(guest()) {
            found = JobPortalController.getJob(slug);
            hidden = JobPortalController.getJob(slugOf('Oculta do portal'));
            draft = JobPortalController.getJob(slugOf('Rascunho publicado'));
            closed = JobPortalController.getJob(slugOf('Vaga encerrada'));
            unknown = JobPortalController.getJob('nao-existe');
            blank = JobPortalController.getJob('  ');
        }
        System.assertNotEquals(null, found);
        System.assertEquals('ZZTEST-Analista Fiscal', found.title);
        System.assertEquals('Remoto', found.workModel);
        System.assert(found.description.contains('Descricao da vaga'));
        System.assert(found.requirements.contains('Requisito'));
        System.assertEquals(null, hidden, 'Publish_On_Portal__c falso');
        System.assertEquals(null, draft, 'status Rascunho');
        System.assertEquals(null, closed, 'status Fechada');
        System.assertEquals(null, unknown);
        System.assertEquals(null, blank);
    }

    @IsTest
    static void dtoExposesOnlyAllowedFields() {
        PortalJobDto dto;
        System.runAs(guest()) {
            dto = JobPortalController.getJob(slugOf('Analista Fiscal'));
        }
        Set<String> expected = new Set<String>{
            'title',
            'slug',
            'department',
            'location',
            'workModel',
            'employmentType',
            'description',
            'requirements',
            'openedDate'
        };
        Map<String, Object> serialized = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(dto, false));
        System.assertEquals(expected, serialized.keySet(), 'o DTO nao pode ganhar campo interno sem este teste mudar');
        String json = JSON.serialize(dto);
        System.assert(!json.contains('Hiring_Manager'), 'sem gestor');
        System.assert(!json.contains('Recruiter'), 'sem recrutador');
        for (Object value : serialized.values()) {
            if (value instanceof String) {
                System.assert(!Pattern.matches('^[a-zA-Z0-9]{15,18}$', (String) value), 'nenhum Id de registro');
            }
        }
    }

    @IsTest
    static void formConfigCarriesConsentVersionAndServerClock() {
        Long before = Datetime.now().getTime();
        JobPortalController.FormConfig config;
        System.runAs(guest()) {
            config = JobPortalController.getFormConfig();
        }
        System.assertEquals(HrSettings.get().Consent_Text_Version__c, config.consentTextVersion);
        System.assert(config.renderedAt >= before);
    }

    @IsTest
    static void validSubmissionCreatesCandidateAndApplicationInTheQueue() {
        String slug = slugOf('Analista Fiscal');
        PortalApplicationInput data = input(slug, '  ZZTEST-Maria@Example.COM ');
        data.message = 'Ola <b>equipe</b><script>alert(1)</script>\nTenho interesse.';
        JobPortalController.SubmitResult result;
        System.runAs(guest()) {
            result = send(data);
        }
        System.assertEquals(true, result.success, result.message);
        Candidate__c candidate = [
            SELECT
                Name,
                OwnerId,
                Email_Normalized__c,
                Phone__c,
                City__c,
                LinkedIn_URL__c,
                Source__c,
                Consent_Given__c,
                Consent_Date__c,
                Consent_Text_Version__c
            FROM Candidate__c
            WHERE Email_Normalized__c = 'zztest-maria@example.com'
        ];
        Job_Application__c application = [
            SELECT OwnerId, Stage__c, Source__c, Cover_Letter__c, Job_Opening__r.Public_Slug__c
            FROM Job_Application__c
            WHERE Candidate__c = :candidate.Id
        ];
        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'HR_Recruiting_Queue'].Id;
        System.assertEquals('ZZTEST-Maria Souza', candidate.Name);
        System.assertEquals(queueId, candidate.OwnerId, 'candidato na fila');
        System.assertEquals('Portal', candidate.Source__c);
        System.assertEquals(true, candidate.Consent_Given__c);
        System.assertNotEquals(null, candidate.Consent_Date__c);
        System.assertEquals(HrSettings.get().Consent_Text_Version__c, candidate.Consent_Text_Version__c);
        System.assertEquals('Sao Paulo', candidate.City__c);
        System.assertEquals(queueId, application.OwnerId, 'candidatura na fila');
        System.assertEquals('Nova', application.Stage__c);
        System.assertEquals('Portal', application.Source__c);
        System.assertEquals(slug, application.Job_Opening__r.Public_Slug__c);
        System.assert(!application.Cover_Letter__c.contains('<'), 'HTML removido do texto livre');
        System.assert(!application.Cover_Letter__c.contains('>'));
        System.assert(application.Cover_Letter__c.contains('Tenho interesse.'));
    }

    @IsTest
    static void honeypotFilledReturnsFakeSuccessWithoutSaving() {
        PortalApplicationInput data = input(slugOf('Analista Fiscal'), 'zztest-robo@example.com');
        data.website = 'http://spam.example.com';
        JobPortalController.SubmitResult result;
        System.runAs(guest()) {
            result = send(data);
        }
        System.assertEquals(true, result.success, 'o robo recebe sucesso falso');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c = 'zztest-robo@example.com']
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Job_Application__c WHERE Candidate__r.Email_Normalized__c = 'zztest-robo@example.com']
        );
    }

    @IsTest
    static void tooFastSubmissionIsRejected() {
        String slug = slugOf('Analista Fiscal');
        PortalApplicationInput fast = input(slug, 'zztest-rapido@example.com');
        fast.renderedAt = String.valueOf(Datetime.now().getTime());
        PortalApplicationInput noClock = input(slug, 'zztest-rapido@example.com');
        noClock.renderedAt = null;
        PortalApplicationInput garbage = input(slug, 'zztest-rapido@example.com');
        garbage.renderedAt = 'abc';
        JobPortalController.SubmitResult fastResult;
        JobPortalController.SubmitResult noClockResult;
        JobPortalController.SubmitResult garbageResult;
        System.runAs(guest()) {
            fastResult = send(fast);
            noClockResult = send(noClock);
            garbageResult = send(garbage);
        }
        System.assertEquals(false, fastResult.success);
        System.assertEquals(JobPortalService.TOO_FAST_MESSAGE, fastResult.message);
        System.assertEquals(false, noClockResult.success);
        System.assertEquals(false, garbageResult.success);
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c = 'zztest-rapido@example.com']
        );
    }

    @IsTest
    static void eachFieldValidationReturnsAFriendlyMessageAndSavesNothing() {
        String slug = slugOf('Analista Fiscal');
        String email = 'zztest-invalido@example.com';

        PortalApplicationInput shortName = input(slug, email);
        shortName.name = 'A';
        PortalApplicationInput tagOnlyName = input(slug, email);
        tagOnlyName.name = '<b></b>';
        PortalApplicationInput longName = input(slug, email);
        longName.name = 'N'.repeat(121);
        PortalApplicationInput badEmail = input(slug, 'sem-arroba');
        PortalApplicationInput longEmail = input(slug, 'a'.repeat(80) + '@example.com');
        PortalApplicationInput badPhone = input(slug, email);
        badPhone.phone = 'telefone';
        PortalApplicationInput longCity = input(slug, email);
        longCity.city = 'C'.repeat(81);
        PortalApplicationInput badUrl = input(slug, email);
        badUrl.linkedInUrl = 'javascript:alert(1)';
        PortalApplicationInput longMessage = input(slug, email);
        longMessage.message = 'M'.repeat(2001);
        PortalApplicationInput noConsent = input(slug, email);
        noConsent.consent = false;
        PortalApplicationInput nullConsent = input(slug, email);
        nullConsent.consent = null;

        List<PortalApplicationInput> all = new List<PortalApplicationInput>{
            shortName,
            tagOnlyName,
            longName,
            badEmail,
            longEmail,
            badPhone,
            longCity,
            badUrl,
            longMessage,
            noConsent,
            nullConsent
        };
        List<String> expectedFields = new List<String>{
            'name',
            'name',
            'name',
            'email',
            'email',
            'phone',
            'city',
            'linkedInUrl',
            'message',
            'consent',
            'consent'
        };
        System.runAs(guest()) {
            for (Integer i = 0; i < all.size(); i++) {
                JobPortalController.SubmitResult result = send(all[i]);
                System.assertEquals(false, result.success, 'caso ' + i);
                System.assertEquals(expectedFields[i], result.field, 'caso ' + i + ': ' + result.message);
                System.assert(String.isNotBlank(result.message));
            }
            JobPortalController.SubmitResult nullInput = send(null);
            System.assertEquals(false, nullInput.success);
            System.assertEquals(JobPortalService.GENERIC_MESSAGE, nullInput.message);
        }
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Candidate__c
                WHERE Name LIKE 'ZZTEST-%' AND Email_Normalized__c LIKE 'zztest-invalido%'
            ]
        );
    }

    @IsTest
    static void unreadablePayloadGetsAGenericMessage() {
        List<String> payloads = new List<String>{ null, '', '{nao e json', '[1,2]' };
        System.runAs(guest()) {
            for (String payload : payloads) {
                JobPortalController.SubmitResult result = JobPortalController.submitApplication(payload);
                System.assertEquals(false, result.success);
                System.assertEquals(JobPortalService.GENERIC_MESSAGE, result.message);
            }
        }
    }

    @IsTest
    static void ineligibleOrMissingJobIsRejected() {
        List<String> slugs = new List<String>{
            slugOf('Oculta do portal'),
            slugOf('Rascunho publicado'),
            slugOf('Vaga encerrada'),
            'nao-existe',
            null,
            'x'.repeat(81)
        };
        System.runAs(guest()) {
            for (String slug : slugs) {
                JobPortalController.SubmitResult result = send(input(slug, 'zztest-vaga@example.com'));
                System.assertEquals(false, result.success, 'slug ' + slug);
                System.assertEquals(JobPortalService.CLOSED_MESSAGE, result.message);
            }
        }
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c = 'zztest-vaga@example.com']
        );
    }

    @IsTest
    static void dailyLimitPerEmailBlocksTheNextApplication() {
        overrideSettings(new Map<String, Object>{ 'Portal_Daily_Limit_Per_Email__c' => 1 });
        String email = 'zztest-limite@example.com';
        JobPortalController.SubmitResult first;
        JobPortalController.SubmitResult second;
        System.runAs(guest()) {
            first = send(input(slugOf('Analista Fiscal'), email));
            second = send(input(slugOf('Analista de Logistica'), email));
        }
        System.assertEquals(true, first.success, first.message);
        System.assertEquals(false, second.success);
        System.assertEquals('Limite diário de candidaturas atingido.', second.message);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Job_Application__c WHERE Candidate__r.Email_Normalized__c = :email]
        );
    }

    @IsTest
    static void duplicateApplicationToTheSameJobIsRefused() {
        String slug = slugOf('Analista Fiscal');
        String email = 'zztest-dup@example.com';
        JobPortalController.SubmitResult first;
        JobPortalController.SubmitResult second;
        System.runAs(guest()) {
            first = send(input(slug, email));
            second = send(input(slug, email.toUpperCase()));
        }
        System.assertEquals(true, first.success, first.message);
        System.assertEquals(false, second.success);
        System.assertEquals('Este candidato já se inscreveu nesta vaga.', second.message);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Job_Application__c WHERE Candidate__r.Email_Normalized__c = :email]
        );
        System.assertEquals(1, [SELECT COUNT() FROM Candidate__c WHERE Email_Normalized__c = :email]);
    }

    @IsTest
    static void existingCandidateIsReusedAndNotOverwritten() {
        String email = 'zztest-reuso@example.com';
        insert new Candidate__c(
            Name = 'ZZTEST-Nome Original',
            Email__c = email,
            City__c = 'Curitiba',
            Source__c = 'Indicacao'
        );
        PortalApplicationInput data = input(slugOf('Analista Fiscal'), email);
        data.name = 'ZZTEST-Outra Pessoa';
        data.city = 'Recife';
        JobPortalController.SubmitResult result;
        System.runAs(guest()) {
            result = send(data);
        }
        System.assertEquals(true, result.success, result.message);
        List<Candidate__c> candidates = [
            SELECT Name, City__c, Phone__c, Consent_Given__c
            FROM Candidate__c
            WHERE Email_Normalized__c = :email
        ];
        System.assertEquals(1, candidates.size(), 'candidato reaproveitado (C4)');
        System.assertEquals('ZZTEST-Nome Original', candidates[0].Name, 'dado existente nao e sobrescrito');
        System.assertEquals('Curitiba', candidates[0].City__c);
        System.assertEquals(true, candidates[0].Consent_Given__c, 'o consentimento e registrado');
        System.assertEquals(1, [SELECT COUNT() FROM Job_Application__c WHERE Candidate__c = :candidates[0].Id]);
    }
}
