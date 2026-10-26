/**
 * Fila dona de candidatos e candidaturas (spec 02). O nome da fila vem de HR_Setting__mdt, sem Id fixo.
 */
// Group e configuracao do proprio produto, nao dado de pessoa: leitura em modo sistema.
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class RecruitingQueue {
    private static Id cachedId;
    private static Boolean loaded = false;

    /** Id da fila de recrutamento, ou null se ela nao existir. */
    public static Id id() {
        if (!loaded) {
            String developerName = HrSettings.get().Recruiting_Queue_Developer_Name__c;
            if (String.isBlank(developerName)) {
                developerName = 'HR_Recruiting_Queue';
            }
            List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :developerName LIMIT 1];
            cachedId = queues.isEmpty() ? null : queues[0].Id;
            loaded = true;
            if (cachedId == null) {
                System.debug(LoggingLevel.WARN, 'Fila de recrutamento nao encontrada: ' + developerName);
            }
        }
        return cachedId;
    }
}
