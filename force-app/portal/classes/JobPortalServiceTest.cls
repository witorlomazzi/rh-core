/**
 * Testes unitarios das regras de texto e de validacao do portal (spec 14, G3). Dados com prefixo ZZTEST-.
 */
@IsTest
private class JobPortalServiceTest {
    @IsTest
    static void cleanRemovesHtmlAndControlCharacters() {
        System.assertEquals('Ana', JobPortalService.clean('<b>Ana</b>', false));
        System.assertEquals('Ana Souza', JobPortalService.clean('  Ana\t\n  Souza  ', false));
        System.assertEquals('oi', JobPortalService.clean('<script>alert(1)</script>oi', false));
        System.assertEquals('oi', JobPortalService.clean('<STYLE type="x">a{}</STYLE>oi', false));
        System.assertEquals('a b', JobPortalService.clean('a<img src=x onerror=alert(1)>b', false));
        System.assertEquals('1 2', JobPortalService.clean('1 < 2', false).replaceAll('\\s+', ' ').replace(' 2', ' 2'));
        System.assertEquals('a b', JobPortalService.clean('a' + String.fromCharArray(new List<Integer>{ 0, 7 }) + 'b', false));
        System.assertEquals(null, JobPortalService.clean('<p></p>', false));
        System.assertEquals(null, JobPortalService.clean('   ', false));
        System.assertEquals(null, JobPortalService.clean(null, false));
    }

    @IsTest
    static void cleanKeepsLineBreaksForTheMessage() {
        String cleaned = JobPortalService.clean('linha 1\r\nlinha 2\n\n\n\nlinha 3 <i>fim</i>', true);
        System.assertEquals('linha 1\nlinha 2\n\nlinha 3 fim', cleaned);
        System.assert(!cleaned.contains('<'));
    }

    @IsTest
    static void submitWithoutInputFailsWithAGenericMessage() {
        try {
            JobPortalService.submit(null);
            System.assert(false, 'deveria falhar');
        } catch (JobPortalService.PortalException e) {
            System.assertEquals(JobPortalService.GENERIC_MESSAGE, e.getMessage());
        }
    }

    @IsTest
    static void honeypotReturnsWithoutThrowingEvenWithInvalidData() {
        PortalApplicationInput data = new PortalApplicationInput();
        data.website = 'http://spam.example.com';
        JobPortalService.submit(data);
        System.assertEquals(0, [SELECT COUNT() FROM Candidate__c]);
    }

    @IsTest
    static void emptyPortalHasNoJobs() {
        System.assertEquals(0, JobPortalService.listOpenJobs().size());
        System.assertEquals(null, JobPortalService.findOpenJob('qualquer'));
    }

    @IsTest
    static void jobWithoutDepartmentGetsANullDepartmentName() {
        insert new Job_Opening__c(Name = 'ZZTEST-Sem area', Status__c = 'Aberta', Publish_On_Portal__c = true);
        List<PortalJobDto> jobs = JobPortalService.listOpenJobs();
        System.assertEquals(1, jobs.size());
        System.assertEquals(null, jobs[0].department);
        PortalJobDto detail = JobPortalService.findOpenJob(jobs[0].slug);
        System.assertEquals('ZZTEST-Sem area', detail.title);
    }
}
