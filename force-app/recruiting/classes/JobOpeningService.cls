/**
 * Regras de vaga: identificador publico (C7), encerramento com reprovacao das candidaturas abertas (C6) e
 * contagem de candidaturas (C8).
 *
 * A classe herda o modo de compartilhamento de quem chama. Os pontos que precisam enxergar dados alem do alcance
 * do usuario ficam isolados em SystemAccess (without sharing), cada um com o motivo comentado.
 */
public inherited sharing class JobOpeningService {
    public static final String STATUS_OPEN = 'Aberta';
    public static final Set<String> CLOSED_STATUSES = new Set<String>{ 'Fechada', 'Cancelada' };
    public static final String CLOSED_NOTE = 'Vaga encerrada';
    private static final Integer MAX_SLUG_BASE = 70;
    private static final String DEFAULT_SLUG = 'vaga';

    private static final Map<String, String> ASCII_BY_ACCENT = new Map<String, String>{
        'á' => 'a', 'à' => 'a', 'â' => 'a', 'ã' => 'a', 'ä' => 'a',
        'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e',
        'í' => 'i', 'ì' => 'i', 'î' => 'i', 'ï' => 'i',
        'ó' => 'o', 'ò' => 'o', 'ô' => 'o', 'õ' => 'o', 'ö' => 'o',
        'ú' => 'u', 'ù' => 'u', 'û' => 'u', 'ü' => 'u',
        'ç' => 'c', 'ñ' => 'n'
    };

    public static Boolean isClosedStatus(String status) {
        return status != null && CLOSED_STATUSES.contains(status);
    }

    /**
     * C7: minusculo, sem acento, hifens no lugar de qualquer sequencia de caracteres que nao seja letra ou
     * numero. Titulo sem nenhum caractere aproveitavel vira "vaga".
     */
    public static String slugify(String title) {
        if (String.isBlank(title)) {
            return DEFAULT_SLUG;
        }
        String lower = title.toLowerCase();
        String ascii = '';
        for (Integer i = 0; i < lower.length(); i++) {
            String ch = lower.substring(i, i + 1);
            ascii += ASCII_BY_ACCENT.containsKey(ch) ? ASCII_BY_ACCENT.get(ch) : ch;
        }
        String slug = ascii.replaceAll('[^a-z0-9]+', '-').replaceAll('^-+|-+$', '');
        if (slug.length() > MAX_SLUG_BASE) {
            slug = slug.substring(0, MAX_SLUG_BASE).replaceAll('-+$', '');
        }
        return String.isBlank(slug) ? DEFAULT_SLUG : slug;
    }

    /**
     * Gera Public_Slug__c das vagas que ainda nao tem, acrescentando sufixo numerico quando o identificador ja
     * existe (no banco ou no proprio lote). Pensado para before insert e before update.
     */
    public static void assignSlugs(List<Job_Opening__c> openings) {
        List<Job_Opening__c> pending = new List<Job_Opening__c>();
        Set<String> bases = new Set<String>();
        for (Job_Opening__c o : openings) {
            if (String.isBlank(o.Public_Slug__c)) {
                pending.add(o);
                bases.add(slugify(o.Name));
            }
        }
        if (pending.isEmpty()) {
            return;
        }
        Set<String> taken = new SystemAccess().existingSlugs(bases);
        for (Job_Opening__c o : openings) {
            if (String.isNotBlank(o.Public_Slug__c)) {
                taken.add(o.Public_Slug__c.toLowerCase());
            }
        }
        for (Job_Opening__c o : pending) {
            String base = slugify(o.Name);
            String candidate = base;
            Integer suffix = 2;
            while (taken.contains(candidate)) {
                candidate = base + '-' + suffix;
                suffix++;
            }
            taken.add(candidate);
            o.Public_Slug__c = candidate;
        }
    }

    /**
     * C6: candidaturas nao terminais das vagas encerradas viram Reprovado, motivo Outro, e o historico recebe a
     * observacao "Vaga encerrada".
     */
    public static void closeApplications(Set<Id> openingIds) {
        new SystemAccess().rejectActiveApplications(openingIds);
    }

    /** C8: recalcula Applications_Count__c a partir das candidaturas existentes. */
    public static void refreshApplicationCounts(Set<Id> openingIds) {
        openingIds.remove(null);
        if (openingIds.isEmpty()) {
            return;
        }
        new SystemAccess().refreshCounts(openingIds);
    }

    /**
     * Contexto de sistema (spec 02): unicidade do identificador publico, contagem e reprovacao em massa precisam
     * enxergar todas as candidaturas e vagas, mesmo as que o usuario que disparou a mudanca nao enxerga.
     */
    // Contexto de sistema da spec 02: dados derivados de vaga e candidatura mantidos por Apex.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private without sharing class SystemAccess {
        public Set<String> existingSlugs(Set<String> bases) {
            List<String> patterns = new List<String>();
            for (String base : bases) {
                patterns.add(base + '%');
            }
            Set<String> result = new Set<String>();
            for (Job_Opening__c o : [SELECT Public_Slug__c FROM Job_Opening__c WHERE Public_Slug__c LIKE :patterns]) {
                result.add(o.Public_Slug__c.toLowerCase());
            }
            return result;
        }

        public void refreshCounts(Set<Id> openingIds) {
            Map<Id, Integer> counts = new Map<Id, Integer>();
            for (Id id : openingIds) {
                counts.put(id, 0);
            }
            for (AggregateResult ar : [
                SELECT Job_Opening__c opening, COUNT(Id) total
                FROM Job_Application__c
                WHERE Job_Opening__c IN :openingIds
                GROUP BY Job_Opening__c
            ]) {
                counts.put((Id) ar.get('opening'), (Integer) ar.get('total'));
            }
            List<Job_Opening__c> toUpdate = new List<Job_Opening__c>();
            for (Job_Opening__c o : [SELECT Id, Applications_Count__c FROM Job_Opening__c WHERE Id IN :openingIds]) {
                Integer total = counts.get(o.Id);
                if (o.Applications_Count__c != total) {
                    toUpdate.add(new Job_Opening__c(Id = o.Id, Applications_Count__c = total));
                }
            }
            if (!toUpdate.isEmpty()) {
                TriggerHandler.bypass('JobOpeningTriggerHandler');
                try {
                    update toUpdate;
                } finally {
                    TriggerHandler.clearBypass('JobOpeningTriggerHandler');
                }
            }
        }

        public void rejectActiveApplications(Set<Id> openingIds) {
            Set<String> active = RecruitingStageConfig.activeStages();
            List<Job_Application__c> toReject = new List<Job_Application__c>();
            for (Job_Application__c a : [
                SELECT Id
                FROM Job_Application__c
                WHERE Job_Opening__c IN :openingIds AND Stage__c IN :active
            ]) {
                a.Stage__c = RecruitingStageConfig.REJECTED_STAGE;
                a.Rejection_Reason__c = RecruitingStageConfig.CLOSED_REJECTION_REASON;
                JobApplicationService.registerNote(a.Id, CLOSED_NOTE);
                toReject.add(a);
            }
            if (!toReject.isEmpty()) {
                update toReject;
            }
        }
    }
}
