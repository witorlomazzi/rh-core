/**
 * Fabrica de dados de teste do RH Core, compartilhada por todos os modulos. Dados com prefixo ZZTEST-.
 *
 * Licencas: a scratch org Developer tem poucas licencas internas (1 Salesforce e 3 Salesforce Platform livres).
 * user() usa o perfil de plataforma enquanto houver licenca e depois o perfil padrao. Crie no maximo 4 usuarios
 * por transacao de teste.
 */
@IsTest
public class HrTestDataFactory {
    private static Integer sequence = 0;
    private static Integer platformCreated = 0;
    private static Integer standardCreated = 0;
    private static Map<String, Id> psgIds = new Map<String, Id>();

    private static final Set<String> PLATFORM_PROFILES = new Set<String>{ 'Usuário de plataforma padrão', 'Standard Platform User' };
    private static final Set<String> STANDARD_PROFILES = new Set<String>{ 'Usuário Padrão', 'Standard User' };

    /** Arvore organizacional padrao com usuarios em gestor, dois colaboradores da mesma equipe e RH. */
    public class OrgTree {
        public Employee__c ceo;
        public Employee__c mgr1;
        public Employee__c mgr2;
        public Employee__c emp1;
        public Employee__c emp2;
        public Employee__c emp3;
        public Employee__c emp4;
        public User mgr1User;
        public User emp1User;
        public User emp2User;
        public User hrUser;
    }

    public static Integer nextSequence() {
        sequence++;
        return sequence;
    }

    public static Department__c department() {
        Integer n = nextSequence();
        Department__c d = new Department__c(Name = 'ZZTEST-Departamento ' + n, Code__c = 'ZZT-D' + n, Active__c = true);
        insert d;
        return d;
    }

    public static Salary_Band__c salaryBand(Decimal minSalary, Decimal maxSalary) {
        Salary_Band__c b = new Salary_Band__c(
            Name = 'ZZTEST-Faixa ' + nextSequence(),
            Min_Salary__c = minSalary,
            Mid_Salary__c = (minSalary + maxSalary) / 2,
            Max_Salary__c = maxSalary
        );
        insert b;
        return b;
    }

    public static Job_Position__c position() {
        return position(null, null);
    }

    public static Job_Position__c position(Id salaryBandId, Id nextPositionId) {
        Integer n = nextSequence();
        Job_Position__c p = new Job_Position__c(
            Name = 'ZZTEST-Cargo ' + n,
            Code__c = 'ZZT-C' + n,
            Level__c = 'Pleno',
            Career_Track__c = 'Tecnica',
            Salary_Band__c = salaryBandId,
            Next_Position__c = nextPositionId,
            Active__c = true
        );
        insert p;
        return p;
    }

    /** Colaborador sem inserir (para lotes). */
    public static Employee__c buildEmployee(Id managerId, Id userId) {
        Integer n = nextSequence();
        return new Employee__c(
            Name = 'ZZTEST-Colaborador ' + n,
            Employee_Number__c = 'ZZTEST-' + n,
            Manager__c = managerId,
            User__c = userId,
            Hire_Date__c = Date.today().addYears(-1),
            Status__c = 'Ativo',
            Employment_Type__c = 'CLT',
            Work_Location__c = 'SP-SAO_PAULO'
        );
    }

    public static Employee__c employee(Id managerId, Id userId) {
        Employee__c e = buildEmployee(managerId, userId);
        insert e;
        return e;
    }

    /**
     * Usuario de teste com o permission set group informado (ou nenhum, se null). Usuarios de HR_Admin entram no
     * grupo HR_Team. Executa em runAs do usuario atual para evitar mixed DML.
     */
    public static User user(String alias, String psgDeveloperName) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u = buildUser(alias);
            insert u;
            if (psgDeveloperName != null) {
                Id psgId = psgId(psgDeveloperName);
                insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetGroupId = psgId);
                if (psgDeveloperName == 'HR_Admin') {
                    addToHrTeam(u.Id);
                }
            }
        }
        return u;
    }

    /** Usuario com permission sets avulsos (sem grupo). */
    public static User userWithPermissionSets(String alias, List<String> permissionSetNames) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u = buildUser(alias);
            insert u;
            List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
            for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :permissionSetNames]) {
                psas.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
            }
            insert psas;
        }
        return u;
    }

    public static void addToHrTeam(Id userId) {
        Group hr = [SELECT Id FROM Group WHERE DeveloperName = 'HR_Team' LIMIT 1];
        insert new GroupMember(GroupId = hr.Id, UserOrGroupId = userId);
    }

    /**
     * CEO (sem usuario) > gestor 1 e gestor 2; gestor 1 > colaboradores 1 e 2; gestor 2 > colaborador 3;
     * colaborador 1 > colaborador 4 (indireto do gestor 1). Usuarios: gestor 1, colaboradores 1 e 2 e um RH.
     * Matriculas fixas (ZZTEST-CEO, ZZTEST-MGR1...) para recarregar com loadOrgTree() depois do @TestSetup.
     */
    public static OrgTree orgTree() {
        OrgTree t = new OrgTree();
        t.mgr1User = user('zzmgr1', 'HR_Manager');
        t.emp1User = user('zzemp1', 'HR_Employee');
        t.emp2User = user('zzemp2', 'HR_Employee');
        t.hrUser = user('zzhr', 'HR_Admin');
        t.ceo = treeEmployee('CEO', null, null);
        t.mgr1 = treeEmployee('MGR1', t.ceo.Id, t.mgr1User.Id);
        t.mgr2 = treeEmployee('MGR2', t.ceo.Id, null);
        t.emp1 = treeEmployee('EMP1', t.mgr1.Id, t.emp1User.Id);
        t.emp2 = treeEmployee('EMP2', t.mgr1.Id, t.emp2User.Id);
        t.emp3 = treeEmployee('EMP3', t.mgr2.Id, null);
        t.emp4 = treeEmployee('EMP4', t.emp1.Id, null);
        return t;
    }

    /** Recarrega a arvore criada por orgTree() em @TestSetup. */
    public static OrgTree loadOrgTree() {
        OrgTree t = new OrgTree();
        Map<String, Employee__c> byNumber = new Map<String, Employee__c>();
        for (Employee__c e : [
            SELECT Id, Name, Manager__c, User__c, Employee_Number__c, Hierarchy_Path__c, Hierarchy_Depth__c,
                Direct_Reports_Count__c
            FROM Employee__c
            WHERE Employee_Number__c IN ('ZZTEST-CEO', 'ZZTEST-MGR1', 'ZZTEST-MGR2', 'ZZTEST-EMP1', 'ZZTEST-EMP2', 'ZZTEST-EMP3', 'ZZTEST-EMP4')
        ]) {
            byNumber.put(e.Employee_Number__c, e);
        }
        t.ceo = byNumber.get('ZZTEST-CEO');
        t.mgr1 = byNumber.get('ZZTEST-MGR1');
        t.mgr2 = byNumber.get('ZZTEST-MGR2');
        t.emp1 = byNumber.get('ZZTEST-EMP1');
        t.emp2 = byNumber.get('ZZTEST-EMP2');
        t.emp3 = byNumber.get('ZZTEST-EMP3');
        t.emp4 = byNumber.get('ZZTEST-EMP4');
        for (User u : [SELECT Id, Alias FROM User WHERE Alias IN ('zzmgr1', 'zzemp1', 'zzemp2', 'zzhr') AND FirstName = 'ZZTEST']) {
            if (u.Alias == 'zzmgr1') {
                t.mgr1User = u;
            } else if (u.Alias == 'zzemp1') {
                t.emp1User = u;
            } else if (u.Alias == 'zzemp2') {
                t.emp2User = u;
            } else {
                t.hrUser = u;
            }
        }
        return t;
    }

    private static Employee__c treeEmployee(String code, Id managerId, Id userId) {
        Employee__c e = buildEmployee(managerId, userId);
        e.Name = 'ZZTEST-' + code;
        e.Employee_Number__c = 'ZZTEST-' + code;
        insert e;
        return e;
    }

    public static HR_Holiday__c holiday(Date d, String location) {
        HR_Holiday__c h = new HR_Holiday__c(
            Name = 'ZZTEST-Feriado ' + nextSequence(),
            Date__c = d,
            Location__c = location,
            Type__c = String.isBlank(location) ? 'Nacional' : 'Municipal',
            Unique_Key__c = String.valueOf(d) + '|' + (location == null ? '' : location)
        );
        insert h;
        return h;
    }

    private static User buildUser(String alias) {
        Id profileId = nextProfileId();
        String unique = alias + nextSequence() + '.' + UserInfo.getOrganizationId();
        return new User(
            Alias = alias.left(8),
            Username = unique + '@zztest.rhcore.example.com',
            Email = alias + '@zztest.rhcore.example.com',
            FirstName = 'ZZTEST',
            LastName = alias,
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            LanguageLocaleKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8'
        );
    }

    private static Id nextProfileId() {
        Map<String, Integer> free = new Map<String, Integer>();
        for (UserLicense l : [
            SELECT Name, TotalLicenses, UsedLicenses
            FROM UserLicense
            WHERE Name IN ('Salesforce', 'Salesforce Platform')
        ]) {
            free.put(l.Name, l.TotalLicenses - l.UsedLicenses);
        }
        Integer platformFree = (free.containsKey('Salesforce Platform') ? free.get('Salesforce Platform') : 0) - platformCreated;
        if (platformFree > 0) {
            platformCreated++;
            return profileIdFor(PLATFORM_PROFILES);
        }
        standardCreated++;
        return profileIdFor(STANDARD_PROFILES);
    }

    private static Id profileIdFor(Set<String> names) {
        return [SELECT Id FROM Profile WHERE Name IN :names LIMIT 1].Id;
    }

    private static Id psgId(String developerName) {
        if (!psgIds.containsKey(developerName)) {
            PermissionSetGroup g = [SELECT Id FROM PermissionSetGroup WHERE DeveloperName = :developerName LIMIT 1];
            Test.calculatePermissionSetGroup(g.Id);
            psgIds.put(developerName, g.Id);
        }
        return psgIds.get(developerName);
    }
}
