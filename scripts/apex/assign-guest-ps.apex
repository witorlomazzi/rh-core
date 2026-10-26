// Atribui o permission set HR_Portal_Guest ao usuario convidado do site "Vagas Vetra" (spec 14).
// O permission set so da acesso a classe JobPortalController: o convidado nunca recebe acesso a objeto.
// Execucao (idempotente): sf apex run --file scripts/apex/assign-guest-ps.apex --target-org <org>
String siteName = 'Vagas_Vetra';
List<Site> sites = [SELECT GuestUserId FROM Site WHERE Name = :siteName LIMIT 1];
List<PermissionSet> sets = [SELECT Id FROM PermissionSet WHERE Name = 'HR_Portal_Guest' LIMIT 1];
if (sites.isEmpty() || sets.isEmpty()) {
    System.debug(LoggingLevel.ERROR, 'Site ' + siteName + ' ou permission set HR_Portal_Guest nao encontrado.');
} else {
    Id guestId = sites[0].GuestUserId;
    Integer existing = [
        SELECT COUNT()
        FROM PermissionSetAssignment
        WHERE AssigneeId = :guestId AND PermissionSetId = :sets[0].Id
    ];
    if (existing == 0) {
        insert new PermissionSetAssignment(AssigneeId = guestId, PermissionSetId = sets[0].Id);
        System.debug('HR_Portal_Guest atribuido ao usuario convidado.');
    } else {
        System.debug('HR_Portal_Guest ja estava atribuido ao usuario convidado.');
    }
}
