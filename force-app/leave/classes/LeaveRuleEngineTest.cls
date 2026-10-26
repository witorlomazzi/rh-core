/**
 * Testes do motor de regras de ferias. Tudo em memoria: o motor nao consulta nem grava dados.
 * Datas fixas: periodo aquisitivo de 2025 (fim em 31/12/2025), hoje em 02/03/2026 e descanso semanal no domingo.
 */
@IsTest
private class LeaveRuleEngineTest {
    private static final Date TODAY = Date.newInstance(2026, 3, 2);
    private static Integer idSequence = 0;

    private static HR_Setting__mdt settings() {
        return new HR_Setting__mdt(
            Weekly_Rest_Days__c = 'SUN',
            Leave_Min_Notice_Days__c = 30,
            Leave_Max_Splits__c = 3,
            Leave_Min_Main_Period_Days__c = 14,
            Leave_Min_Other_Period_Days__c = 5,
            Leave_Block_Days_Before_Rest__c = 2,
            Leave_Max_Sold_Days_Divisor__c = 3,
            Abono_Deadline_Days_Before_Period_End__c = 15,
            Accrual_Period_Months__c = 12,
            Concession_Warning_Days__c = 60
        );
    }

    private static Id fakeId(SObjectType t) {
        idSequence++;
        return Id.valueOf(t.getDescribe().getKeyPrefix() + String.valueOf(idSequence).leftPad(12, '0'));
    }

    /** Primeira data a partir de 'from' que cai no dia da semana informado (0 = domingo ... 6 = sabado). */
    private static Date nextWeekday(Date fromDate, Integer dow) {
        Date d = fromDate;
        while (HrDateUtils.dayOfWeek(d) != dow) {
            d = d.addDays(1);
        }
        return d;
    }

    /** Uma segunda-feira com mais de 30 dias de antecedencia de TODAY. */
    private static Date validMonday() {
        return nextWeekday(TODAY.addDays(45), 1);
    }

    private static Leave_Accrual_Period__c period(Integer entitled) {
        return new Leave_Accrual_Period__c(
            Start_Date__c = Date.newInstance(2025, 1, 1),
            End_Date__c = Date.newInstance(2025, 12, 31),
            Concession_Deadline__c = Date.newInstance(2026, 12, 31),
            Entitled_Days__c = entitled
        );
    }

    private static Leave_Request__c req(Date startDate, Integer days, Integer sold) {
        return new Leave_Request__c(Start_Date__c = startDate, Days__c = days, Sold_Days__c = sold);
    }

    private static LeaveRuleEngine.Context ctx(Date startDate, Integer days, Integer sold) {
        LeaveRuleEngine.Context c = new LeaveRuleEngine.Context();
        c.period = period(30);
        c.settings = settings();
        c.today = TODAY;
        c.restDays = new Set<Integer>{ 0 };
        c.startDate = startDate;
        c.days = days;
        c.soldDays = sold;
        return c;
    }

    private static LeaveRuleResult find(List<LeaveRuleResult> results, String code) {
        for (LeaveRuleResult r : results) {
            if (r.code == code) {
                return r;
            }
        }
        return null;
    }

    private static void assertBlocked(List<LeaveRuleResult> results, String code) {
        LeaveRuleResult r = find(results, code);
        Assert.isNotNull(r, 'Esperava a regra ' + code + ' em ' + JSON.serialize(results));
        Assert.isTrue(r.blocking, code + ' deveria bloquear');
        Assert.isFalse(String.isBlank(r.message));
    }

    private static void assertAbsent(List<LeaveRuleResult> results, String code) {
        Assert.isNull(find(results, code), 'Nao esperava a regra ' + code + ' em ' + JSON.serialize(results));
    }

    // ------------------------------------------------------------------------------------------------ base

    @IsTest
    static void validRequestHasNoResults() {
        List<LeaveRuleResult> results = LeaveRuleEngine.evaluate(ctx(validMonday(), 30, 0));
        Assert.areEqual(0, results.size(), JSON.serialize(results));
        Assert.isFalse(LeaveRuleEngine.hasBlocking(results));
    }

    @IsTest
    static void invalidInputIsBlocked() {
        LeaveRuleEngine.Context c = ctx(null, 10, 0);
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_DADOS);
        assertBlocked(LeaveRuleEngine.evaluate(ctx(validMonday(), 0, 0)), LeaveRuleEngine.R_DADOS);
        assertBlocked(LeaveRuleEngine.evaluate(ctx(validMonday(), null, 0)), LeaveRuleEngine.R_DADOS);
        assertBlocked(LeaveRuleEngine.evaluate(ctx(validMonday(), 10, -1)), LeaveRuleEngine.R_DADOS);
        LeaveRuleEngine.Context noEnd = ctx(validMonday(), 10, 0);
        noEnd.period.End_Date__c = null;
        assertBlocked(LeaveRuleEngine.evaluate(noEnd), LeaveRuleEngine.R_DADOS);
        LeaveRuleEngine.Context noSettings = ctx(validMonday(), 10, 0);
        noSettings.settings = null;
        assertBlocked(LeaveRuleEngine.evaluate(noSettings), LeaveRuleEngine.R_DADOS);
        assertBlocked(LeaveRuleEngine.evaluate(null), LeaveRuleEngine.R_DADOS);
    }

    @IsTest
    static void missingSettingsFallBackToCltDefaults() {
        LeaveRuleEngine.Context c = ctx(TODAY.addDays(10), 4, 11);
        c.settings = new HR_Setting__mdt();
        List<LeaveRuleResult> results = LeaveRuleEngine.evaluate(c);
        assertBlocked(results, LeaveRuleEngine.R_V3);
        assertBlocked(results, LeaveRuleEngine.R_V6);
        assertBlocked(results, LeaveRuleEngine.R_V8);
    }

    @IsTest
    static void endOfDependsOnStartAndDays() {
        Assert.areEqual(Date.newInstance(2026, 5, 10), LeaveRuleEngine.endOf(req(Date.newInstance(2026, 5, 1), 10, 0)));
        Assert.isNull(LeaveRuleEngine.endOf(new Leave_Request__c()));
    }

    // ------------------------------------------------------------------------------------------------ V1 a V3

    @IsTest
    static void v1PeriodStillInAcquisition() {
        LeaveRuleEngine.Context c = ctx(validMonday(), 10, 0);
        c.period.End_Date__c = TODAY;
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V1);
        c.period.End_Date__c = TODAY.addDays(-1);
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V1);
    }

    @IsTest
    static void v2BalanceDiscountsExistingRequests() {
        LeaveRuleEngine.Context c = ctx(validMonday(), 10, 0);
        c.periodRequests.add(req(validMonday().addDays(60), 25, 0));
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V2);
        c.days = 5;
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V2);
        // gozo e abono somam
        c.days = 3;
        c.soldDays = 3;
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V2);
    }

    @IsTest
    static void v2IgnoresTheRequestBeingValidated() {
        Id selfId = fakeId(Leave_Request__c.SObjectType);
        LeaveRuleEngine.Context c = ctx(validMonday(), 30, 0);
        c.requestId = selfId;
        Leave_Request__c self = req(validMonday(), 30, 0);
        self.Id = selfId;
        c.periodRequests.add(self);
        List<LeaveRuleResult> results = LeaveRuleEngine.evaluate(c);
        assertAbsent(results, LeaveRuleEngine.R_V2);
        assertAbsent(results, LeaveRuleEngine.R_V11);
    }

    @IsTest
    static void v3NoticeBlocksEmployeeAndWarnsWithException() {
        LeaveRuleEngine.Context c = ctx(nextWeekday(TODAY.addDays(10), 1), 10, 0);
        LeaveRuleResult r = find(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V3);
        Assert.isNotNull(r);
        Assert.isTrue(r.blocking);
        c.allowNoticeException = true;
        LeaveRuleResult warned = find(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V3);
        Assert.isNotNull(warned);
        Assert.isFalse(warned.blocking);
        Assert.isTrue(warned.message.contains('exceção'));
        // exatamente 30 dias de antecedencia e permitido
        LeaveRuleEngine.Context ok = ctx(nextWeekday(TODAY.addDays(30), 1), 10, 0);
        assertAbsent(LeaveRuleEngine.evaluate(ok), LeaveRuleEngine.R_V3);
    }

    // ------------------------------------------------------------------------------------------------ V4

    @IsTest
    static void v4FridayBeforeSundayRestIsBlocked() {
        Date friday = nextWeekday(TODAY.addDays(45), 5);
        assertBlocked(LeaveRuleEngine.evaluate(ctx(friday, 10, 0)), LeaveRuleEngine.R_V4);
    }

    @IsTest
    static void v4SaturdayBeforeSundayRestIsBlocked() {
        Date saturday = nextWeekday(TODAY.addDays(45), 6);
        assertBlocked(LeaveRuleEngine.evaluate(ctx(saturday, 10, 0)), LeaveRuleEngine.R_V4);
    }

    @IsTest
    static void v4MondayAndThursdayAreAllowed() {
        assertAbsent(LeaveRuleEngine.evaluate(ctx(validMonday(), 10, 0)), LeaveRuleEngine.R_V4);
        Date thursday = nextWeekday(TODAY.addDays(45), 4);
        assertAbsent(LeaveRuleEngine.evaluate(ctx(thursday, 10, 0)), LeaveRuleEngine.R_V4);
    }

    @IsTest
    static void v4EveOfHolidayIsBlocked() {
        Date monday = validMonday();
        LeaveRuleEngine.Context c = ctx(monday, 10, 0);
        c.holidays = new Set<Date>{ monday.addDays(1) };
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V4);
        // feriado dois dias depois tambem bloqueia
        c.holidays = new Set<Date>{ monday.addDays(2) };
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V4);
        // feriado tres dias depois ja nao
        c.holidays = new Set<Date>{ monday.addDays(3) };
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V4);
    }

    @IsTest
    static void v4UsesConfiguredRestDays() {
        Date monday = validMonday();
        LeaveRuleEngine.Context c = ctx(monday, 10, 0);
        c.restDays = new Set<Integer>{ 3 }; // quarta-feira: segunda e terca ficam proibidas
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V4);
    }

    // ------------------------------------------------------------------------------------------------ V5 a V7

    @IsTest
    static void v5FourthFractionIsBlocked() {
        Date base = validMonday();
        LeaveRuleEngine.Context c = ctx(base.addDays(120), 5, 0);
        c.periodRequests.add(req(base, 14, 0));
        c.periodRequests.add(req(base.addDays(30), 5, 0));
        c.periodRequests.add(req(base.addDays(60), 5, 0));
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V5);
        c.periodRequests.remove(2);
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V5);
    }

    @IsTest
    static void v6FractionBelowMinimumIsBlocked() {
        assertBlocked(LeaveRuleEngine.evaluate(ctx(validMonday(), 4, 0)), LeaveRuleEngine.R_V6);
        assertAbsent(LeaveRuleEngine.evaluate(ctx(validMonday(), 5, 0)), LeaveRuleEngine.R_V6);
    }

    @IsTest
    static void v7ScenarioFourteenTenSixIsValid() {
        Date base = validMonday();
        // 14 sozinho
        Assert.areEqual(0, LeaveRuleEngine.evaluate(ctx(base, 14, 0)).size());
        // 10 com 14 ja existente
        LeaveRuleEngine.Context second = ctx(base.addDays(42), 10, 0);
        second.periodRequests.add(req(base, 14, 0));
        Assert.areEqual(0, LeaveRuleEngine.evaluate(second).size());
        // 6 com 14 e 10 existentes: totaliza 30
        LeaveRuleEngine.Context third = ctx(base.addDays(84), 6, 0);
        third.periodRequests.add(req(base, 14, 0));
        third.periodRequests.add(req(base.addDays(42), 10, 0));
        Assert.areEqual(0, LeaveRuleEngine.evaluate(third).size());
    }

    @IsTest
    static void v7ScenarioFiveFiveTwentyIsValid() {
        Date base = validMonday();
        Assert.areEqual(0, LeaveRuleEngine.evaluate(ctx(base, 5, 0)).size());
        LeaveRuleEngine.Context second = ctx(base.addDays(42), 5, 0);
        second.periodRequests.add(req(base, 5, 0));
        Assert.areEqual(0, LeaveRuleEngine.evaluate(second).size());
        LeaveRuleEngine.Context third = ctx(base.addDays(84), 20, 0);
        third.periodRequests.add(req(base, 5, 0));
        third.periodRequests.add(req(base.addDays(42), 5, 0));
        Assert.areEqual(0, LeaveRuleEngine.evaluate(third).size());
    }

    @IsTest
    static void v7ScenarioFiveFiveFiveIsInvalid() {
        Date base = validMonday();
        LeaveRuleEngine.Context third = ctx(base.addDays(84), 5, 0);
        third.periodRequests.add(req(base, 5, 0));
        third.periodRequests.add(req(base.addDays(42), 5, 0));
        assertBlocked(LeaveRuleEngine.evaluate(third), LeaveRuleEngine.R_V7);
    }

    @IsTest
    static void v7TwoShortFractionsAndShortThirdIsInvalid() {
        Date base = validMonday();
        LeaveRuleEngine.Context third = ctx(base.addDays(84), 10, 0);
        third.periodRequests.add(req(base, 5, 0));
        third.periodRequests.add(req(base.addDays(42), 5, 0));
        assertBlocked(LeaveRuleEngine.evaluate(third), LeaveRuleEngine.R_V7);
    }

    @IsTest
    static void v7RemainingBalanceMustStillAllowMainFraction() {
        Date base = validMonday();
        // 30 dias de direito, 10 vendidos: sobram 20. Uma fracao de 10 deixa 10, que nao comporta os 14.
        LeaveRuleEngine.Context c = ctx(base, 10, 10);
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V7);
        // fracao de 5 deixa 15 e ainda comporta os 14
        c.days = 5;
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V7);
    }

    @IsTest
    static void v7ReducedEntitlementUsesEntitlementAsMainMinimum() {
        LeaveRuleEngine.Context c = ctx(validMonday(), 12, 0);
        c.period.Entitled_Days__c = 12;
        Assert.areEqual(0, LeaveRuleEngine.evaluate(c).size(), 'Direito de 12 dias tira em uma fracao unica');
        c.days = 6;
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V7);
    }

    // ------------------------------------------------------------------------------------------------ V8 a V10

    @IsTest
    static void v8SoldElevenOfThirtyIsBlocked() {
        assertBlocked(LeaveRuleEngine.evaluate(ctx(validMonday(), 19, 11)), LeaveRuleEngine.R_V8);
        assertAbsent(LeaveRuleEngine.evaluate(ctx(validMonday(), 20, 10)), LeaveRuleEngine.R_V8);
    }

    @IsTest
    static void v8CountsSoldDaysAlreadyUsedInThePeriod() {
        LeaveRuleEngine.Context c = ctx(validMonday(), 14, 5);
        c.periodRequests.add(req(validMonday().addDays(60), 6, 6));
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V8);
    }

    @IsTest
    static void v8ScalesWithReducedEntitlement() {
        LeaveRuleEngine.Context c = ctx(validMonday(), 14, 9);
        c.period.Entitled_Days__c = 24;
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V8);
        c.soldDays = 8;
        c.days = 14;
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V8);
    }

    @IsTest
    static void v9SoldRequestedAfterDeadlineWarns() {
        LeaveRuleResult warn = find(LeaveRuleEngine.evaluate(ctx(validMonday(), 20, 10)), LeaveRuleEngine.R_V9);
        Assert.isNotNull(warn);
        Assert.isFalse(warn.blocking);
        Assert.areEqual('O abono pedido fora do prazo depende de concordância da empresa.', warn.message);
        assertAbsent(LeaveRuleEngine.evaluate(ctx(validMonday(), 30, 0)), LeaveRuleEngine.R_V9);
    }

    @IsTest
    static void v9NoWarningWhenInsideDeadline() {
        // Hoje 30 dias antes do fim do periodo: dentro do prazo (o periodo ainda nao terminou, entao V1 bloqueia)
        LeaveRuleEngine.Context c = ctx(validMonday(), 20, 10);
        c.period.End_Date__c = TODAY.addDays(30);
        List<LeaveRuleResult> results = LeaveRuleEngine.evaluate(c);
        assertAbsent(results, LeaveRuleEngine.R_V9);
        assertBlocked(results, LeaveRuleEngine.R_V1);
    }

    @IsTest
    static void v10EndAfterConcessionDeadlineWarns() {
        LeaveRuleEngine.Context c = ctx(validMonday(), 10, 0);
        c.period.Concession_Deadline__c = validMonday().addDays(5);
        LeaveRuleResult warn = find(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V10);
        Assert.isNotNull(warn);
        Assert.isFalse(warn.blocking);
        Assert.isTrue(warn.message.contains('em dobro'));
        c.period.Concession_Deadline__c = validMonday().addDays(9);
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V10);
    }

    // ------------------------------------------------------------------------------------------------ V11 e V12

    @IsTest
    static void v11OverlapWithSamePeriodRequestIsBlocked() {
        Date base = validMonday();
        LeaveRuleEngine.Context c = ctx(base.addDays(10), 10, 0);
        c.periodRequests.add(req(base, 14, 0)); // base .. base+13
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V11);
        c.startDate = base.addDays(14);
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V11);
    }

    @IsTest
    static void v11OverlapWithAnotherPeriodRequestIsBlocked() {
        Date base = validMonday();
        LeaveRuleEngine.Context c = ctx(base, 10, 0);
        c.otherPeriodRequests.add(req(base.addDays(9), 5, 0));
        assertBlocked(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V11);
        c.otherPeriodRequests.clear();
        c.otherPeriodRequests.add(req(base.addDays(10), 5, 0));
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V11);
    }

    @IsTest
    static void v12TeamConflictWarnsWithoutBlocking() {
        Date base = validMonday();
        LeaveRuleEngine.Context c = ctx(base, 10, 0);
        Id colleagueA = fakeId(Employee__c.SObjectType);
        Id colleagueB = fakeId(Employee__c.SObjectType);
        Leave_Request__c a = req(base.addDays(5), 10, 0);
        a.Employee__c = colleagueA;
        Leave_Request__c a2 = req(base.addDays(8), 5, 0);
        a2.Employee__c = colleagueA;
        Leave_Request__c b = req(base.addDays(9), 3, 0);
        b.Employee__c = colleagueB;
        Leave_Request__c far = req(base.addDays(60), 10, 0);
        far.Employee__c = fakeId(Employee__c.SObjectType);
        c.teamRequests = new List<Leave_Request__c>{ a, a2, b, far };
        List<LeaveRuleResult> results = LeaveRuleEngine.evaluate(c);
        LeaveRuleResult warn = find(results, LeaveRuleEngine.R_V12);
        Assert.isNotNull(warn);
        Assert.isFalse(warn.blocking);
        Assert.isTrue(warn.message.contains('2 colegas'), warn.message);
        Assert.isFalse(LeaveRuleEngine.hasBlocking(results));
    }

    @IsTest
    static void v12SingleColleagueAndNoConflict() {
        Date base = validMonday();
        LeaveRuleEngine.Context c = ctx(base, 10, 0);
        Leave_Request__c one = req(base, 5, 0);
        c.teamRequests = new List<Leave_Request__c>{ one };
        LeaveRuleResult warn = find(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V12);
        Assert.isTrue(warn.message.contains('1 colega '), warn.message);
        c.teamRequests = new List<Leave_Request__c>{ req(base.addDays(42), 5, 0) };
        assertAbsent(LeaveRuleEngine.evaluate(c), LeaveRuleEngine.R_V12);
    }

    @IsTest
    static void catalogCoversEveryRule() {
        Assert.areEqual(12, LeaveRuleEngine.RULE_CODES.size());
        for (String code : LeaveRuleEngine.RULE_CODES) {
            Assert.isTrue(LeaveRuleEngine.RULE_TITLES.containsKey(code), code);
        }
    }
}
