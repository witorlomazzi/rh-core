/**
 * Regras de candidato: e-mail normalizado (C4), cadastro sem duplicar pessoa (upsertByEmail) e anonimizacao LGPD
 * (C11). Base do portal publico de vagas (spec 14) e da admissao (spec 15).
 *
 * A classe herda o modo de compartilhamento de quem chama. A busca por e-mail e a escrita sobre candidatos que o
 * chamador nao enxerga ficam isoladas em SystemAccess (without sharing), com o motivo comentado.
 */
public inherited sharing class CandidateService {
    public static final String ANONYMIZED_NAME = 'Candidato anonimizado';
    public static final String ANONYMIZED_DOMAIN = '@anon.invalid';
    private static final Pattern EMAIL_FORMAT = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

    /** Dados de entrada para cadastrar ou reaproveitar um candidato. Pode vir da tela, de importacao ou do portal. */
    public class CandidateInput {
        public String name;
        public String email;
        public String phone;
        public String linkedInUrl;
        public String city;
        public String source;
        public Boolean consentGiven;
        public String consentTextVersion;
    }

    /** C4: minusculo e sem espacos. Devolve null para e-mail vazio. */
    public static String normalizeEmail(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        return email.deleteWhitespace().toLowerCase();
    }

    /** Cadastra o candidato ou reaproveita o existente com o mesmo e-mail normalizado. */
    public static Candidate__c upsertByEmail(CandidateInput input) {
        Map<String, Candidate__c> result = upsertByEmail(new List<CandidateInput>{ input });
        return result.get(normalizeEmail(input.email));
    }

    /**
     * Versao em lote. Devolve o candidato de cada e-mail normalizado. Candidato existente nao tem dado
     * sobrescrito: so campos vazios sao preenchidos, o consentimento e registrado se ainda nao existia e a
     * ultima atividade e renovada. Assim, quem informa um e-mail alheio nao altera os dados da outra pessoa.
     */
    public static Map<String, Candidate__c> upsertByEmail(List<CandidateInput> inputs) {
        Map<String, CandidateInput> byEmail = new Map<String, CandidateInput>();
        for (CandidateInput input : inputs) {
            validate(input);
            String key = normalizeEmail(input.email);
            if (!byEmail.containsKey(key)) {
                byEmail.put(key, input);
            }
        }

        Map<String, Candidate__c> existing = new SystemAccess().findByNormalizedEmails(byEmail.keySet());
        List<Candidate__c> toUpdate = new List<Candidate__c>();
        List<Candidate__c> toInsert = new List<Candidate__c>();
        Map<String, Candidate__c> result = new Map<String, Candidate__c>();
        String defaultVersion = HrSettings.get().Consent_Text_Version__c;

        for (String key : byEmail.keySet()) {
            CandidateInput input = byEmail.get(key);
            Candidate__c current = existing.get(key);
            if (current == null) {
                Candidate__c created = new Candidate__c(
                    Name = input.name.trim().left(80),
                    Email__c = input.email.deleteWhitespace(),
                    Phone__c = input.phone,
                    LinkedIn_URL__c = input.linkedInUrl,
                    City__c = input.city,
                    Source__c = input.source,
                    Last_Activity_Date__c = Date.today()
                );
                if (input.consentGiven == true) {
                    created.Consent_Given__c = true;
                    created.Consent_Date__c = Datetime.now();
                    created.Consent_Text_Version__c = String.isNotBlank(input.consentTextVersion)
                        ? input.consentTextVersion
                        : defaultVersion;
                }
                toInsert.add(created);
                result.put(key, created);
            } else {
                Candidate__c patch = new Candidate__c(Id = current.Id, Last_Activity_Date__c = Date.today());
                fillIfBlank(current, patch, input);
                if (input.consentGiven == true && current.Consent_Given__c != true) {
                    patch.Consent_Given__c = true;
                    patch.Consent_Date__c = Datetime.now();
                    patch.Consent_Text_Version__c = String.isNotBlank(input.consentTextVersion)
                        ? input.consentTextVersion
                        : defaultVersion;
                }
                toUpdate.add(patch);
                result.put(key, current);
            }
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toUpdate.isEmpty()) {
            new SystemAccess().updateCandidates(toUpdate);
        }
        return result;
    }

    /**
     * C11: anonimiza os candidatos informados que continuam elegiveis. Um candidato com candidatura ativa ou
     * contratada nunca e anonimizado, mesmo que o Id venha na lista. Devolve quantos foram anonimizados.
     */
    public static Integer anonymize(Set<Id> candidateIds) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            return 0;
        }
        return new SystemAccess().anonymizeEligible(candidateIds);
    }

    private static void validate(CandidateInput input) {
        if (input == null || String.isBlank(input.name)) {
            throw new JobApplicationService.RecruitingException('Informe o nome do candidato.');
        }
        String normalized = normalizeEmail(input?.email);
        if (normalized == null || !EMAIL_FORMAT.matcher(normalized).matches()) {
            throw new JobApplicationService.RecruitingException('Informe um e-mail válido.');
        }
    }

    private static void fillIfBlank(Candidate__c current, Candidate__c patch, CandidateInput input) {
        if (String.isBlank(current.Phone__c) && String.isNotBlank(input.phone)) {
            patch.Phone__c = input.phone;
        }
        if (String.isBlank(current.LinkedIn_URL__c) && String.isNotBlank(input.linkedInUrl)) {
            patch.LinkedIn_URL__c = input.linkedInUrl;
        }
        if (String.isBlank(current.City__c) && String.isNotBlank(input.city)) {
            patch.City__c = input.city;
        }
        if (String.isBlank(current.Source__c) && String.isNotBlank(input.source)) {
            patch.Source__c = input.source;
        }
    }

    /**
     * Contexto de sistema (spec 02): a deduplicacao por e-mail precisa enxergar todos os candidatos, inclusive os
     * que o chamador nao ve (portal publico, gestor contratante). A anonimizacao roda sobre candidatos vencidos
     * sem relacao com o usuario que dispara o batch.
     */
    // Contexto de sistema da spec 02: deduplicacao e anonimizacao (LGPD) de candidatos.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private without sharing class SystemAccess {
        public Map<String, Candidate__c> findByNormalizedEmails(Set<String> normalizedEmails) {
            Map<String, Candidate__c> result = new Map<String, Candidate__c>();
            for (Candidate__c c : [
                SELECT
                    Id,
                    Name,
                    Email_Normalized__c,
                    Phone__c,
                    LinkedIn_URL__c,
                    City__c,
                    Source__c,
                    Consent_Given__c
                FROM Candidate__c
                WHERE Email_Normalized__c IN :normalizedEmails
            ]) {
                result.put(c.Email_Normalized__c, c);
            }
            return result;
        }

        public void updateCandidates(List<Candidate__c> candidates) {
            update candidates;
        }

        public Integer anonymizeEligible(Set<Id> candidateIds) {
            Set<String> protectedStages = RecruitingStageConfig.retentionProtectedStages();
            Set<Id> blocked = new Set<Id>();
            for (Job_Application__c a : [
                SELECT Candidate__c
                FROM Job_Application__c
                WHERE Candidate__c IN :candidateIds AND Stage__c IN :protectedStages
            ]) {
                blocked.add(a.Candidate__c);
            }
            List<Candidate__c> toUpdate = new List<Candidate__c>();
            Set<Id> anonymizedIds = new Set<Id>();
            for (Candidate__c c : [SELECT Id FROM Candidate__c WHERE Id IN :candidateIds AND Anonymized__c = FALSE]) {
                if (blocked.contains(c.Id)) {
                    continue;
                }
                // Minusculo, como todo e-mail normalizado (C4); o campo de e-mail do Salesforce tambem guarda minusculo.
                String anonymousEmail = ('anon-' + c.Id + ANONYMIZED_DOMAIN).toLowerCase();
                toUpdate.add(
                    new Candidate__c(
                        Id = c.Id,
                        Name = ANONYMIZED_NAME,
                        Email__c = anonymousEmail,
                        Email_Normalized__c = anonymousEmail,
                        Phone__c = null,
                        LinkedIn_URL__c = null,
                        City__c = null,
                        Anonymized__c = true,
                        Anonymized_Date__c = Datetime.now()
                    )
                );
                anonymizedIds.add(c.Id);
            }
            if (toUpdate.isEmpty()) {
                return 0;
            }
            List<Job_Application__c> applications = new List<Job_Application__c>();
            for (Job_Application__c a : [
                SELECT Id, Cover_Letter__c
                FROM Job_Application__c
                WHERE Candidate__c IN :anonymizedIds
            ]) {
                if (a.Cover_Letter__c != null) {
                    applications.add(new Job_Application__c(Id = a.Id, Cover_Letter__c = null));
                }
            }
            update toUpdate;
            if (!applications.isEmpty()) {
                TriggerHandler.bypass('JobApplicationTriggerHandler');
                try {
                    update applications;
                } finally {
                    TriggerHandler.clearBypass('JobApplicationTriggerHandler');
                }
            }
            return toUpdate.size();
        }
    }
}
