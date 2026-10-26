/**
 * Spec 02, item 4: usuario sem permission set recebe excecao ou lista vazia, nunca dado de desempenho.
 */
@IsTest
private class PerformanceNoAccessTest {
    @IsTest
    static void userWithoutPermissionSetGetsNoPerformanceData() {
        User outsider = HrTestDataFactory.user('zznoper', null);
        Employee__c employee = HrTestDataFactory.employee(null, outsider.Id);
        Review_Cycle__c cycle = PerformanceTestSupport.newCycle();
        ReviewCycleService.LaunchResult result = new ReviewCycleService.LaunchResult();
        ReviewCycleService.createRecords(cycle, new List<Employee__c>{ employee }, result);
        Assert.areEqual(1, result.reviewsCreated);
        Id reviewId = PerformanceTestSupport.reviewOf(employee.Id, cycle.Id).Id;

        System.runAs(outsider) {
            try {
                PerformanceReviewController.getMyCycle(cycle.Id);
                Assert.fail('Sem permission set nao le o proprio cadastro');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
            try {
                PerformanceReviewController.getTeam(cycle.Id);
                Assert.fail('Sem permission set nao le o ciclo');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
            try {
                PerformanceReviewController.getReviewForm(reviewId);
                Assert.fail('Sem permission set nao le a avaliacao');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
            try {
                ReviewCycleController.getOverview(cycle.Id);
                Assert.fail('Sem permission set nao e RH');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
            Boolean blocked = false;
            try {
                blocked = PerformanceReviewSelector.byCycle(cycle.Id).isEmpty();
            } catch (QueryException e) {
                blocked = true;
            }
            Assert.isTrue(blocked, 'Selector nunca devolve avaliacao a quem nao tem permission set');
        }
    }
}
