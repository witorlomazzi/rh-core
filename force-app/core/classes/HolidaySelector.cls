/**
 * Consultas de HR_Holiday__c. Feriados sao dado publico da empresa (OWD Public Read Only).
 */
public inherited sharing class HolidaySelector {
    public static List<HR_Holiday__c> byDateRange(Date startDate, Date endDate) {
        return [
            SELECT Id, Name, Date__c, Location__c, Type__c, Unique_Key__c
            FROM HR_Holiday__c
            WHERE Date__c >= :startDate AND Date__c <= :endDate
            WITH USER_MODE
            ORDER BY Date__c
        ];
    }
}
