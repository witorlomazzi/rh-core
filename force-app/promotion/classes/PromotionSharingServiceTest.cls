@IsTest
private class PromotionSharingServiceTest {
    @TestSetup
    static void setup() {
        PromotionTestSupport.createAll();
    }

    private static Id requestOf(User requester, Id employeeId, Id positionId) {
        PromotionService.SubmitResult r;
        System.runAs(requester) {
            r = PromotionService.createAndSubmit(employeeId, positionId, Date.today().addDays(10), 'ZZTEST-Compartilhamento');
        }
        return r.requestId;
    }

    private static List<Promotion_Request__Share> chainShares(Id requestId) {
        return [
            SELECT UserOrGroupId, AccessLevel
            FROM Promotion_Request__Share
            WHERE ParentId = :requestId AND RowCause = :PromotionSharingService.REASON
        ];
    }

    private static Id hrGroupId() {
        return [SELECT Id FROM Group WHERE DeveloperName = 'HR_Team' AND Type = 'Regular' LIMIT 1].Id;
    }

    @IsTest
    static void sharesWithSecondLevelApproverAndHrGroup() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId = requestOf(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id);
        Set<Id> targets = new Set<Id>();
        for (Promotion_Request__Share s : chainShares(requestId)) {
            targets.add(s.UserOrGroupId);
            System.assertEquals('Read', s.AccessLevel);
        }
        System.assertEquals(new Set<Id>{ c.tree.mgr1User.Id, hrGroupId() }, targets);
    }

    @IsTest
    static void doesNotShareWithTheOwnerAsApprover() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        // O gestor 1 e ao mesmo tempo solicitante e aprovador de segundo nivel de emp1 (cadeia: gestor 1, CEO).
        Id requestId = requestOf(c.tree.mgr1User, c.tree.emp1.Id, c.posB.Id);
        List<Promotion_Request__Share> shares = chainShares(requestId);
        System.assertEquals(1, shares.size());
        System.assertEquals(hrGroupId(), shares[0].UserOrGroupId);
    }

    @IsTest
    static void recalculationIsIdempotentAndRemovesObsoleteShares() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id requestId = requestOf(c.tree.emp1User, c.tree.emp4.Id, c.posB.Id);
        PromotionSharingService.recalculate(new Set<Id>{ requestId });
        System.assertEquals(2, chainShares(requestId).size(), 'Segunda execucao nao duplica');

        // O colaborador muda para a equipe do gestor 2 (sem usuario): o share do gestor 1 deixa de valer.
        update new Employee__c(Id = c.tree.emp4.Id, Manager__c = c.tree.mgr2.Id);
        PromotionSharingService.recalculate(new Set<Id>{ requestId });
        List<Promotion_Request__Share> shares = chainShares(requestId);
        System.assertEquals(1, shares.size());
        System.assertEquals(hrGroupId(), shares[0].UserOrGroupId);
    }

    @IsTest
    static void missingHrGroupGrantsNoGroupShare() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        List<Promotion_Request__c> rows = PromotionTestSupport.approvedRequests(
            new List<Employee__c>{ c.tree.emp4 },
            c.posB.Id,
            6000,
            Date.today()
        );
        HrSettings.testOverride = new HR_Setting__mdt(HR_Group_Developer_Name__c = 'ZZTEST_Grupo_Inexistente');
        PromotionSharingService.recalculate(new Set<Id>{ rows[0].Id });
        List<Promotion_Request__Share> shares = chainShares(rows[0].Id);
        System.assertEquals(1, shares.size(), 'So o aprovador de segundo nivel');
        System.assertEquals(c.tree.mgr1User.Id, shares[0].UserOrGroupId);
    }

    @IsTest
    static void emptyInputIsIgnored() {
        PromotionSharingService.recalculate(null);
        PromotionSharingService.recalculate(new Set<Id>());
        System.assertEquals(0, [SELECT COUNT() FROM Promotion_Request__Share WHERE RowCause = :PromotionSharingService.REASON]);
    }

    @IsTest
    static void approverResolution() {
        PromotionTestSupport.Ctx c = PromotionTestSupport.load();
        Id userA = c.tree.mgr1User.Id;
        Id root = c.tree.ceo.Id;
        Id middle = c.tree.mgr2.Id;
        Id direct = c.tree.emp1.Id;
        Map<Id, Id> everyone = new Map<Id, Id>{ root => userA, middle => userA, direct => userA };
        System.assertEquals(null, PromotionSharingService.approverUserId(new List<Id>(), everyone));
        System.assertEquals(userA, PromotionSharingService.approverUserId(new List<Id>{ direct }, everyone), 'Sem segundo nivel: o direto');
        System.assertEquals(userA, PromotionSharingService.approverUserId(new List<Id>{ root, middle, direct }, everyone));
        Map<Id, Id> onlyDirect = new Map<Id, Id>{ direct => userA };
        System.assertEquals(
            userA,
            PromotionSharingService.approverUserId(new List<Id>{ root, middle, direct }, onlyDirect),
            'Segundo nivel sem usuario: cai no direto'
        );
        System.assertEquals(null, PromotionSharingService.approverUserId(new List<Id>{ root, middle, direct }, new Map<Id, Id>()));
    }
}
