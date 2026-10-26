/**
 * Regras do portal publico de vagas (spec 14).
 *
 *  - listOpenJobs / findOpenJob: vagas elegiveis (G2: Status Aberta e Publish_On_Portal__c) como DTO (G1).
 *  - submit: valida e grava a candidatura de um visitante anonimo (G3), delegando candidato e candidatura ao
 *    modulo de recrutamento (JobApplicationService.apply), que reaproveita o candidato por e-mail (C4) e
 *    respeita a candidatura unica (C5).
 *
 * A classe herda o modo de compartilhamento de quem chama. O unico chamador de producao e JobPortalController
 * (without sharing), porque o usuario convidado do site nao tem acesso a objeto (spec 02, contexto de sistema).
 * Por isso as consultas daqui nao usam USER_MODE: o convidado nao leria nada e o filtro G2 e feito na propria query.
 */
// Contexto de sistema da spec 02 (portal publico, usuario convidado sem acesso a objeto).
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class JobPortalService {
    public static final String STATUS_OPEN = 'Aberta';
    public static final String SOURCE_PORTAL = 'Portal';
    public static final Integer MAX_JOBS = 200;

    public static final String DAILY_LIMIT_MESSAGE = 'Limite diário de candidaturas atingido.';
    public static final String CLOSED_MESSAGE = 'Esta vaga não está mais disponível.';
    public static final String CONSENT_MESSAGE = 'É necessário aceitar o termo de privacidade.';
    public static final String TOO_FAST_MESSAGE = 'Aguarde alguns segundos e envie o formulário novamente.';
    public static final String GENERIC_MESSAGE = 'Não foi possível enviar sua candidatura agora. Tente novamente em alguns minutos.';

    @TestVisible
    private static final Integer DEFAULT_MIN_SECONDS = 3;
    @TestVisible
    private static final Integer DEFAULT_DAILY_LIMIT = 3;

    private static final Integer MAX_NAME = 120;
    private static final Integer MIN_NAME = 2;
    private static final Integer MAX_EMAIL = 80;
    private static final Integer MAX_PHONE = 25;
    private static final Integer MAX_CITY = 80;
    private static final Integer MAX_URL = 255;
    private static final Integer MAX_MESSAGE = 2000;
    private static final Integer MAX_SLUG = 80;

    private static final Pattern EMAIL_FORMAT = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
    private static final Pattern PHONE_FORMAT = Pattern.compile('^[0-9+()\\-\\s.]{8,25}$');
    private static final Pattern URL_FORMAT = Pattern.compile('^https?://[^\\s]+$');

    /** Erro de regra com mensagem amigavel para o visitante. field indica o campo do formulario, se houver. */
    public class PortalException extends Exception {
        public String field;
    }

    /** Vagas elegiveis para a lista. description e requirements ficam vazios (so o detalhe devolve o texto). */
    public static List<PortalJobDto> listOpenJobs() {
        List<PortalJobDto> result = new List<PortalJobDto>();
        for (Job_Opening__c o : [
            SELECT
                Name,
                Public_Slug__c,
                Department__r.Name,
                Location__c,
                Work_Model__c,
                Employment_Type__c,
                Opened_Date__c
            FROM Job_Opening__c
            WHERE Status__c = :STATUS_OPEN AND Publish_On_Portal__c = TRUE AND Public_Slug__c != NULL
            ORDER BY Opened_Date__c DESC NULLS LAST, Name
            LIMIT :MAX_JOBS
        ]) {
            result.add(toDto(o, false));
        }
        return result;
    }

    /** Detalhe da vaga elegivel com esse identificador publico, ou null se nao existir ou nao for elegivel (G2). */
    public static PortalJobDto findOpenJob(String slug) {
        Job_Opening__c opening = eligibleOpening(slug);
        return opening == null ? null : toDto(opening, true);
    }

    /**
     * G3: valida e grava a candidatura. Lanca PortalException com mensagem amigavel quando algo falha. Se o honeypot
     * vier preenchido, nao grava nada e retorna normalmente (sucesso falso para nao ensinar o robo).
     */
    public static void submit(PortalApplicationInput input) {
        if (input == null) {
            throw fail(GENERIC_MESSAGE, null);
        }
        if (String.isNotBlank(input.website)) {
            return;
        }
        assertNotTooFast(input.renderedAt);

        String name = clean(input.name, false);
        if (name == null || name.length() < MIN_NAME) {
            throw fail('Informe seu nome completo.', 'name');
        }
        if (name.length() > MAX_NAME) {
            throw fail('O nome pode ter no máximo ' + MAX_NAME + ' caracteres.', 'name');
        }
        String email = CandidateService.normalizeEmail(clean(input.email, false));
        if (email == null || email.length() > MAX_EMAIL || !EMAIL_FORMAT.matcher(email).matches()) {
            throw fail('Informe um e-mail válido.', 'email');
        }
        String phone = optional(input.phone, MAX_PHONE, 'phone', 'O telefone');
        if (phone != null && !PHONE_FORMAT.matcher(phone).matches()) {
            throw fail('Informe um telefone válido, com DDD.', 'phone');
        }
        String city = optional(input.city, MAX_CITY, 'city', 'A cidade');
        String linkedIn = optional(input.linkedInUrl, MAX_URL, 'linkedInUrl', 'O endereço do LinkedIn');
        if (linkedIn != null && !URL_FORMAT.matcher(linkedIn).matches()) {
            throw fail('Informe o endereço do LinkedIn começando com https://.', 'linkedInUrl');
        }
        String message = optional(input.message, MAX_MESSAGE, 'message', 'A mensagem');
        if (input.consent != true) {
            throw fail(CONSENT_MESSAGE, 'consent');
        }

        Job_Opening__c opening = eligibleOpening(input.slug);
        if (opening == null) {
            throw fail(CLOSED_MESSAGE, null);
        }
        assertUnderDailyLimit(email);

        CandidateService.CandidateInput candidate = new CandidateService.CandidateInput();
        candidate.name = name;
        candidate.email = email;
        candidate.phone = phone;
        candidate.city = city;
        candidate.linkedInUrl = linkedIn;
        candidate.source = SOURCE_PORTAL;
        candidate.consentGiven = true;
        // A versao do termo vem da configuracao do servidor, nunca do navegador.
        candidate.consentTextVersion = consentTextVersion();
        try {
            JobApplicationService.apply(candidate, opening.Id, SOURCE_PORTAL, message);
        } catch (JobApplicationService.RecruitingException e) {
            System.debug(LoggingLevel.WARN, 'Portal: candidatura recusada pelo recrutamento: ' + e.getMessage());
            throw translate(e);
        }
    }

    /** Versao vigente do texto de privacidade (G5), de HR_Setting__mdt. */
    public static String consentTextVersion() {
        return HrSettings.get().Consent_Text_Version__c;
    }

    /**
     * Remove HTML e caracteres de controle de texto livre. keepLineBreaks preserva quebras de linha (mensagem);
     * senao tudo vira uma linha. Devolve null para texto vazio.
     */
    public static String clean(String raw, Boolean keepLineBreaks) {
        if (raw == null) {
            return null;
        }
        String text = raw.replaceAll('(?is)<(script|style)[^>]*>.*?</\\1\\s*>', ' ');
        text = text.replaceAll('(?s)<[^>]*>', ' ');
        text = text.replace('<', ' ').replace('>', ' ');
        text = text.replaceAll('[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]', ' ');
        if (keepLineBreaks == true) {
            text = text.replace('\r\n', '\n').replace('\r', '\n');
            text = text.replaceAll('[ \\t]+', ' ').replaceAll('\\n{3,}', '\n\n');
        } else {
            text = text.replaceAll('\\s+', ' ');
        }
        text = text.trim();
        return String.isEmpty(text) ? null : text;
    }

    private static Job_Opening__c eligibleOpening(String slug) {
        if (String.isBlank(slug) || slug.length() > MAX_SLUG) {
            return null;
        }
        List<Job_Opening__c> rows = [
            SELECT
                Name,
                Public_Slug__c,
                Department__r.Name,
                Location__c,
                Work_Model__c,
                Employment_Type__c,
                Description__c,
                Requirements__c,
                Opened_Date__c
            FROM Job_Opening__c
            WHERE Public_Slug__c = :slug AND Status__c = :STATUS_OPEN AND Publish_On_Portal__c = TRUE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static PortalJobDto toDto(Job_Opening__c o, Boolean withText) {
        PortalJobDto dto = new PortalJobDto();
        dto.title = o.Name;
        dto.slug = o.Public_Slug__c;
        dto.department = o.Department__r?.Name;
        dto.location = o.Location__c;
        dto.workModel = o.Work_Model__c;
        dto.employmentType = o.Employment_Type__c;
        dto.openedDate = o.Opened_Date__c;
        if (withText) {
            dto.description = o.Description__c;
            dto.requirements = o.Requirements__c;
        }
        return dto;
    }

    private static void assertNotTooFast(Decimal renderedAt) {
        Decimal configured = HrSettings.get().Portal_Min_Submit_Seconds__c;
        Decimal minSeconds = configured == null ? DEFAULT_MIN_SECONDS : configured;
        if (renderedAt == null || (Datetime.now().getTime() - renderedAt) < (minSeconds * 1000)) {
            throw fail(TOO_FAST_MESSAGE, null);
        }
    }

    private static void assertUnderDailyLimit(String normalizedEmail) {
        Decimal configured = HrSettings.get().Portal_Daily_Limit_Per_Email__c;
        Integer dailyLimit = configured == null ? DEFAULT_DAILY_LIMIT : configured.intValue();
        Integer today = [
            SELECT COUNT()
            FROM Job_Application__c
            WHERE Candidate__r.Email_Normalized__c = :normalizedEmail AND CreatedDate = TODAY
        ];
        if (today >= dailyLimit) {
            throw fail(DAILY_LIMIT_MESSAGE, null);
        }
    }

    /** Campo opcional: limpa o texto e recusa o que passar do limite. */
    private static String optional(String raw, Integer maxLength, String field, String label) {
        String value = clean(raw, field == 'message');
        if (value != null && value.length() > maxLength) {
            throw fail(label + ' pode ter no máximo ' + maxLength + ' caracteres.', field);
        }
        return value;
    }

    /** Traduz erros do recrutamento para mensagens do visitante, sem repassar texto interno. */
    private static PortalException translate(JobApplicationService.RecruitingException e) {
        String text = e.getMessage();
        if (text == JobApplicationTriggerHandler.DUPLICATE_MESSAGE) {
            return fail(text, null);
        }
        if (text == JobApplicationTriggerHandler.CLOSED_OPENING_MESSAGE) {
            return fail(CLOSED_MESSAGE, null);
        }
        return fail(GENERIC_MESSAGE, null);
    }

    private static PortalException fail(String message, String field) {
        PortalException e = new PortalException(message);
        e.field = field;
        return e;
    }
}
