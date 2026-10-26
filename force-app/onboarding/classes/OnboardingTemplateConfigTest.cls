@IsTest
private class OnboardingTemplateConfigTest {
    @IsTest
    static void deployedTemplatesAreOrderedAndComplete() {
        List<OnboardingTemplateConfig.Template> all = OnboardingTemplateConfig.all();
        Assert.areEqual(8, all.size(), 'Os 8 modelos padrao da spec 15');
        Assert.areEqual('Enviar documentos admissionais', all[0].title);
        Assert.areEqual('Colaborador', all[0].ownerRole);
        Assert.areEqual(-10, all[0].offsetDays);
        Assert.areEqual('Conversa de 30 dias', all[7].title);
        Assert.areEqual(30, all[7].offsetDays);
        for (Integer i = 1; i < all.size(); i++) {
            Assert.isTrue(all[i - 1].sortOrder < all[i].sortOrder, 'Ordem crescente');
        }
        Assert.areEqual(8, OnboardingTemplateConfig.all().size(), 'Segunda chamada usa o cache');
    }

    @IsTest
    static void everyDeployedTemplateAppliesToAllEmploymentTypes() {
        for (String type : new List<String>{ 'CLT', 'Estagio', 'PJ' }) {
            Assert.areEqual(8, OnboardingTemplateConfig.forEmploymentType(type).size(), type);
        }
    }

    @IsTest
    static void employmentTypeListIsParsedFromTheRecord() {
        Onboarding_Task_Template__mdt row = new Onboarding_Task_Template__mdt(
            Title__c = 'ZZTEST-Modelo',
            Owner_Role__c = 'RH',
            Applies_To_Employment_Type__c = 'CLT; PJ;;'
        );
        OnboardingTemplateConfig.Template t = new OnboardingTemplateConfig.Template(row);
        Assert.isTrue(t.appliesTo('CLT'));
        Assert.isTrue(t.appliesTo('PJ'));
        Assert.isFalse(t.appliesTo('Estagio'));
        Assert.areEqual(0, t.offsetDays, 'Sem prazo no modelo: zero dias');
        Assert.areEqual(999, t.sortOrder, 'Sem ordem no modelo: vai para o fim');

        OnboardingTemplateConfig.Template everyone = new OnboardingTemplateConfig.Template(new Onboarding_Task_Template__mdt(Title__c = 'ZZTEST-Todos'));
        Assert.isTrue(everyone.appliesTo('Estagio'), 'Lista vazia vale para todos');
    }

    @IsTest
    static void overrideReplacesTheDeployedConfiguration() {
        OnboardingTemplateConfig.Template only = new OnboardingTemplateConfig.Template();
        only.title = 'ZZTEST-Unico';
        OnboardingTemplateConfig.testOverride = new List<OnboardingTemplateConfig.Template>{ only };
        Assert.areEqual(1, OnboardingTemplateConfig.all().size());
        Assert.areEqual(1, OnboardingTemplateConfig.forEmploymentType('PJ').size());
    }
}
