/**
 * Motor de regras de ferias da CLT (arts. 130, 134, 135, 137 e 143). Classe pura: nao faz consulta nem DML, recebe
 * tudo pelo Context e devolve somente as regras violadas (bloqueantes ou avisos). Todos os parametros vem de
 * HR_Setting__mdt. Quem monta o Context (LeaveRequestService) carrega os dados em USER_MODE ou no contexto de
 * sistema documentado na spec 02.
 *
 * Decisao: a quantidade de dias de gozo exigida no periodo principal e limitada ao direito do periodo
 * (ex.: 12 dias de direito exigem uma fracao unica de 12), para nao tornar impossivel quem tem direito reduzido.
 */
public with sharing class LeaveRuleEngine {
    public static final String R_DADOS = 'DADOS_INVALIDOS';
    public static final String R_V1 = 'PERIODO_NAO_ADQUIRIDO';
    public static final String R_V2 = 'SALDO_INSUFICIENTE';
    public static final String R_V3 = 'ANTECEDENCIA';
    public static final String R_V4 = 'INICIO_ANTES_DESCANSO';
    public static final String R_V5 = 'QUANTIDADE_PERIODOS';
    public static final String R_V6 = 'MINIMO_FRACAO';
    public static final String R_V7 = 'PERIODO_PRINCIPAL';
    public static final String R_V8 = 'ABONO_LIMITE';
    public static final String R_V9 = 'ABONO_PRAZO';
    public static final String R_V10 = 'PRAZO_CONCESSIVO';
    public static final String R_V11 = 'SOBREPOSICAO';
    public static final String R_V12 = 'CONFLITO_EQUIPE';

    /** Codigos na ordem de exibicao, com o titulo curto de cada regra (usado pelas telas para listar as que passaram). */
    public static final List<String> RULE_CODES = new List<String>{
        R_V1, R_V2, R_V3, R_V4, R_V5, R_V6, R_V7, R_V8, R_V9, R_V10, R_V11, R_V12
    };
    public static final Map<String, String> RULE_TITLES = new Map<String, String>{
        R_V1 => 'Período aquisitivo concluído',
        R_V2 => 'Saldo suficiente',
        R_V3 => 'Antecedência mínima',
        R_V4 => 'Início fora dos dias que antecedem descanso ou feriado',
        R_V5 => 'Quantidade de frações',
        R_V6 => 'Tamanho mínimo da fração',
        R_V7 => 'Fração principal',
        R_V8 => 'Limite do abono pecuniário',
        R_V9 => 'Prazo do abono',
        R_V10 => 'Prazo concessivo',
        R_V11 => 'Sem sobreposição com outras férias',
        R_V12 => 'Sem conflito com a equipe'
    };

    /** Dados de entrada do motor. Listas nunca nulas; solicitacoes canceladas e rejeitadas ja vem filtradas. */
    public class Context {
        public Leave_Accrual_Period__c period;
        /** Outras solicitacoes do mesmo periodo (a que esta sendo validada pode estar na lista: sai pelo requestId). */
        public List<Leave_Request__c> periodRequests = new List<Leave_Request__c>();
        /** Solicitacoes do mesmo colaborador em outros periodos (so para detectar sobreposicao). */
        public List<Leave_Request__c> otherPeriodRequests = new List<Leave_Request__c>();
        /** Solicitacoes pendentes ou aprovadas de colegas com o mesmo gestor direto. */
        public List<Leave_Request__c> teamRequests = new List<Leave_Request__c>();
        /** Dias de descanso semanal: 0 = domingo ... 6 = sabado. */
        public Set<Integer> restDays = new Set<Integer>();
        public Set<Date> holidays = new Set<Date>();
        public HR_Setting__mdt settings;
        public Date today;
        /** Excecao de antecedencia concedida pelo RH. */
        public Boolean allowNoticeException = false;
        // Pedido que esta sendo validado
        public Id requestId;
        public Date startDate;
        public Integer days;
        public Integer soldDays;
    }

    public static List<LeaveRuleResult> evaluate(Context c) {
        List<LeaveRuleResult> out = new List<LeaveRuleResult>();
        String invalid = invalidInput(c);
        if (invalid != null) {
            out.add(new LeaveRuleResult(R_DADOS, true, invalid));
            return out;
        }
        Integer days = c.days;
        Integer sold = c.soldDays == null ? 0 : c.soldDays;
        Date endDate = c.startDate.addDays(days - 1);
        Decimal entitled = c.period.Entitled_Days__c == null ? 0 : c.period.Entitled_Days__c;
        List<Leave_Request__c> others = excludeSelf(c.periodRequests, c.requestId);

        addIfPresent(out, v1PeriodAcquired(c));
        addIfPresent(out, v2Balance(c, others, entitled, days, sold));
        addIfPresent(out, v3Notice(c));
        addIfPresent(out, v4BeforeRest(c));
        addIfPresent(out, v5Splits(c, others));
        addIfPresent(out, v6MinimumFraction(c, days));
        addIfPresent(out, v7MainPeriod(c, others, entitled, days, sold));
        addIfPresent(out, v8SoldLimit(c, others, entitled, sold));
        addIfPresent(out, v9SoldDeadline(c, sold));
        addIfPresent(out, v10Concession(c, endDate));
        addIfPresent(out, v11Overlap(c, others, endDate));
        addIfPresent(out, v12TeamConflict(c, endDate));
        return out;
    }

    /** Verdadeiro se algum resultado bloqueia o envio. */
    public static Boolean hasBlocking(List<LeaveRuleResult> results) {
        for (LeaveRuleResult r : results) {
            if (r.blocking) {
                return true;
            }
        }
        return false;
    }

    /** Fim das ferias de uma solicitacao (a formula End_Date__c nao existe em registros em memoria). */
    public static Date endOf(Leave_Request__c r) {
        if (r.Start_Date__c == null || r.Days__c == null) {
            return null;
        }
        return r.Start_Date__c.addDays(r.Days__c.intValue() - 1);
    }

    // ------------------------------------------------------------------------------------------------ regras

    private static String invalidInput(Context c) {
        if (c == null || c.period == null || c.settings == null || c.today == null) {
            return 'Não foi possível validar: faltam dados do período ou da configuração.';
        }
        if (c.startDate == null) {
            return 'Informe a data de início das férias.';
        }
        if (c.days == null || c.days < 1) {
            return 'Informe a quantidade de dias de férias (mínimo 1).';
        }
        if (c.soldDays != null && c.soldDays < 0) {
            return 'A quantidade de dias vendidos não pode ser negativa.';
        }
        if (c.period.End_Date__c == null) {
            return 'O período aquisitivo não tem data final.';
        }
        return null;
    }

    private static LeaveRuleResult v1PeriodAcquired(Context c) {
        if (c.today <= c.period.End_Date__c) {
            return new LeaveRuleResult(
                R_V1,
                true,
                'O período aquisitivo termina em ' + formatDate(c.period.End_Date__c) + '. As férias só podem ser tiradas depois disso.'
            );
        }
        return null;
    }

    private static LeaveRuleResult v2Balance(Context c, List<Leave_Request__c> others, Decimal entitled, Integer days, Integer sold) {
        Decimal used = 0;
        for (Leave_Request__c r : others) {
            used += nz(r.Days__c) + nz(r.Sold_Days__c);
        }
        Decimal balance = entitled - used;
        if (days + sold > balance) {
            return new LeaveRuleResult(
                R_V2,
                true,
                'O pedido usa ' + (days + sold) + ' dias (gozo e abono), mas o saldo do período é de ' + balance.intValue() + '.'
            );
        }
        return null;
    }

    private static LeaveRuleResult v3Notice(Context c) {
        Integer minNotice = num(c.settings.Leave_Min_Notice_Days__c, 30);
        if (c.today.daysBetween(c.startDate) >= minNotice) {
            return null;
        }
        if (c.allowNoticeException == true) {
            return new LeaveRuleResult(R_V3, false, 'Antecedência mínima de ' + minNotice + ' dias dispensada por exceção do RH.');
        }
        return new LeaveRuleResult(
            R_V3,
            true,
            'O início precisa ter pelo menos ' + minNotice + ' dias de antecedência a partir de hoje.'
        );
    }

    private static LeaveRuleResult v4BeforeRest(Context c) {
        Integer blockDays = num(c.settings.Leave_Block_Days_Before_Rest__c, 2);
        for (Integer i = 1; i <= blockDays; i++) {
            Date d = c.startDate.addDays(i);
            if (c.restDays.contains(HrDateUtils.dayOfWeek(d)) || c.holidays.contains(d)) {
                return new LeaveRuleResult(
                    R_V4,
                    true,
                    'O início não pode ocorrer nos ' +
                        blockDays +
                        ' dias que antecedem feriado ou descanso semanal (' +
                        formatDate(d) +
                        '). Art. 134, § 3º da CLT.'
                );
            }
        }
        return null;
    }

    private static LeaveRuleResult v5Splits(Context c, List<Leave_Request__c> others) {
        Integer maxSplits = num(c.settings.Leave_Max_Splits__c, 3);
        if (others.size() + 1 > maxSplits) {
            return new LeaveRuleResult(
                R_V5,
                true,
                'O período aquisitivo aceita no máximo ' + maxSplits + ' frações de férias.'
            );
        }
        return null;
    }

    private static LeaveRuleResult v6MinimumFraction(Context c, Integer days) {
        Integer minOther = num(c.settings.Leave_Min_Other_Period_Days__c, 5);
        if (days < minOther) {
            return new LeaveRuleResult(R_V6, true, 'Cada fração de férias deve ter pelo menos ' + minOther + ' dias.');
        }
        return null;
    }

    private static LeaveRuleResult v7MainPeriod(
        Context c,
        List<Leave_Request__c> others,
        Decimal entitled,
        Integer days,
        Integer sold
    ) {
        Integer maxSplits = num(c.settings.Leave_Max_Splits__c, 3);
        Integer mainMin = Math.min(num(c.settings.Leave_Min_Main_Period_Days__c, 14), entitled.intValue());
        Integer fractions = others.size() + 1;
        Decimal sumDays = days;
        Decimal soldTotal = sold;
        Boolean hasMain = days >= mainMin;
        for (Leave_Request__c r : others) {
            sumDays += nz(r.Days__c);
            soldTotal += nz(r.Sold_Days__c);
            if (nz(r.Days__c) >= mainMin) {
                hasMain = true;
            }
        }
        if (hasMain) {
            return null;
        }
        Decimal remaining = entitled - soldTotal - sumDays;
        if (fractions >= maxSplits || remaining < mainMin) {
            return new LeaveRuleResult(
                R_V7,
                true,
                'Uma das frações precisa ter pelo menos ' +
                    mainMin +
                    ' dias. Com este pedido, o período não conseguiria mais cumprir essa regra.'
            );
        }
        return null;
    }

    private static LeaveRuleResult v8SoldLimit(Context c, List<Leave_Request__c> others, Decimal entitled, Integer sold) {
        Integer divisor = num(c.settings.Leave_Max_Sold_Days_Divisor__c, 3);
        if (divisor < 1) {
            divisor = 3;
        }
        Integer maxSold = (entitled / divisor).intValue();
        Decimal soldTotal = sold;
        for (Leave_Request__c r : others) {
            soldTotal += nz(r.Sold_Days__c);
        }
        if (soldTotal > maxSold) {
            return new LeaveRuleResult(
                R_V8,
                true,
                'O abono pecuniário é limitado a ' + maxSold + ' dias neste período (um terço do direito). Art. 143 da CLT.'
            );
        }
        return null;
    }

    private static LeaveRuleResult v9SoldDeadline(Context c, Integer sold) {
        if (sold <= 0) {
            return null;
        }
        Integer deadlineDays = num(c.settings.Abono_Deadline_Days_Before_Period_End__c, 15);
        if (c.today > c.period.End_Date__c.addDays(-deadlineDays)) {
            return new LeaveRuleResult(R_V9, false, 'O abono pedido fora do prazo depende de concordância da empresa.');
        }
        return null;
    }

    private static LeaveRuleResult v10Concession(Context c, Date endDate) {
        if (c.period.Concession_Deadline__c != null && endDate > c.period.Concession_Deadline__c) {
            return new LeaveRuleResult(
                R_V10,
                false,
                'Férias após o prazo concessivo são devidas em dobro (art. 137 da CLT).'
            );
        }
        return null;
    }

    private static LeaveRuleResult v11Overlap(Context c, List<Leave_Request__c> others, Date endDate) {
        List<Leave_Request__c> all = new List<Leave_Request__c>(others);
        all.addAll(excludeSelf(c.otherPeriodRequests, c.requestId));
        for (Leave_Request__c r : all) {
            Date otherEnd = endOf(r);
            if (r.Start_Date__c != null && otherEnd != null && r.Start_Date__c <= endDate && otherEnd >= c.startDate) {
                return new LeaveRuleResult(
                    R_V11,
                    true,
                    'As datas coincidem com outro pedido seu (' + formatDate(r.Start_Date__c) + ' a ' + formatDate(otherEnd) + ').'
                );
            }
        }
        return null;
    }

    private static LeaveRuleResult v12TeamConflict(Context c, Date endDate) {
        Set<Id> people = new Set<Id>();
        Integer anonymous = 0;
        for (Leave_Request__c r : c.teamRequests) {
            Date otherEnd = endOf(r);
            if (r.Start_Date__c != null && otherEnd != null && r.Start_Date__c <= endDate && otherEnd >= c.startDate) {
                if (r.Employee__c == null) {
                    anonymous++;
                } else {
                    people.add(r.Employee__c);
                }
            }
        }
        Integer count = people.size() + anonymous;
        if (count == 0) {
            return null;
        }
        return new LeaveRuleResult(
            R_V12,
            false,
            'Coincide com as férias de ' + count + (count == 1 ? ' colega' : ' colegas') + ' da mesma equipe no período.'
        );
    }

    // ------------------------------------------------------------------------------------------------ apoio

    private static void addIfPresent(List<LeaveRuleResult> out, LeaveRuleResult r) {
        if (r != null) {
            out.add(r);
        }
    }

    private static List<Leave_Request__c> excludeSelf(List<Leave_Request__c> source, Id requestId) {
        List<Leave_Request__c> result = new List<Leave_Request__c>();
        for (Leave_Request__c r : source) {
            if (requestId == null || r.Id != requestId) {
                result.add(r);
            }
        }
        return result;
    }

    private static Decimal nz(Decimal value) {
        return value == null ? 0 : value;
    }

    private static Integer num(Decimal value, Integer fallback) {
        return value == null ? fallback : value.intValue();
    }

    public static String formatDate(Date d) {
        return String.valueOf(d.day()).leftPad(2, '0') + '/' + String.valueOf(d.month()).leftPad(2, '0') + '/' + d.year();
    }
}
