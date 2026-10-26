/**
 * Envio de notificacoes personalizadas (sino do Lightning e app movel). Falha de notificacao nunca derruba a
 * transacao de negocio: o erro fica registrado em debug.
 */
public with sharing class HrNotificationService {
    private static Map<String, Id> typeIds = new Map<String, Id>();
    @TestVisible
    private static Integer sentCount = 0;

    public static void notify(Set<String> recipientIds, Id targetId, String title, String body, String typeDeveloperName) {
        try {
            if (recipientIds == null || recipientIds.isEmpty() || targetId == null) {
                return;
            }
            Id typeId = typeId(typeDeveloperName);
            if (typeId == null) {
                System.debug(LoggingLevel.WARN, 'Tipo de notificacao nao encontrado: ' + typeDeveloperName);
                return;
            }
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(typeId);
            notification.setTitle(String.isBlank(title) ? 'RH Core' : title.left(250));
            notification.setBody(String.isBlank(body) ? ' ' : body.left(750));
            notification.setTargetId(targetId);
            notification.send(recipientIds);
            sentCount++;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Falha ao enviar notificacao: ' + e.getMessage());
        }
    }

    private static Id typeId(String developerName) {
        if (!typeIds.containsKey(developerName)) {
            List<CustomNotificationType> rows = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = :developerName
                LIMIT 1
            ];
            typeIds.put(developerName, rows.isEmpty() ? null : rows[0].Id);
        }
        return typeIds.get(developerName);
    }
}
