/**
 * Consultas de Leave_Request__c. As consultas de tela e de validacao rodam em USER_MODE: o acesso vem do periodo
 * aquisitivo (pai), isto e, o proprio colaborador, a cadeia de gestores e o RH. teamOverlaps e a unica leitura em
 * contexto de sistema (conflito de equipe, ver o comentario do metodo).
 */
public inherited sharing class LeaveRequestSelector {
    public static final Set<String> CLOSED_STATUSES = new Set<String>{ 'Cancelado', 'Rejeitado' };

    public static List<Leave_Request__c> byId(Id requestId) {
        return [
            SELECT
                Id, Name, Employee__c, Employee__r.Name, Accrual_Period__c, Start_Date__c, End_Date__c, Days__c,
                Sold_Days__c, Status__c, Current_Step__c, Requested_By__c, Notes__c, Rule_Check_Result__c,
                Team_Conflict_Warning__c, CreatedDate, CreatedById
            FROM Leave_Request__c
            WHERE Id = :requestId
            WITH USER_MODE
        ];
    }

    /** Todas as solicitacoes do colaborador, da mais recente para a mais antiga. */
    public static List<Leave_Request__c> byEmployee(Id employeeId) {
        return [
            SELECT
                Id, Name, Employee__c, Accrual_Period__c, Accrual_Period__r.Name, Start_Date__c, End_Date__c, Days__c,
                Sold_Days__c, Status__c, Current_Step__c, Requested_By__c, Notes__c, Team_Conflict_Warning__c,
                CreatedDate
            FROM Leave_Request__c
            WHERE Employee__c = :employeeId
            WITH USER_MODE
            ORDER BY Start_Date__c DESC, CreatedDate DESC
        ];
    }

    /** Solicitacoes do colaborador que ainda ocupam datas (nem canceladas nem rejeitadas), de qualquer periodo. */
    public static List<Leave_Request__c> openByEmployee(Id employeeId) {
        return [
            SELECT Id, Accrual_Period__c, Employee__c, Start_Date__c, End_Date__c, Days__c, Sold_Days__c, Status__c
            FROM Leave_Request__c
            WHERE Employee__c = :employeeId AND Status__c NOT IN :CLOSED_STATUSES
            WITH USER_MODE
        ];
    }

    /** Solicitacoes que se sobrepoem ao intervalo para as pessoas informadas (calendario da equipe). */
    public static List<Leave_Request__c> overlapping(Set<Id> employeeIds, Date rangeStart, Date rangeEnd) {
        Set<String> shown = new Set<String>{ 'Pendente', 'Aprovado', 'Em_Gozo', 'Concluido' };
        return [
            SELECT Id, Name, Employee__c, Start_Date__c, End_Date__c, Days__c, Status__c
            FROM Leave_Request__c
            WHERE
                Employee__c IN :employeeIds
                AND Status__c IN :shown
                AND Start_Date__c <= :rangeEnd
                AND End_Date__c >= :rangeStart
            WITH USER_MODE
            ORDER BY Start_Date__c
        ];
    }

    /**
     * Contexto de sistema (regra V12): o colaborador nao enxerga as ferias dos colegas (OWD privado), mas o aviso de
     * conflito de equipe precisa saber se elas existem. A consulta devolve so datas e o colaborador; o motor de
     * regras reduz isso a uma contagem, sem nomes, antes de qualquer exibicao. A leitura roda na classe interna
     * without sharing porque inherited sharing herdaria o compartilhamento do usuario.
     */
    public static List<Leave_Request__c> teamOverlaps(Id managerId, Id employeeId, Date rangeStart, Date rangeEnd) {
        if (managerId == null) {
            return new List<Leave_Request__c>();
        }
        return new SystemReader().teamOverlaps(managerId, employeeId, rangeStart, rangeEnd);
    }

    // Leitura em contexto de sistema documentada no metodo teamOverlaps (spec 02).
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private without sharing class SystemReader {
        List<Leave_Request__c> teamOverlaps(Id managerId, Id employeeId, Date rangeStart, Date rangeEnd) {
            Set<String> active = new Set<String>{ 'Pendente', 'Aprovado', 'Em_Gozo' };
            return [
                SELECT Id, Employee__c, Start_Date__c, End_Date__c, Days__c, Status__c
                FROM Leave_Request__c
                WHERE
                    Employee__r.Manager__c = :managerId
                    AND Employee__c != :employeeId
                    AND Status__c IN :active
                    AND Start_Date__c <= :rangeEnd
                    AND End_Date__c >= :rangeStart
                LIMIT 200
            ];
        }
    }
}
