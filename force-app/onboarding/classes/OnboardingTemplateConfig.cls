/**
 * Modelos de tarefa do onboarding lidos de Onboarding_Task_Template__mdt. Nenhuma tarefa fica fixa em codigo: para
 * mudar o plano padrao basta alterar os registros de Custom Metadata.
 *
 * Applies_To_Employment_Type__c vazio significa "todos os tipos"; senao e uma lista separada por ponto e virgula
 * com valores de Employee__c.Employment_Type__c (ex.: CLT;Estagio).
 */
public inherited sharing class OnboardingTemplateConfig {
    public class Template implements Comparable {
        public String title;
        public String description;
        public String ownerRole;
        public Integer offsetDays;
        public Integer sortOrder;
        public Set<String> employmentTypes;

        public Template() {
            this.employmentTypes = new Set<String>();
            this.offsetDays = 0;
            this.sortOrder = 999;
        }

        public Template(Onboarding_Task_Template__mdt row) {
            this();
            this.title = row.Title__c;
            this.description = row.Description__c;
            this.ownerRole = row.Owner_Role__c;
            this.offsetDays = row.Due_Offset_Days__c == null ? 0 : row.Due_Offset_Days__c.intValue();
            this.sortOrder = row.Order__c == null ? 999 : row.Order__c.intValue();
            if (String.isNotBlank(row.Applies_To_Employment_Type__c)) {
                for (String part : row.Applies_To_Employment_Type__c.split(';')) {
                    if (String.isNotBlank(part)) {
                        this.employmentTypes.add(part.trim());
                    }
                }
            }
        }

        /** Vazio vale para todos os tipos de contratacao. */
        public Boolean appliesTo(String employmentType) {
            return employmentTypes.isEmpty() || employmentTypes.contains(employmentType);
        }

        public Integer compareTo(Object other) {
            return sortOrder - ((Template) other).sortOrder;
        }
    }

    /** Permite aos testes substituir a configuracao sem depender dos registros implantados. */
    @TestVisible
    private static List<Template> testOverride;
    private static List<Template> cache;

    /** Todos os modelos, na ordem de Order__c. */
    public static List<Template> all() {
        if (testOverride != null) {
            return testOverride;
        }
        if (cache == null) {
            List<Template> rows = new List<Template>();
            for (Onboarding_Task_Template__mdt row : Onboarding_Task_Template__mdt.getAll().values()) {
                rows.add(new Template(row));
            }
            rows.sort();
            cache = rows;
        }
        return cache;
    }

    /** Modelos aplicaveis ao tipo de contratacao informado, na ordem de Order__c. */
    public static List<Template> forEmploymentType(String employmentType) {
        List<Template> result = new List<Template>();
        for (Template t : all()) {
            if (t.appliesTo(employmentType)) {
                result.add(t);
            }
        }
        return result;
    }
}
