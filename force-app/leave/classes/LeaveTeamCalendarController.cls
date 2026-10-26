/**
 * Dados do calendario de ferias da equipe (leaveTeamCalendar): uma linha por pessoa da equipe direta do usuario e
 * uma coluna por dia do mes, com feriados e descanso semanal destacados. Leituras em USER_MODE: o gestor ve as
 * solicitacoes da equipe pelo compartilhamento da cadeia de gestores; quem nao tem equipe recebe a tela vazia.
 */
public with sharing class LeaveTeamCalendarController {
    public class DayView {
        @AuraEnabled
        public Integer day;
        @AuraEnabled
        public String isoDate;
        /** 0 = domingo ... 6 = sabado */
        @AuraEnabled
        public Integer weekday;
        @AuraEnabled
        public Boolean isRestDay;
        @AuraEnabled
        public Boolean isHoliday;
        @AuraEnabled
        public String holidayName;
        @AuraEnabled
        public Integer onLeaveCount = 0;
    }

    public class CellView {
        @AuraEnabled
        public Integer day;
        /** Vazio, Pendente, Aprovado, Em_Gozo ou Concluido */
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String requestName;
    }

    public class PersonRow {
        @AuraEnabled
        public Id employeeId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public List<CellView> cells = new List<CellView>();
    }

    public class MonthView {
        @AuraEnabled
        public Integer year;
        @AuraEnabled
        public Integer month;
        @AuraEnabled
        public List<DayView> days = new List<DayView>();
        @AuraEnabled
        public List<PersonRow> rows = new List<PersonRow>();
        @AuraEnabled
        public String emptyMessage;
    }

    @AuraEnabled
    public static MonthView getMonth(Integer year, Integer month) {
        try {
            if (year == null || month == null || month < 1 || month > 12) {
                throw new AuraHandledException('Informe um mês válido.');
            }
            MonthView view = new MonthView();
            view.year = year;
            view.month = month;
            Date firstDay = Date.newInstance(year, month, 1);
            Date lastDay = firstDay.addMonths(1).addDays(-1);

            Employee__c me = EmployeeSelector.currentUserEmployee();
            if (me == null) {
                view.emptyMessage = 'Seu usuário ainda não está vinculado a um colaborador.';
                return view;
            }
            buildDays(view, firstDay, lastDay, me.Work_Location__c);
            List<Employee__c> team = EmployeeSelector.directReports(me.Id);
            if (team.isEmpty()) {
                view.emptyMessage = 'Você não tem equipe direta para exibir no calendário.';
                return view;
            }
            fillRows(view, team, firstDay, lastDay);
            return view;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    private static void buildDays(MonthView view, Date firstDay, Date lastDay, String location) {
        Map<Date, String> holidayNames = new Map<Date, String>();
        for (HR_Holiday__c h : HolidaySelector.byDateRange(firstDay, lastDay)) {
            if (String.isBlank(h.Location__c) || (location != null && h.Location__c.equalsIgnoreCase(location))) {
                holidayNames.put(h.Date__c, h.Name);
            }
        }
        Integer total = firstDay.daysBetween(lastDay) + 1;
        for (Integer i = 0; i < total; i++) {
            Date d = firstDay.addDays(i);
            DayView dv = new DayView();
            dv.day = d.day();
            dv.isoDate = String.valueOf(d);
            dv.weekday = HrDateUtils.dayOfWeek(d);
            dv.isRestDay = HrDateUtils.isRestDay(d);
            dv.isHoliday = holidayNames.containsKey(d);
            dv.holidayName = holidayNames.get(d);
            view.days.add(dv);
        }
    }

    private static void fillRows(MonthView view, List<Employee__c> team, Date firstDay, Date lastDay) {
        Set<Id> ids = new Map<Id, Employee__c>(team).keySet();
        Map<Id, List<Leave_Request__c>> byEmployee = new Map<Id, List<Leave_Request__c>>();
        for (Leave_Request__c r : LeaveRequestSelector.overlapping(ids, firstDay, lastDay)) {
            if (!byEmployee.containsKey(r.Employee__c)) {
                byEmployee.put(r.Employee__c, new List<Leave_Request__c>());
            }
            byEmployee.get(r.Employee__c).add(r);
        }
        for (Employee__c e : team) {
            PersonRow row = new PersonRow();
            row.employeeId = e.Id;
            row.name = e.Name;
            row.positionName = e.Position__r == null ? null : e.Position__r.Name;
            for (DayView dv : view.days) {
                CellView cell = new CellView();
                cell.day = dv.day;
                cell.status = '';
                Date d = Date.valueOf(dv.isoDate);
                for (Leave_Request__c r : byEmployee.containsKey(e.Id) ? byEmployee.get(e.Id) : new List<Leave_Request__c>()) {
                    if (r.Start_Date__c <= d && r.End_Date__c >= d) {
                        cell.status = r.Status__c;
                        cell.requestName = r.Name;
                    }
                }
                if (cell.status != '') {
                    dv.onLeaveCount++;
                }
                row.cells.add(cell);
            }
            view.rows.add(row);
        }
    }
}
