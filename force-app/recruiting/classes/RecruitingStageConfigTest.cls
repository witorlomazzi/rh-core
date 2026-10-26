@IsTest
private class RecruitingStageConfigTest {
    private static RecruitingStageConfig.StageInfo stage(String value, Integer order, Boolean terminal, String next) {
        RecruitingStageConfig.StageInfo s = new RecruitingStageConfig.StageInfo();
        s.value = value;
        s.sortOrder = order;
        s.isTerminal = terminal;
        s.allowedNext = String.isBlank(next) ? new List<String>() : next.split(';');
        return s;
    }

    @IsTest
    static void orderedFollowsCustomMetadata() {
        List<RecruitingStageConfig.StageInfo> all = RecruitingStageConfig.ordered();
        Assert.areEqual(8, all.size(), 'Uma etapa para cada valor do picklist');
        Assert.areEqual('Nova', all[0].value);
        Assert.areEqual('Nova', RecruitingStageConfig.initialStage());
        for (Integer i = 1; i < all.size(); i++) {
            Assert.isTrue(all[i].sortOrder >= all[i - 1].sortOrder, 'Ordem crescente');
        }
        Assert.areEqual(
            new Set<String>{ 'Nova', 'Triagem', 'Entrevista_RH', 'Entrevista_Tecnica', 'Proposta' },
            RecruitingStageConfig.activeStages()
        );
        Assert.isTrue(RecruitingStageConfig.retentionProtectedStages().contains('Contratado'));
        Assert.isFalse(RecruitingStageConfig.retentionProtectedStages().contains('Reprovado'));
        for (String terminal : new List<String>{ 'Contratado', 'Reprovado', 'Desistiu' }) {
            RecruitingStageConfig.StageInfo info = RecruitingStageConfig.byValue(terminal);
            Assert.isTrue(info.isTerminal, terminal + ' e terminal');
            Assert.isTrue(info.allowedNext.isEmpty(), terminal + ' nao tem proxima etapa');
        }
        Assert.isTrue(RecruitingStageConfig.byValue('Proposta').requiresScore);
        Assert.isTrue(RecruitingStageConfig.byValue('Reprovado').requiresRejectionReason);
        Assert.isNull(RecruitingStageConfig.byValue('Inexistente'));
        Assert.isNull(RecruitingStageConfig.byValue(null));
    }

    @IsTest
    static void defaultTransitionsMatchSpec() {
        Map<String, Set<String>> expected = new Map<String, Set<String>>{
            'Nova' => new Set<String>{ 'Triagem', 'Reprovado', 'Desistiu' },
            'Triagem' => new Set<String>{ 'Entrevista_RH', 'Reprovado', 'Desistiu' },
            'Entrevista_RH' => new Set<String>{ 'Entrevista_Tecnica', 'Reprovado', 'Desistiu' },
            'Entrevista_Tecnica' => new Set<String>{ 'Proposta', 'Reprovado', 'Desistiu' },
            'Proposta' => new Set<String>{ 'Contratado', 'Reprovado', 'Desistiu' }
        };
        for (String from_x : expected.keySet()) {
            Assert.areEqual(
                expected.get(from_x),
                new Set<String>(RecruitingStageConfig.byValue(from_x).allowedNext),
                'Transicoes de ' + from_x
            );
        }
        Assert.isFalse(RecruitingStageConfig.isAllowed('Nova', 'Proposta'));
        Assert.isFalse(RecruitingStageConfig.isAllowed('Triagem', 'Nova'));
        Assert.isFalse(RecruitingStageConfig.isAllowed('Contratado', 'Reprovado'));
        Assert.isFalse(RecruitingStageConfig.isAllowed(null, 'Triagem'));
    }

    @IsTest
    static void validateAppliesTransitionReasonAndScoreRules() {
        Assert.isNull(RecruitingStageConfig.validate('Nova', 'Triagem', null, null), 'Transicao valida');
        Assert.isNull(RecruitingStageConfig.validate('Nova', 'Nova', null, null), 'Mesma etapa nao e mudanca');
        Assert.isNull(RecruitingStageConfig.validate('Triagem', 'Reprovado', null, 'Perfil'));
        Assert.isNull(RecruitingStageConfig.validate('Entrevista_Tecnica', 'Proposta', 3, null));

        String notAllowed = RecruitingStageConfig.validate('Nova', 'Proposta', 5, null);
        Assert.areEqual('Mudança de etapa não permitida: de Nova para Proposta.', notAllowed);
        String fromTerminal = RecruitingStageConfig.validate('Reprovado', 'Triagem', null, null);
        Assert.isTrue(fromTerminal.startsWith('Mudança de etapa não permitida'));
        Assert.areEqual('Informe o motivo da reprovação.', RecruitingStageConfig.validate('Nova', 'Reprovado', null, null));
        Assert.areEqual('Informe o motivo da reprovação.', RecruitingStageConfig.validate('Nova', 'Reprovado', null, ''));
        String noScore = RecruitingStageConfig.validate('Entrevista_Tecnica', 'Proposta', null, null);
        Assert.isTrue(noScore.contains('nota'), noScore);
        Assert.isTrue(RecruitingStageConfig.validate('Nova', 'Inexistente', null, null).contains('Etapa desconhecida'));
    }

    @IsTest
    static void labelsComeFromPicklistAndFallBackToValue() {
        Assert.areEqual('Entrevista com RH', RecruitingStageConfig.label('Entrevista_RH'));
        Assert.areEqual('Valor solto', RecruitingStageConfig.label('Valor solto'));
        Assert.areEqual('', RecruitingStageConfig.label(null));
    }

    @IsTest
    static void testOverrideReplacesConfiguration() {
        RecruitingStageConfig.testOverride = new List<RecruitingStageConfig.StageInfo>{
            stage('Aberta', 1, false, 'Fechada'),
            stage('Fechada', 2, true, '')
        };
        Assert.areEqual('Aberta', RecruitingStageConfig.initialStage());
        Assert.isTrue(RecruitingStageConfig.isAllowed('Aberta', 'Fechada'));
        Assert.isFalse(RecruitingStageConfig.isAllowed('Fechada', 'Aberta'));
        RecruitingStageConfig.testOverride = new List<RecruitingStageConfig.StageInfo>();
        Assert.areEqual('Nova', RecruitingStageConfig.initialStage(), 'Sem etapas, assume Nova');
    }
}
