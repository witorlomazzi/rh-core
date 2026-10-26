/**
 * Compartilhamento de Performance_Review__c (spec 02): avaliador, cadeia de gestores, outra equipe, colega e o
 * colaborador somente depois da liberacao. Cobre os itens 1, 2, 3 e 4 dos testes de seguranca obrigatorios.
 */
@IsTest
private class PerformanceSharingServiceTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    private static Review_Cycle__c cycleWithEveryone(HrTestDataFactory.OrgTree t) {
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);
        System.runAs(t.hrUser) {
            // Colaboradores 3 (outra equipe) e 4 (subordinado indireto do gestor 1) nao tem usuario: entram por createRecords
            ReviewCycleService.createRecords(cycle, new List<Employee__c>{ t.emp3, t.emp4 }, new ReviewCycleService.LaunchResult());
        }
        return cycle;
    }

    private static Set<Id> visibleReviewIds(User u, Id cycleId) {
        Set<Id> ids = new Set<Id>();
        System.runAs(u) {
            for (Performance_Review__c r : PerformanceReviewSelector.byCycle(cycleId)) {
                ids.add(r.Id);
            }
        }
        return ids;
    }

    @IsTest
    static void managerSeesDirectAndIndirectReportsButNotOtherTeams() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithEveryone(t);
        Id emp1Review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id).Id;
        Id emp2Review = PerformanceTestSupport.reviewOf(t.emp2.Id, cycle.Id).Id;
        Id emp3Review = PerformanceTestSupport.reviewOf(t.emp3.Id, cycle.Id).Id;
        Id emp4Review = PerformanceTestSupport.reviewOf(t.emp4.Id, cycle.Id).Id;

        Set<Id> seenByMgr1 = visibleReviewIds(t.mgr1User, cycle.Id);
        Assert.isTrue(seenByMgr1.contains(emp1Review), 'Subordinado direto');
        Assert.isTrue(seenByMgr1.contains(emp2Review), 'Subordinado direto');
        Assert.isTrue(seenByMgr1.contains(emp4Review), 'Subordinado indireto');
        Assert.isFalse(seenByMgr1.contains(emp3Review), 'Gestor de outra equipe nao ve a avaliacao');

        System.runAs(t.mgr1User) {
            Assert.isNull(PerformanceReviewSelector.byId(emp3Review), 'Leitura direta tambem nao devolve');
            try {
                PerformanceReviewController.getReviewForm(emp3Review);
                Assert.fail('Formulario da avaliacao de outra equipe');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('sem acesso'));
            }
            PerformanceReviewController.TeamView team = PerformanceReviewController.getTeam(cycle.Id);
            Set<Id> employeesInTeam = new Set<Id>();
            for (PerformanceReviewController.TeamRow row : team.rows) {
                employeesInTeam.add(row.employeeId);
            }
            Assert.isFalse(employeesInTeam.contains(t.emp3.Id));
            Assert.isFalse(employeesInTeam.contains(t.mgr1.Id), 'Gestor nao lista a propria avaliacao como equipe');
            Assert.isTrue(employeesInTeam.contains(t.emp4.Id));
        }
    }

    @IsTest
    static void peerAndEmployeeDoNotSeeAnyReviewBeforeRelease() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithEveryone(t);
        Assert.isTrue(visibleReviewIds(t.emp2User, cycle.Id).isEmpty(), 'Colega e o proprio colaborador nao leem');
        // O colaborador 1 e gestor do 4: so enxerga a avaliacao dele, nunca a propria nem a do colega
        Set<Id> seenByEmp1 = visibleReviewIds(t.emp1User, cycle.Id);
        Assert.areEqual(1, seenByEmp1.size());
        Assert.isTrue(seenByEmp1.contains(PerformanceTestSupport.reviewOf(t.emp4.Id, cycle.Id).Id));
        // RH ve todas
        Assert.isTrue(visibleReviewIds(t.hrUser, cycle.Id).size() >= 5);
    }

    @IsTest
    static void reviewerHasEditUntilSendingAndReadAfterwards() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithEveryone(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp1.Id, cycle.Id);
        Assert.areEqual('Edit', accessOf(review.Id, t.mgr1User.Id, PerformanceSharingService.CHAIN_REASON));
        System.runAs(t.mgr1User) {
            PerformanceReviewService.saveManagerReview(review.Id, 4, 'Bom', false);
            Assert.areEqual('Edit', accessOf(review.Id, t.mgr1User.Id, PerformanceSharingService.CHAIN_REASON), 'Em andamento ainda edita');
            PerformanceReviewService.saveManagerReview(review.Id, 4, 'Bom', true);
        }
        Assert.areEqual('Read', accessOf(review.Id, t.mgr1User.Id, PerformanceSharingService.CHAIN_REASON), 'Enviada: so leitura');
        // Avaliacao do colaborador 4: o gestor direto (colaborador 1) edita e o gestor 1 so le
        Performance_Review__c review4 = PerformanceTestSupport.reviewOf(t.emp4.Id, cycle.Id);
        Assert.areEqual('Edit', accessOf(review4.Id, t.emp1User.Id, PerformanceSharingService.CHAIN_REASON));
        Assert.areEqual('Read', accessOf(review4.Id, t.mgr1User.Id, PerformanceSharingService.CHAIN_REASON));
        Assert.areEqual(0, PerformanceTestSupport.shareCount(review4.Id, t.emp2User.Id, PerformanceSharingService.CHAIN_REASON));
    }

    @IsTest
    static void employeeGetsReadShareOnlyAfterRelease() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = cycleWithEveryone(t);
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Performance_Review__c review = PerformanceTestSupport.reviewOf(t.emp2.Id, cycle.Id);
        System.runAs(t.mgr1User) {
            PerformanceReviewService.saveManagerReview(review.Id, 3, 'Regular', true);
        }
        PerformanceTestSupport.advance(t.hrUser, cycle.Id);
        Assert.areEqual(0, PerformanceTestSupport.shareCount(review.Id, t.emp2User.Id, PerformanceSharingService.RELEASE_REASON));
        System.runAs(t.hrUser) {
            ReviewCycleService.release(cycle.Id);
        }
        Assert.areEqual(1, PerformanceTestSupport.shareCount(review.Id, t.emp2User.Id, PerformanceSharingService.RELEASE_REASON));
        Assert.areEqual('Read', accessOf(review.Id, t.emp2User.Id, PerformanceSharingService.RELEASE_REASON));
        Assert.isTrue(visibleReviewIds(t.emp2User, cycle.Id).contains(review.Id), 'Colaborador le depois da liberacao');
        // Os colegas e a outra equipe continuam sem acesso
        Assert.isFalse(visibleReviewIds(t.emp1User, cycle.Id).contains(review.Id), 'Colega nao le a avaliacao liberada do outro');
    }

    @IsTest
    static void syncIgnoresEmptyInput() {
        PerformanceSharingService.sync(null);
        PerformanceSharingService.sync(new List<Performance_Review__c>());
        Assert.areEqual(0, [SELECT COUNT() FROM Performance_Review__Share WHERE RowCause = :PerformanceSharingService.CHAIN_REASON]);
    }

    private static String accessOf(Id reviewId, Id userId, String reason) {
        List<Performance_Review__Share> rows = [
            SELECT AccessLevel
            FROM Performance_Review__Share
            WHERE ParentId = :reviewId AND UserOrGroupId = :userId AND RowCause = :reason
        ];
        return rows.isEmpty() ? null : rows[0].AccessLevel;
    }
}
