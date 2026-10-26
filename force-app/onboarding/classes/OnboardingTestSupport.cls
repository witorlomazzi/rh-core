/**
 * Dados e atalhos de teste do modulo de onboarding (prefixo ZZTEST-). Chamado no @TestSetup de cada classe de teste.
 *
 * Usa a arvore de HrTestDataFactory.orgTree(): o RH (HR_Admin) contrata e faz o papel de recrutador; o gestor 1
 * (HR_Manager) e o gestor contratante da vaga; os colaboradores 1 e 2 sao colaboradores sem relacao com o novo
 * contratado. Limite de licencas: so os 4 usuarios da fabrica existem; um teste que precisar de mais um cria no maximo
 * um (HrTestDataFactory.user) dentro do proprio metodo.
 */
@IsTest
public class OnboardingTestSupport {
    public static final String OPENING_NAME = 'ZZTEST-Onboarding';

    public class Ctx {
        public HrTestDataFactory.OrgTree tree;
        public Job_Opening__c opening;
    }

    public static void createAll() {
        HrTestDataFactory.OrgTree t = HrTestDataFactory.orgTree();
        Job_Position__c position = HrTestDataFactory.position();
        Department__c department = HrTestDataFactory.department();
        Job_Opening__c opening = RecruitingTestData.opening('Onboarding', t.mgr1.Id, 'Aberta');
        update new Job_Opening__c(
            Id = opening.Id,
            Position__c = position.Id,
            Department__c = department.Id,
            Employment_Type__c = 'CLT'
        );
    }

    public static Ctx load() {
        Ctx c = new Ctx();
        c.tree = HrTestDataFactory.loadOrgTree();
        c.opening = [
            SELECT Id, Position__c, Department__c, Hiring_Manager__c, Employment_Type__c
            FROM Job_Opening__c
            WHERE Name = :OPENING_NAME
            LIMIT 1
        ];
        return c;
    }

    /** Candidaturas novas (etapa inicial) para a vaga, criadas em lote. Devolve com Id e Name. */
    public static List<Job_Application__c> applications(Id openingId, Integer count) {
        List<Candidate__c> candidates = RecruitingTestData.candidates('onb', count);
        Set<Id> ids = new Map<Id, Job_Application__c>(RecruitingTestData.applications(candidates, openingId)).keySet();
        return [SELECT Id, Name, Candidate__c FROM Job_Application__c WHERE Id IN :ids ORDER BY Name];
    }

    /**
     * Contrata as candidaturas pelo caminho real: o salto direto para Proposta passa por bypass (so o preparo), e a
     * mudanca para Contratado roda o trigger e o OnboardingHiredHandler de verdade, em um unico DML.
     */
    public static void hire(List<Job_Application__c> applications) {
        List<Job_Application__c> toProposal = new List<Job_Application__c>();
        List<Job_Application__c> toHired = new List<Job_Application__c>();
        for (Job_Application__c a : applications) {
            toProposal.add(new Job_Application__c(Id = a.Id, Stage__c = 'Proposta', Score__c = 4));
            toHired.add(new Job_Application__c(Id = a.Id, Stage__c = 'Contratado'));
        }
        TriggerHandler.bypass('JobApplicationTriggerHandler');
        try {
            update toProposal;
        } finally {
            TriggerHandler.clearBypass('JobApplicationTriggerHandler');
        }
        update toHired;
    }

    public static Employee__c employeeOf(Id applicationId) {
        Id employeeId = [SELECT Employee__c FROM Job_Application__c WHERE Id = :applicationId].Employee__c;
        return reloadEmployee(employeeId);
    }

    public static Employee__c reloadEmployee(Id employeeId) {
        return [
            SELECT
                Id,
                Name,
                Email__c,
                Status__c,
                Position__c,
                Department__c,
                Manager__c,
                Hire_Date__c,
                Employee_Number__c,
                Employment_Type__c,
                User__c
            FROM Employee__c
            WHERE Id = :employeeId
        ];
    }

    public static Onboarding_Plan__c planOf(Id employeeId) {
        return [
            SELECT Id, Name, Employee__c, Job_Application__c, Start_Date__c, Status__c, Total_Tasks__c, Completed_Tasks__c
            FROM Onboarding_Plan__c
            WHERE Employee__c = :employeeId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    public static List<Onboarding_Task__c> tasksOf(Id planId) {
        return [
            SELECT
                Id,
                Name,
                Plan__c,
                Status__c,
                Owner_Role__c,
                Due_Date__c,
                Due_Offset_Days__c,
                Order__c,
                Assigned_To__c,
                Completed_Date__c,
                Description__c
            FROM Onboarding_Task__c
            WHERE Plan__c = :planId
            ORDER BY Order__c
        ];
    }

    /** Task de um papel (a primeira, na ordem do plano). */
    public static Onboarding_Task__c taskOfRole(Id planId, String role) {
        for (Onboarding_Task__c t : tasksOf(planId)) {
            if (t.Owner_Role__c == role) {
                return t;
            }
        }
        return null;
    }

    /** Muda a situacao de todas as tarefas indicadas, como o usuario informado. */
    public static void setStatus(List<Onboarding_Task__c> tasks, String status, User actingUser) {
        List<Onboarding_Task__c> patches = new List<Onboarding_Task__c>();
        for (Onboarding_Task__c t : tasks) {
            patches.add(new Onboarding_Task__c(Id = t.Id, Status__c = status));
        }
        System.runAs(actingUser) {
            update patches;
        }
    }

    /** Candidatura contratada de ponta a ponta, como o usuario de RH. Devolve o colaborador criado. */
    public static Employee__c hireOne(Ctx c) {
        List<Job_Application__c> apps = applications(c.opening.Id, 1);
        System.runAs(c.tree.hrUser) {
            hire(apps);
        }
        return employeeOf(apps[0].Id);
    }
}
