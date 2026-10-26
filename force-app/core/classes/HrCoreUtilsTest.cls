@IsTest
private class HrCoreUtilsTest {
    @IsTest
    static void settingsDefaultAndOverride() {
        Assert.areEqual(30, HrSettings.get().Leave_Min_Notice_Days__c, 'Registro Default implantado');
        Assert.areEqual(new Set<Integer>{ 0 }, HrSettings.restDaysOfWeek());
        HrSettings.testOverride = new HR_Setting__mdt(Weekly_Rest_Days__c = 'SUN; sat ;XYZ');
        Assert.areEqual(new Set<Integer>{ 0, 6 }, HrSettings.restDaysOfWeek());
        HrSettings.testOverride = new HR_Setting__mdt(Weekly_Rest_Days__c = null);
        Assert.isTrue(HrSettings.restDaysOfWeek().isEmpty());
    }

    @IsTest
    static void dateUtilsRestDaysAndHolidays() {
        Date sunday = Date.newInstance(2026, 10, 25);
        Assert.areEqual(0, HrDateUtils.dayOfWeek(sunday));
        Assert.areEqual(6, HrDateUtils.dayOfWeek(Date.newInstance(1900, 1, 6)), 'Antes da referencia');
        Assert.isTrue(HrDateUtils.isRestDay(sunday));
        Assert.isFalse(HrDateUtils.isRestDay(sunday.addDays(1)));

        HrTestDataFactory.holiday(Date.newInstance(2026, 11, 2), null);
        HrTestDataFactory.holiday(Date.newInstance(2026, 11, 20), 'SP-SAO_PAULO');
        HrTestDataFactory.holiday(Date.newInstance(2027, 1, 1), null);
        HrDateUtils.clearCache();
        Assert.isTrue(HrDateUtils.isHoliday(Date.newInstance(2026, 11, 2), 'RJ-RIO'), 'Nacional vale para todos');
        Assert.isTrue(HrDateUtils.isHoliday(Date.newInstance(2026, 11, 20), 'sp-sao_paulo'));
        Assert.isFalse(HrDateUtils.isHoliday(Date.newInstance(2026, 11, 20), 'RJ-RIO'), 'Municipal de outra cidade');
        Assert.isFalse(HrDateUtils.isHoliday(Date.newInstance(2026, 11, 20), null));
        Assert.isFalse(HrDateUtils.isWorkingDay(Date.newInstance(2026, 11, 2), 'SP-SAO_PAULO'));
        Assert.isTrue(HrDateUtils.isWorkingDay(Date.newInstance(2026, 11, 3), 'SP-SAO_PAULO'));
        Set<Date> range = HrDateUtils.holidaysBetween(Date.newInstance(2026, 11, 1), Date.newInstance(2027, 1, 31), 'SP-SAO_PAULO');
        Assert.areEqual(3, range.size(), 'Atravessa a virada do ano');

        Assert.areEqual(Date.newInstance(2027, 1, 25), HrDateUtils.addMonths(Date.newInstance(2026, 10, 25), 3));
        Assert.isNull(HrDateUtils.addMonths(null, 1));
        Assert.areEqual(7, HrDateUtils.daysBetween(sunday, sunday.addDays(7)));
        Assert.isNull(HrDateUtils.daysBetween(null, sunday));
    }

    @IsTest
    static void selectorsReturnRecords() {
        Department__c d = HrTestDataFactory.department();
        Job_Position__c next = HrTestDataFactory.position();
        Job_Position__c p = HrTestDataFactory.position(HrTestDataFactory.salaryBand(3000, 5000).Id, next.Id);
        Assert.areEqual(1, DepartmentSelector.byIds(new Set<Id>{ d.Id }).size());
        Assert.isFalse(DepartmentSelector.active().isEmpty());
        Assert.areEqual(next.Id, JobPositionSelector.byIds(new Set<Id>{ p.Id })[0].Next_Position__c);
        Assert.areEqual(2, JobPositionSelector.active().size());
        HrTestDataFactory.holiday(Date.newInstance(2026, 12, 25), null);
        Assert.areEqual(1, HolidaySelector.byDateRange(Date.newInstance(2026, 12, 1), Date.newInstance(2026, 12, 31)).size());
    }

    @IsTest
    static void salaryBandValidation() {
        try {
            HrTestDataFactory.salaryBand(5000, 3000);
            Assert.fail('Maximo menor que minimo');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('salário máximo'));
        }
    }

    @IsTest
    static void notificationsNeverThrow() {
        Employee__c e = HrTestDataFactory.employee(null, null);
        HrNotificationService.notify(new Set<String>{ UserInfo.getUserId() }, e.Id, 'Teste', 'Corpo', 'HR_Request_Decided');
        Assert.areEqual(1, HrNotificationService.sentCount);
        HrNotificationService.notify(new Set<String>{ UserInfo.getUserId() }, e.Id, null, null, 'Tipo_Inexistente');
        HrNotificationService.notify(new Set<String>(), e.Id, 'x', 'y', 'HR_Request_Decided');
        HrNotificationService.notify(null, e.Id, 'x', 'y', 'HR_Request_Decided');
        Assert.areEqual(1, HrNotificationService.sentCount, 'Chamadas invalidas nao enviam');
    }

    @IsTest
    static void triggerHandlerDispatchesAndBypasses() {
        TriggerHandler h = new TriggerHandler();
        for (System.TriggerOperation op : System.TriggerOperation.values()) {
            h.operationOverride = op;
            h.run();
        }
        Assert.areEqual('TriggerHandler', h.getHandlerName());
        TriggerHandler.bypass('TriggerHandler');
        Assert.isTrue(TriggerHandler.isBypassed('TriggerHandler'));
        h.run();
        TriggerHandler.clearBypass('TriggerHandler');
        Assert.isFalse(TriggerHandler.isBypassed('TriggerHandler'));
    }

    @IsTest
    static void hierarchyServiceResolvesChain() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.orgTree();
        Assert.areEqual(new List<Id>{ t.emp1User.Id, t.mgr1User.Id }, EmployeeHierarchyService.managerChainUserIds(t.emp4));
        Assert.areEqual(new List<Id>{ t.emp1.Id, t.mgr1.Id, t.ceo.Id }, EmployeeHierarchyService.managerChainEmployeeIds(t.emp4.Id));
        Assert.areEqual(t.emp1User.Id, EmployeeHierarchyService.directManagerUserId(t.emp4));
        Assert.areEqual(t.mgr1User.Id, EmployeeHierarchyService.secondLevelManagerUserId(t.emp4));
        Assert.areEqual(t.mgr1User.Id, EmployeeHierarchyService.secondLevelManagerUserId(t.emp1), 'Sem usuario no 2o nivel: gestor direto');
        Assert.isNull(EmployeeHierarchyService.secondLevelManagerUserId(t.ceo));
        Assert.isNull(EmployeeHierarchyService.directManagerUserId(t.ceo));
        Assert.isTrue(EmployeeHierarchyService.isInChainOf(t.mgr1.Id, t.emp4.Id));
        Assert.isTrue(EmployeeHierarchyService.isInChainOf(t.ceo.Id, t.emp4.Id));
        Assert.isFalse(EmployeeHierarchyService.isInChainOf(t.mgr2.Id, t.emp4.Id));
        Assert.isFalse(EmployeeHierarchyService.isInChainOf(t.emp4.Id, t.emp4.Id));
        Assert.isFalse(EmployeeHierarchyService.isInChainOf(null, t.emp4.Id));
        Assert.isTrue(EmployeeHierarchyService.managerChainEmployeeIds(null).isEmpty());
    }

    @IsTest
    static void noopHandlerRecordsCalls() {
        NoopApprovalHandler h = new NoopApprovalHandler();
        Id fakeId = HrTestDataFactory.department().Id;
        h.onApproved(fakeId);
        h.onRejected(fakeId);
        h.onStepAdvanced(fakeId, 2);
        Assert.areEqual(3, NoopApprovalHandler.calls.size());
    }
}
