/**
 * Apoio compartilhado pelos testes do modulo de desempenho. Dados com prefixo ZZTEST-. Os testes usam a arvore
 * padrao do HrTestDataFactory.orgTree() criada em @TestSetup (gestor 1, colaboradores 1 e 2 e um RH).
 */
@IsTest
public class PerformanceTestSupport {
    public static Review_Cycle__c newCycle() {
        Review_Cycle__c c = new Review_Cycle__c(
            Name = 'ZZTEST-Ciclo ' + HrTestDataFactory.nextSequence(),
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(60),
            Self_Review_Due__c = Date.today().addDays(10),
            Manager_Review_Due__c = Date.today().addDays(20),
            Rating_Scale_Max__c = 5
        );
        insert c;
        return c;
    }

    /** Lanca o ciclo como RH. */
    public static ReviewCycleService.LaunchResult launch(User hr, Id cycleId) {
        ReviewCycleService.LaunchResult result;
        System.runAs(hr) {
            result = ReviewCycleService.launch(cycleId);
        }
        return result;
    }

    public static String advance(User hr, Id cycleId) {
        String status;
        System.runAs(hr) {
            status = ReviewCycleService.advance(cycleId).Status__c;
        }
        return status;
    }

    /** Colaborador registra metas com os pesos informados. */
    public static void goals(User employeeUser, Id cycleId, List<Decimal> weights) {
        System.runAs(employeeUser) {
            Integer i = 1;
            for (Decimal w : weights) {
                GoalController.saveGoal(null, cycleId, 'ZZTEST-Meta ' + i, 'Alvo ' + i, 'Descricao ' + i, w, null);
                i++;
            }
        }
    }

    public static Self_Assessment__c selfOf(Id employeeId, Id cycleId) {
        return [
            SELECT Id, Employee__c, Review_Cycle__c, Self_Rating__c, Submitted__c, Submitted_Date__c, Unique_Key__c
            FROM Self_Assessment__c
            WHERE Employee__c = :employeeId AND Review_Cycle__c = :cycleId
        ];
    }

    public static Performance_Review__c reviewOf(Id employeeId, Id cycleId) {
        return [
            SELECT
                Id, OwnerId, Employee__c, Review_Cycle__c, Reviewer__c, Status__c, Manager_Rating__c, Manager_Comments__c,
                Calibrated_Rating__c, Final_Rating__c, Released_Date__c, Unique_Key__c
            FROM Performance_Review__c
            WHERE Employee__c = :employeeId AND Review_Cycle__c = :cycleId
        ];
    }

    /** Colaborador envia a autoavaliacao (metas ja registradas). */
    public static void submitSelf(User employeeUser, Employee__c employee, Id cycleId, Decimal rating) {
        Id saId = selfOf(employee.Id, cycleId).Id;
        System.runAs(employeeUser) {
            SelfAssessmentController.submitAssessment(saId, rating, 'Pontos fortes', 'Pontos a melhorar');
        }
    }

    public static Integer shareCount(Id reviewId, Id userId, String reason) {
        return [
            SELECT COUNT()
            FROM Performance_Review__Share
            WHERE ParentId = :reviewId AND UserOrGroupId = :userId AND RowCause = :reason
        ];
    }

    /** Concede o grupo de gestor a um usuario de teste (acrescenta ao grupo que ele ja tem). */
    public static void grantManager(User u) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id psgId = [SELECT Id FROM PermissionSetGroup WHERE DeveloperName = 'HR_Manager' LIMIT 1].Id;
            Test.calculatePermissionSetGroup(psgId);
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetGroupId = psgId);
        }
    }

    /** Confere que a mensagem da excecao contem o trecho, mostrando a mensagem real quando falha. */
    public static void assertMessage(Exception e, String part) {
        String actual = messageOf(e);
        Assert.isTrue(actual.contains(part), 'Mensagem inesperada: ' + actual);
    }

    /** Mensagem de uma excecao de DML (primeira linha) ou a mensagem comum. */
    public static String messageOf(Exception e) {
        if (e instanceof DmlException && ((DmlException) e).getNumDml() > 0) {
            return ((DmlException) e).getDmlMessage(0);
        }
        return e.getMessage();
    }
}
