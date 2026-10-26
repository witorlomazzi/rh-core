/**
 * Spec 02, item 4: usuario sem permission set do RH recebe excecao ou lista vazia, nunca dado.
 */
@IsTest
private class EmployeeNoAccessTest {
    @IsTest
    static void userWithoutPermissionSetGetsNoData() {
        User outsider = HrTestDataFactory.user('zznops', null);
        Employee__c e = HrTestDataFactory.employee(null, outsider.Id);
        System.runAs(outsider) {
            Boolean blocked = false;
            try {
                blocked = EmployeeSelector.byIds(new Set<Id>{ e.Id }).isEmpty();
            } catch (QueryException ex) {
                blocked = true;
            }
            Assert.isTrue(blocked, 'Sem permission set nao le colaborador, nem o proprio');

            try {
                OrgChartController.getInitial(null);
                Assert.fail('Organograma deveria recusar usuario sem acesso');
            } catch (AuraHandledException ex) {
                Assert.isNotNull(ex.getMessage());
            }

            try {
                ApprovalController.getPending();
                Assert.fail('Caixa de aprovacoes deveria recusar usuario sem acesso');
            } catch (AuraHandledException ex) {
                Assert.isNotNull(ex.getMessage());
            }
            try {
                ApprovalController.getSteps(e.Id);
                Assert.fail('Historico de etapas deveria recusar usuario sem acesso');
            } catch (AuraHandledException ex) {
                Assert.isNotNull(ex.getMessage());
            }
        }
    }
}
