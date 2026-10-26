/**
 * Configuracao do funil de recrutamento lida de Recruiting_Stage__mdt: ordem, cor, etapas terminais, transicoes
 * permitidas e exigencias de nota e de motivo. Nenhuma regra de etapa fica fixa em codigo: para mudar o funil
 * basta alterar os registros de Custom Metadata.
 *
 * Os rotulos vem do picklist Job_Application__c.Stage__c (respeitam traducao).
 */
public inherited sharing class RecruitingStageConfig {
    /** Etapa que dispara a admissao (C10). */
    public static final String HIRED_STAGE = 'Contratado';
    /** Etapa usada quando a vaga e encerrada (C6). */
    public static final String REJECTED_STAGE = 'Reprovado';
    public static final String CLOSED_REJECTION_REASON = 'Outro';

    public class StageInfo implements Comparable {
        public String value;
        public Integer sortOrder;
        public Boolean isTerminal;
        public List<String> allowedNext;
        public Boolean requiresScore;
        public Boolean requiresRejectionReason;
        public String color;

        public StageInfo() {
            this.allowedNext = new List<String>();
            this.isTerminal = false;
            this.requiresScore = false;
            this.requiresRejectionReason = false;
        }

        public StageInfo(Recruiting_Stage__mdt row) {
            this();
            this.value = row.Stage_Value__c;
            this.sortOrder = row.Order__c == null ? 999 : row.Order__c.intValue();
            this.isTerminal = row.Is_Terminal__c == true;
            this.requiresScore = row.Requires_Score__c == true;
            this.requiresRejectionReason = row.Requires_Rejection_Reason__c == true;
            this.color = row.Color__c;
            if (String.isNotBlank(row.Allowed_Next_Stages__c)) {
                for (String part : row.Allowed_Next_Stages__c.split(';')) {
                    if (String.isNotBlank(part)) {
                        this.allowedNext.add(part.trim());
                    }
                }
            }
        }

        public Integer compareTo(Object other) {
            return sortOrder - ((StageInfo) other).sortOrder;
        }
    }

    /** Permite aos testes substituir a configuracao sem depender dos registros implantados. */
    @TestVisible
    private static List<StageInfo> testOverride;
    private static List<StageInfo> cache;
    private static Map<String, String> labelCache;

    /** Etapas na ordem do funil (Order__c). */
    public static List<StageInfo> ordered() {
        if (testOverride != null) {
            return testOverride;
        }
        if (cache == null) {
            List<StageInfo> infos = new List<StageInfo>();
            for (Recruiting_Stage__mdt row : Recruiting_Stage__mdt.getAll().values()) {
                infos.add(new StageInfo(row));
            }
            infos.sort();
            cache = infos;
        }
        return cache;
    }

    public static StageInfo byValue(String stage) {
        if (stage != null) {
            for (StageInfo s : ordered()) {
                if (s.value == stage) {
                    return s;
                }
            }
        }
        return null;
    }

    /** Primeira etapa do funil: a etapa de toda candidatura nova. */
    public static String initialStage() {
        List<StageInfo> all = ordered();
        return all.isEmpty() ? 'Nova' : all[0].value;
    }

    /** Etapas em que a candidatura ainda esta em andamento. */
    public static Set<String> activeStages() {
        Set<String> result = new Set<String>();
        for (StageInfo s : ordered()) {
            if (!s.isTerminal) {
                result.add(s.value);
            }
        }
        return result;
    }

    /**
     * Etapas que protegem o candidato da anonimizacao: as ativas e a de contratacao (C11).
     */
    public static Set<String> retentionProtectedStages() {
        Set<String> result = activeStages();
        result.add(HIRED_STAGE);
        return result;
    }

    public static Boolean isAllowed(String fromStage, String toStage) {
        StageInfo source = byValue(fromStage);
        return source != null && source.allowedNext.contains(toStage);
    }

    /** Rotulo da etapa no picklist; devolve o proprio valor se nao encontrar. */
    public static String label(String stage) {
        if (stage == null) {
            return '';
        }
        if (labelCache == null) {
            labelCache = new Map<String, String>();
            for (Schema.PicklistEntry entry : Job_Application__c.Stage__c.getDescribe().getPicklistValues()) {
                labelCache.put(entry.getValue(), entry.getLabel());
            }
        }
        return labelCache.containsKey(stage) ? labelCache.get(stage) : stage;
    }

    /**
     * Valida a mudanca de etapa (C1 e C2). Devolve a mensagem de erro, ou null quando a mudanca e valida.
     * Mudar para a mesma etapa nao e mudanca e devolve null.
     */
    public static String validate(String fromStage, String toStage, Decimal score, String rejectionReason) {
        if (fromStage == toStage) {
            return null;
        }
        StageInfo target = byValue(toStage);
        if (target == null) {
            return 'Etapa desconhecida: ' + toStage + '.';
        }
        if (!isAllowed(fromStage, toStage)) {
            return 'Mudança de etapa não permitida: de ' + label(fromStage) + ' para ' + label(toStage) + '.';
        }
        if (target.requiresRejectionReason && String.isBlank(rejectionReason)) {
            return 'Informe o motivo da reprovação.';
        }
        if (target.requiresScore && score == null) {
            return 'Informe a nota do candidato antes de avançar para ' + label(toStage) + '.';
        }
        return null;
    }
}
