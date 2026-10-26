/**
 * Testes dos controllers dos componentes de ferias (saldo, formulario, lista e calendario da equipe).
 * Arvore: gestor 1 (usuario) > colaboradores 1 e 2 (usuarios); colaborador 1 > colaborador 4.
 */
@IsTest
private class LeaveControllerTest {
    @TestSetup
    static void setup() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.orgTree();
        LeaveTestData.generatePeriods(new Set<Id>{ t.mgr1.Id, t.emp1.Id, t.emp2.Id, t.emp3.Id, t.emp4.Id });
    }

    private static LeaveRequestController.RuleView ruleOf(LeaveRequestController.CheckView view, String code) {
        for (LeaveRequestController.RuleView r : view.rules) {
            if (r.code == code) {
                return r;
            }
        }
        return null;
    }

    // ------------------------------------------------------------------------------------------ saldo

    @IsTest
    static void balanceShowsThePeriodsOfTheCurrentUser() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.emp1User) {
            LeaveRequestController.BalanceView view = LeaveRequestController.getBalance(null);
            Assert.areEqual(t.emp1.Id, view.employeeId);
            Assert.areEqual(2, view.periods.size());
            Assert.isNull(view.emptyMessage);
            // mais recente primeiro: o periodo em aquisicao e depois o adquirido
            Assert.areEqual('Em_Aquisicao', view.periods[0].status);
            Assert.areEqual('Em aquisição', view.periods[0].statusLabel);
            Assert.isFalse(view.periods[0].canRequest);
            LeaveRequestController.PeriodView acquired = view.periods[1];
            Assert.areEqual('Disponivel', acquired.status);
            Assert.areEqual(30, acquired.entitledDays);
            Assert.areEqual(30, acquired.balanceDays);
            Assert.areEqual(0, acquired.daysTaken);
            Assert.isTrue(acquired.canRequest);
            Assert.isTrue(acquired.daysToDeadline > 300);
        }
    }

    @IsTest
    static void balanceForARecordAndForUsersWithoutEmployee() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        System.runAs(t.mgr1User) {
            LeaveRequestController.BalanceView view = LeaveRequestController.getBalance(t.emp1.Id);
            Assert.areEqual(t.emp1.Name, view.employeeName);
            Assert.areEqual(2, view.periods.size());
        }
        System.runAs(t.hrUser) {
            // O RH de teste nao tem registro de colaborador proprio
            LeaveRequestController.BalanceView none = LeaveRequestController.getBalance(null);
            Assert.isNull(none.employeeId);
            Assert.isTrue(none.emptyMessage.contains('vinculado'));
        }
        System.runAs(t.emp2User) {
            // Registro que o usuario nao enxerga: tela vazia, sem dado
            LeaveRequestController.BalanceView hidden = LeaveRequestController.getBalance(t.emp1.Id);
            Assert.isNull(hidden.employeeId);
            Assert.isTrue(hidden.periods.isEmpty());
        }
    }

    // ------------------------------------------------------------------------------------------ formulario

    @IsTest
    static void checkRulesListsEveryRuleAsOk() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp1User) {
            LeaveRequestController.CheckView view = LeaveRequestController.checkRules(period.Id, LeaveTestData.validMonday(), 30, 0, false);
            Assert.areEqual(12, view.rules.size());
            Assert.isTrue(view.canSubmit);
            Assert.isFalse(view.hasBlocking);
            Assert.isFalse(view.hasWarning);
            Assert.isFalse(view.isHr);
            for (LeaveRequestController.RuleView r : view.rules) {
                Assert.areEqual('ok', r.level, r.code);
                Assert.isNotNull(r.title);
            }
        }
    }

    @IsTest
    static void checkRulesShowsBlockingAndWarning() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp1User) {
            Date friday = LeaveTestData.nextWeekday(Date.today().addDays(45), 5);
            LeaveRequestController.CheckView blocked = LeaveRequestController.checkRules(period.Id, friday, 4, 0, false);
            Assert.isTrue(blocked.hasBlocking);
            Assert.isFalse(blocked.canSubmit);
            Assert.areEqual('blocked', ruleOf(blocked, LeaveRuleEngine.R_V4).level);
            Assert.areEqual('blocked', ruleOf(blocked, LeaveRuleEngine.R_V6).level);
            Assert.isNotNull(ruleOf(blocked, LeaveRuleEngine.R_V4).message);

            LeaveRequestController.CheckView warned = LeaveRequestController.checkRules(period.Id, LeaveTestData.validMonday(), 20, 10, false);
            Assert.isTrue(warned.hasWarning);
            Assert.isTrue(warned.canSubmit);
            Assert.areEqual('warning', ruleOf(warned, LeaveRuleEngine.R_V9).level);
        }
    }

    @IsTest
    static void checkRulesWithIncompleteDataExplainsTheProblem() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp1User) {
            LeaveRequestController.CheckView view = LeaveRequestController.checkRules(period.Id, null, 10, 0, false);
            Assert.isTrue(view.hasBlocking);
            Assert.areEqual(1, view.rules.size());
            Assert.areEqual('blocked', view.rules[0].level);
            Assert.areEqual('Dados do pedido', view.rules[0].title);
        }
    }

    @IsTest
    static void checkRulesForAnotherEmployeeFailsWithAMessage() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp2User) {
            try {
                LeaveRequestController.checkRules(period.Id, LeaveTestData.validMonday(), 10, 0, false);
                Assert.fail('Sem acesso ao periodo');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('não encontrado'), e.getMessage());
            }
        }
    }

    @IsTest
    static void submitRequestCreatesAPendingRequest() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp1User) {
            LeaveRequestController.CheckView view = LeaveRequestController.submitRequest(
                period.Id,
                LeaveTestData.validMonday(),
                14,
                0,
                'Viagem em familia',
                false
            );
            Assert.isTrue(view.submitted);
            Assert.isNotNull(view.requestId);
            Leave_Request__c saved = LeaveTestData.reloadRequest(view.requestId);
            Assert.areEqual('Pendente', saved.Status__c);
            Assert.areEqual('Viagem em familia', saved.Notes__c);

            List<LeaveRequestController.RequestView> mine = LeaveRequestController.getRequests(null);
            Assert.areEqual(1, mine.size());
            Assert.areEqual('Pendente', mine[0].status);
            Assert.areEqual('Aguardando o gestor', mine[0].awaitingLabel);
            Assert.isTrue(mine[0].canCancel);
            Assert.areEqual(14, mine[0].days);
            Assert.areEqual(mine[0].startDate.addDays(13), mine[0].endDate);

            LeaveRequestController.cancelRequest(view.requestId);
            Assert.areEqual('Cancelado', LeaveRequestController.getRequests(null)[0].status);
            Assert.isFalse(LeaveRequestController.getRequests(null)[0].canCancel);
        }
    }

    @IsTest
    static void submitRequestBlockedLeavesNothingSaved() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.emp1User) {
            LeaveRequestController.CheckView view = LeaveRequestController.submitRequest(
                period.Id,
                LeaveTestData.nextWeekday(Date.today().addDays(5), 1),
                30,
                0,
                null,
                false
            );
            Assert.isFalse(view.submitted);
            Assert.isTrue(view.hasBlocking);
            Assert.areEqual('blocked', ruleOf(view, LeaveRuleEngine.R_V3).level);
            Assert.isTrue(LeaveRequestController.getRequests(null).isEmpty(), 'Rascunho nao fica gravado');
        }
    }

    @IsTest
    static void submitRequestErrorsBecomeAuraMessages() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.mgr1User) {
            try {
                LeaveRequestController.submitRequest(period.Id, LeaveTestData.validMonday(), 10, 0, null, false);
                Assert.fail('Gestor nao solicita pelo colaborador');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('colaborador ou o RH'), e.getMessage());
            }
        }
        System.runAs(t.emp1User) {
            try {
                LeaveRequestController.cancelRequest(null);
                Assert.fail('Pedido inexistente');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('não encontrada'), e.getMessage());
            }
            try {
                // DmlException do motor de regras vira mensagem de negocio
                LeaveRequestController.submitRequest(period.Id, LeaveTestData.validMonday(), 0, 0, null, false);
                Assert.fail('Zero dias');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
    }

    @IsTest
    static void hrSeesTheExceptionFlag() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Leave_Accrual_Period__c period = LeaveTestData.firstPeriod(t.emp1.Id);
        System.runAs(t.hrUser) {
            LeaveRequestController.CheckView view = LeaveRequestController.checkRules(
                period.Id,
                LeaveTestData.nextWeekday(Date.today().addDays(10), 1),
                14,
                0,
                true
            );
            Assert.isTrue(view.isHr);
            Assert.isTrue(view.canSubmit, 'Excecao de antecedencia do RH vira aviso');
            Assert.areEqual('warning', ruleOf(view, LeaveRuleEngine.R_V3).level);
        }
    }

    // ------------------------------------------------------------------------------------------ calendario

    @IsTest
    static void teamCalendarShowsDirectReportsWithLeaveHolidaysAndRestDays() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        // Segunda-feira entre os dias 8 e 14 do mes que comeca daqui a dois meses: toda a janela fica dentro do mes.
        Date monday = LeaveTestData.nextWeekday(Date.today().addMonths(2).toStartOfMonth().addDays(7), 1);
        Date monthStart = monday.toStartOfMonth();
        Leave_Request__c r = LeaveTestData.insertRequest(LeaveTestData.firstPeriod(t.emp1.Id).Id, monday, 5, 0, 'Aprovado');
        LeaveTestData.insertRequest(LeaveTestData.firstPeriod(t.emp2.Id).Id, monday.addDays(2), 3, 0, 'Pendente');
        // Rascunho e cancelado nao aparecem
        LeaveTestData.insertRequest(LeaveTestData.firstPeriod(t.emp2.Id).Id, monday.addDays(20), 3, 0, 'Rascunho');
        Date holidayDate = monday.addDays(1);
        HrTestDataFactory.holiday(holidayDate, null);
        HrTestDataFactory.holiday(monday.addDays(3), 'RJ-OUTRA');

        System.runAs(t.mgr1User) {
            LeaveTeamCalendarController.MonthView view = LeaveTeamCalendarController.getMonth(monday.year(), monday.month());
            Assert.isNull(view.emptyMessage);
            Assert.areEqual(monthStart.daysBetween(monthStart.addMonths(1)), view.days.size());
            Assert.areEqual(2, view.rows.size(), 'Gestor 1 tem dois diretos');

            LeaveTeamCalendarController.PersonRow row1;
            LeaveTeamCalendarController.PersonRow row2;
            for (LeaveTeamCalendarController.PersonRow row : view.rows) {
                if (row.employeeId == t.emp1.Id) {
                    row1 = row;
                } else {
                    row2 = row;
                }
            }
            Assert.areEqual(view.days.size(), row1.cells.size());
            Assert.areEqual('Aprovado', row1.cells[monday.day() - 1].status);
            Assert.areEqual('Aprovado', row1.cells[monday.day() + 3].status);
            Assert.areEqual('', row1.cells[monday.day() + 4].status);
            Assert.areEqual(r.Id, [SELECT Id FROM Leave_Request__c WHERE Name = :row1.cells[monday.day() - 1].requestName].Id);
            Assert.areEqual('Pendente', row2.cells[monday.day() + 1].status);

            LeaveTeamCalendarController.DayView mondayView = view.days[monday.day() - 1];
            Assert.areEqual(1, mondayView.weekday);
            Assert.isFalse(mondayView.isRestDay);
            Assert.areEqual(1, mondayView.onLeaveCount);
            Assert.areEqual(2, view.days[monday.day() + 1].onLeaveCount, 'Dois colaboradores de ferias no mesmo dia');
            Assert.isTrue(view.days[holidayDate.day() - 1].isHoliday);
            Assert.isNotNull(view.days[holidayDate.day() - 1].holidayName);
            Assert.isFalse(view.days[monday.addDays(3).day() - 1].isHoliday, 'Feriado de outra localidade nao vale');
            Boolean sundayFound = false;
            for (LeaveTeamCalendarController.DayView d : view.days) {
                if (d.weekday == 0) {
                    Assert.isTrue(d.isRestDay);
                    sundayFound = true;
                }
            }
            Assert.isTrue(sundayFound);
        }
    }

    @IsTest
    static void teamCalendarEmptyStates() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.loadOrgTree();
        Date today = Date.today();
        System.runAs(t.emp2User) {
            LeaveTeamCalendarController.MonthView view = LeaveTeamCalendarController.getMonth(today.year(), today.month());
            Assert.isTrue(view.rows.isEmpty());
            Assert.isTrue(view.emptyMessage.contains('equipe direta'), view.emptyMessage);
        }
        System.runAs(t.hrUser) {
            LeaveTeamCalendarController.MonthView view = LeaveTeamCalendarController.getMonth(today.year(), today.month());
            Assert.isTrue(view.emptyMessage.contains('vinculado'), view.emptyMessage);
        }
        System.runAs(t.emp1User) {
            // Colaborador 1 tem o colaborador 4 como direto
            Assert.areEqual(1, LeaveTeamCalendarController.getMonth(today.year(), today.month()).rows.size());
            try {
                LeaveTeamCalendarController.getMonth(today.year(), 13);
                Assert.fail('Mes invalido');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('mês válido'), e.getMessage());
            }
            try {
                LeaveTeamCalendarController.getMonth(null, 1);
                Assert.fail('Ano nulo');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
    }
}
