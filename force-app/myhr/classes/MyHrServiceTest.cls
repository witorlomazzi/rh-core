/**
 * Testes puros dos auxiliares do MyHrService (tempo de casa e iniciais), sem dados de banco.
 */
@IsTest
private class MyHrServiceTest {
    @IsTest
    static void tenureCountsCompleteMonths() {
        Date ref = Date.newInstance(2026, 10, 26);
        Assert.areEqual(12, MyHrService.tenureMonths(Date.newInstance(2025, 10, 26), ref));
        Assert.areEqual(11, MyHrService.tenureMonths(Date.newInstance(2025, 10, 27), ref), 'Falta um dia para completar');
        Assert.areEqual(0, MyHrService.tenureMonths(Date.newInstance(2026, 10, 1), ref));
        Assert.areEqual(0, MyHrService.tenureMonths(Date.newInstance(2026, 12, 1), ref), 'Admissao futura');
        Assert.areEqual(0, MyHrService.tenureMonths(null, ref));
        Assert.areEqual(75, MyHrService.tenureMonths(Date.newInstance(2020, 7, 10), ref));
    }

    @IsTest
    static void initialsUseFirstAndLastName() {
        Assert.areEqual('AS', MyHrService.initialsOf('Ana Maria Souza'));
        Assert.areEqual('B', MyHrService.initialsOf('bruno'));
        Assert.areEqual('', MyHrService.initialsOf(null));
        Assert.areEqual('', MyHrService.initialsOf('   '));
    }

    @IsTest
    static void dtoDefaultsAreEmpty() {
        MyHrService.TeamMember m = new MyHrService.TeamMember();
        Assert.isFalse(m.deadlineAlert);
        Assert.areEqual(0, m.balanceDays);
        MyHrService.TeamOverview v = new MyHrService.TeamOverview();
        Assert.isTrue(v.members.isEmpty());
    }
}
