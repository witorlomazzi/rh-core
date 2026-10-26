/**
 * Utilitarios de data do RH: descanso semanal (HR_Setting__mdt), feriados (HR_Holiday__c) e aritmetica de datas.
 * Feriados sao carregados por ano e mantidos em cache na transacao.
 */
public with sharing class HrDateUtils {
    // 07/01/1900 foi domingo: referencia para calcular o dia da semana sem depender de locale.
    private static final Date SUNDAY_REFERENCE = Date.newInstance(1900, 1, 7);
    private static Map<Integer, List<HR_Holiday__c>> holidaysByYear = new Map<Integer, List<HR_Holiday__c>>();

    /** 0 = domingo ... 6 = sabado. */
    public static Integer dayOfWeek(Date d) {
        Integer m = Math.mod(SUNDAY_REFERENCE.daysBetween(d), 7);
        return m < 0 ? m + 7 : m;
    }

    public static Boolean isRestDay(Date d) {
        return HrSettings.restDaysOfWeek().contains(dayOfWeek(d));
    }

    public static Boolean isHoliday(Date d, String location) {
        for (HR_Holiday__c h : holidaysOfYear(d.year())) {
            if (h.Date__c == d && appliesTo(h, location)) {
                return true;
            }
        }
        return false;
    }

    public static Boolean isWorkingDay(Date d, String location) {
        return !isRestDay(d) && !isHoliday(d, location);
    }

    /** Feriados que valem para a localidade (ou para todas) no intervalo, inclusive. */
    public static Set<Date> holidaysBetween(Date startDate, Date endDate, String location) {
        Set<Date> result = new Set<Date>();
        for (Integer y = startDate.year(); y <= endDate.year(); y++) {
            for (HR_Holiday__c h : holidaysOfYear(y)) {
                if (h.Date__c >= startDate && h.Date__c <= endDate && appliesTo(h, location)) {
                    result.add(h.Date__c);
                }
            }
        }
        return result;
    }

    public static Date addMonths(Date d, Integer months) {
        return d == null ? null : d.addMonths(months);
    }

    public static Integer daysBetween(Date startDate, Date endDate) {
        return (startDate == null || endDate == null) ? null : startDate.daysBetween(endDate);
    }

    private static Boolean appliesTo(HR_Holiday__c h, String location) {
        return String.isBlank(h.Location__c) || (location != null && h.Location__c.equalsIgnoreCase(location));
    }

    private static List<HR_Holiday__c> holidaysOfYear(Integer year) {
        if (!holidaysByYear.containsKey(year)) {
            holidaysByYear.put(
                year,
                HolidaySelector.byDateRange(Date.newInstance(year, 1, 1), Date.newInstance(year, 12, 31))
            );
        }
        return holidaysByYear.get(year);
    }

    @TestVisible
    private static void clearCache() {
        holidaysByYear.clear();
    }
}
