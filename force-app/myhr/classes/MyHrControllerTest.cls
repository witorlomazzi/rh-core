/**
 * Testes do controller do Meu RH: contexto (colaborador, gestor, RH, sem vinculo, sem permission set), visao da
 * equipe (saldo, proximas ferias, alerta de prazo, isolamento entre equipes) e avaliacoes visiveis. Dados ZZTEST-.
 */
@IsTest
private class MyHrControllerTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.orgTree();
    }

    // ------------------------------------------------------------------------------------------------ contexto

    @IsTest
    static void employeeGetsOwnContext() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Department__c dept = HrTestDataFactory.department();
        Job_Position__c pos = HrTestDataFactory.position();
        update new Employee__c(Id = t.emp2.Id, Department__c = dept.Id, Position__c = pos.Id);

        MyHrService.Context ctx;
        System.runAs(t.emp2User) {
            ctx = MyHrController.getContext();
        }
        Assert.isTrue(ctx.linked);
        Assert.areEqual(t.emp2.Id, ctx.employeeId);
        Assert.areEqual('ZZTEST-EMP2', ctx.employeeName);
        Assert.areEqual('Z', ctx.initials, 'Nome de uma palavra so tem uma inicial');
        Assert.areEqual(t.mgr1.Id, ctx.managerId);
        Assert.areEqual('ZZTEST-MGR1', ctx.managerName);
        Assert.areEqual(pos.Name, ctx.positionName);
        Assert.areEqual(dept.Name, ctx.departmentName);
        Assert.areEqual('Ativo', ctx.statusLabel);
        Assert.isFalse(ctx.isManager, 'Colaborador sem equipe nao e gestor');
        Assert.isFalse(ctx.isHr, 'Colaborador nao e RH');
        Assert.isFalse(ctx.hasOnboardingPlan);
        Assert.isNull(ctx.nextLeave);
        Assert.areEqual(12, ctx.tenureMonths, 'Admitido ha um ano');
        Assert.isNull(ctx.emptyMessage);
    }

    @IsTest
    static void managerContextFlagsTeam() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        MyHrService.Context ctx;
        System.runAs(t.mgr1User) {
            ctx = MyHrController.getContext();
        }
        Assert.isTrue(ctx.linked);
        Assert.isTrue(ctx.isManager);
        Assert.areEqual(2, ctx.directReports);
        Assert.isFalse(ctx.isHr);
    }

    @IsTest
    static void hrUserWithoutEmployeeGetsHrFlagAndFriendlyMessage() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        MyHrService.Context ctx;
        System.runAs(t.hrUser) {
            ctx = MyHrController.getContext();
        }
        Assert.isFalse(ctx.linked);
        Assert.isTrue(ctx.isHr, 'Custom Permission HR_Admin_Access vem do grupo HR_Admin');
        Assert.areEqual(MyHrService.NOT_LINKED, ctx.emptyMessage);
        Assert.isNull(ctx.employeeId);
    }

    @IsTest
    static void hrUserLinkedToEmployeeGetsBoth() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Employee__c hrEmployee = HrTestDataFactory.employee(t.ceo.Id, t.hrUser.Id);
        MyHrService.Context ctx;
        System.runAs(t.hrUser) {
            ctx = MyHrController.getContext();
        }
        Assert.isTrue(ctx.linked);
        Assert.isTrue(ctx.isHr);
        Assert.areEqual(hrEmployee.Id, ctx.employeeId);
    }

    @IsTest
    static void userWithoutEmployeeLinkGetsEmptyState() {
        User unlinked = HrTestDataFactory.user('zzunlnk', 'HR_Employee');
        MyHrService.Context ctx;
        System.runAs(unlinked) {
            ctx = MyHrController.getContext();
        }
        Assert.isFalse(ctx.linked);
        Assert.isFalse(ctx.isManager);
        Assert.isFalse(ctx.isHr);
        Assert.areEqual('Seu usuário ainda não está vinculado a um colaborador. Fale com o RH.', ctx.emptyMessage);
        Assert.isNull(ctx.nextLeave);
    }

    @IsTest
    static void userWithoutPermissionSetGetsNoData() {
        User outsider = HrTestDataFactory.user('zznoctx', null);
        HrTestDataFactory.employee(null, outsider.Id);
        System.runAs(outsider) {
            try {
                MyHrController.getContext();
                Assert.fail('Sem permission set nao deve devolver contexto');
            } catch (AuraHandledException ex) {
                Assert.isNotNull(ex.getMessage());
            }
            try {
                MyHrController.getTeamOverview();
                Assert.fail('Sem permission set nao deve devolver equipe');
            } catch (AuraHandledException ex) {
                Assert.isNotNull(ex.getMessage());
            }
            try {
                MyHrController.getEmployeeReviews(UserInfo.getUserId());
                Assert.fail('Sem permission set nao deve devolver avaliacoes');
            } catch (AuraHandledException ex) {
                Assert.isNotNull(ex.getMessage());
            }
        }
    }

    @IsTest
    static void contextShowsOnboardingPlanAndNextLeave() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Onboarding_Plan__c plan = new Onboarding_Plan__c(Employee__c = t.emp2.Id, Start_Date__c = Date.today());
        insert plan;
        Leave_Request__c request = scheduleLeave(t.emp2.Id, 20, 10, 'Aprovado');

        MyHrService.Context ctx;
        System.runAs(t.emp2User) {
            ctx = MyHrController.getContext();
        }
        Assert.isTrue(ctx.hasOnboardingPlan);
        Assert.areEqual(plan.Id, ctx.onboardingPlanId);
        Assert.isNotNull(ctx.nextLeave);
        Assert.areEqual('Aprovado', ctx.nextLeave.status);
        Assert.areEqual(10, ctx.nextLeave.days);
        Assert.areEqual(Date.today().addDays(20), ctx.nextLeave.startDate);
        Assert.areEqual(Date.today().addDays(29), ctx.nextLeave.endDate);
        Assert.isNotNull(request.Id);
    }

    @IsTest
    static void contextIgnoresCancelledAndPastLeave() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        scheduleLeave(t.emp2.Id, 20, 5, 'Cancelado');
        MyHrService.Context ctx;
        System.runAs(t.emp2User) {
            ctx = MyHrController.getContext();
        }
        Assert.isNull(ctx.nextLeave, 'Cancelada nao e proxima ferias');
    }

    // ------------------------------------------------------------------------------------------------ equipe

    @IsTest
    static void managerSeesDirectTeamWithBalanceNextLeaveAndAlert() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        LeaveTestData.generatePeriods(new Set<Id>{ t.emp1.Id, t.emp2.Id, t.emp3.Id });
        Leave_Accrual_Period__c p1 = LeaveTestData.firstPeriod(t.emp1.Id);
        // emp1: prazo concessivo em 30 dias (dentro da janela de 60); emp2: prazo distante
        TriggerHandler.bypass('LeaveAccrualPeriodTriggerHandler');
        update new Leave_Accrual_Period__c(Id = p1.Id, Concession_Deadline__c = Date.today().addDays(30));
        TriggerHandler.clearBypass('LeaveAccrualPeriodTriggerHandler');
        scheduleLeave(t.emp2.Id, 45, 14, 'Pendente');

        MyHrService.TeamOverview view;
        System.runAs(t.mgr1User) {
            view = MyHrController.getTeamOverview();
        }
        Assert.isTrue(view.isManager);
        Assert.areEqual(2, view.members.size(), 'Somente a equipe direta, nao o indireto nem outra equipe');
        Map<Id, MyHrService.TeamMember> byId = new Map<Id, MyHrService.TeamMember>();
        for (MyHrService.TeamMember m : view.members) {
            byId.put(m.employeeId, m);
        }
        Assert.isFalse(byId.containsKey(t.emp3.Id), 'Colaborador de outra equipe nao aparece');
        Assert.isFalse(byId.containsKey(t.emp4.Id), 'Indireto nao aparece na equipe direta');

        MyHrService.TeamMember m1 = byId.get(t.emp1.Id);
        Assert.isTrue(m1.deadlineAlert);
        Assert.isFalse(m1.deadlineOverdue);
        Assert.areEqual(30, m1.daysToDeadline);
        Assert.areEqual(Date.today().addDays(30), m1.concessionDeadline);
        Assert.isTrue(m1.hasOpenPeriod);
        Assert.areEqual(p1.Balance_Days__c.intValue(), m1.balanceDays);
        Assert.isNull(m1.nextLeave);
        Assert.areEqual('Ativo', m1.statusLabel);

        MyHrService.TeamMember m2 = byId.get(t.emp2.Id);
        Assert.isFalse(m2.deadlineAlert);
        Assert.isNotNull(m2.nextLeave);
        Assert.areEqual('Pendente', m2.nextLeave.statusLabel);
        Assert.areEqual(14, m2.nextLeave.days);
        Assert.areEqual(1, view.alertCount);
    }

    @IsTest
    static void overduePeriodWithBalanceIsFlaggedOverdue() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        LeaveTestData.generatePeriods(new Set<Id>{ t.emp1.Id });
        Leave_Accrual_Period__c p1 = LeaveTestData.firstPeriod(t.emp1.Id);
        TriggerHandler.bypass('LeaveAccrualPeriodTriggerHandler');
        update new Leave_Accrual_Period__c(Id = p1.Id, Concession_Deadline__c = Date.today().addDays(-5));
        TriggerHandler.clearBypass('LeaveAccrualPeriodTriggerHandler');
        MyHrService.TeamOverview view;
        System.runAs(t.mgr1User) {
            view = MyHrController.getTeamOverview();
        }
        for (MyHrService.TeamMember m : view.members) {
            if (m.employeeId == t.emp1.Id) {
                Assert.isTrue(m.deadlineOverdue);
                Assert.isTrue(m.deadlineAlert);
                Assert.areEqual(-5, m.daysToDeadline);
            }
        }
    }

    @IsTest
    static void employeeWithoutReportsGetsEmptyTeamMessage() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        MyHrService.TeamOverview view;
        System.runAs(t.emp2User) {
            view = MyHrController.getTeamOverview();
        }
        Assert.isFalse(view.isManager);
        Assert.isTrue(view.members.isEmpty());
        Assert.areEqual('Você não tem pessoas na sua equipe direta.', view.emptyMessage);
    }

    @IsTest
    static void unlinkedUserGetsEmptyTeamState() {
        User unlinked = HrTestDataFactory.user('zzunlt', 'HR_Employee');
        MyHrService.TeamOverview view;
        System.runAs(unlinked) {
            view = MyHrController.getTeamOverview();
        }
        Assert.isFalse(view.isManager);
        Assert.areEqual(MyHrService.NOT_LINKED, view.emptyMessage);
    }

    @IsTest
    static void teamOverviewDoesNotMultiplyQueriesWithTeamSize() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        List<Employee__c> extra = new List<Employee__c>();
        for (Integer i = 0; i < 40; i++) {
            extra.add(HrTestDataFactory.buildEmployee(t.mgr1.Id, null));
        }
        insert extra;
        Integer before;
        Integer after;
        MyHrService.TeamOverview view;
        System.runAs(t.mgr1User) {
            before = Limits.getQueries();
            view = MyHrController.getTeamOverview();
            after = Limits.getQueries();
        }
        Assert.areEqual(42, view.members.size());
        Assert.isTrue(after - before <= 6, 'Consultas constantes: ' + (after - before));
    }

    // ------------------------------------------------------------------------------------------------ avaliacoes

    @IsTest
    static void reviewsAreVisibleOnlyToThoseWithAccess() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        // avaliacoes nascem so pelo lancamento do ciclo (regra do modulo de desempenho)
        PerformanceTestSupport.launch(t.hrUser, cycle.Id);

        List<MyHrService.ReviewRow> asManager;
        List<MyHrService.ReviewRow> asHr;
        List<MyHrService.ReviewRow> asEmployee;
        List<MyHrService.ReviewRow> asPeer;
        System.runAs(t.mgr1User) {
            asManager = MyHrController.getEmployeeReviews(t.emp2.Id);
        }
        System.runAs(t.hrUser) {
            asHr = MyHrController.getEmployeeReviews(t.emp2.Id);
        }
        System.runAs(t.emp2User) {
            asEmployee = MyHrController.getEmployeeReviews(t.emp2.Id);
        }
        System.runAs(t.emp1User) {
            asPeer = MyHrController.getEmployeeReviews(t.emp2.Id);
        }
        Assert.areEqual(1, asManager.size());
        Assert.areEqual(cycle.Name, asManager[0].cycleName);
        Assert.areEqual(1, asHr.size());
        Assert.isTrue(asEmployee.isEmpty(), 'Colaborador so le a avaliacao depois da liberacao');
        Assert.isTrue(asPeer.isEmpty(), 'Colega nunca le');
    }

    @IsTest
    static void reviewsWithoutEmployeeIdAreEmpty() {
        Assert.isTrue(MyHrController.getEmployeeReviews(null).isEmpty());
    }

    // ------------------------------------------------------------------------------------------------ apoio

    /** Cria o periodo do colaborador (se faltar) e uma solicitacao que comeca daqui a startInDays dias. */
    private static Leave_Request__c scheduleLeave(Id employeeId, Integer startInDays, Integer days, String status) {
        LeaveTestData.generatePeriods(new Set<Id>{ employeeId });
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(employeeId);
        return LeaveTestData.insertRequest(period.Id, Date.today().addDays(startInDays), days, 0, status);
    }
}
