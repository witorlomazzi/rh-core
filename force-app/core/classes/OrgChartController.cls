/**
 * Dados do organograma (coreOrgChart). Tudo em USER_MODE pelo EmployeeSelector: o usuario so ve quem o
 * compartilhamento permite. Nao expoe salario.
 *
 * Excecao documentada: o cartao do gestor direto (nome, cargo e departamento) e lido em modo sistema, porque o
 * colaborador nao tem share no registro do proprio gestor. Sao os mesmos dados que o campo de pesquisa Gestor ja
 * exibe no registro do colaborador.
 */
// Leitura em sistema restrita ao cartao do gestor (ver comentario da classe); o resto usa EmployeeSelector em USER_MODE.
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class OrgChartController {
    private static final Integer SEARCH_LIMIT = 20;

    public class OrgNode {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String initials;
        @AuraEnabled
        public String positionName;
        @AuraEnabled
        public String departmentName;
        @AuraEnabled
        public Integer directReports;
        @AuraEnabled
        public Boolean hasChildren;

        public OrgNode(Employee__c e) {
            this.id = e.Id;
            this.name = e.Name;
            this.initials = initialsOf(e.Name);
            this.positionName = e.Position__r == null ? null : e.Position__r.Name;
            this.departmentName = e.Department__r == null ? null : e.Department__r.Name;
            this.directReports = e.Direct_Reports_Count__c == null ? 0 : e.Direct_Reports_Count__c.intValue();
            this.hasChildren = this.directReports > 0;
        }
    }

    public class OrgChartView {
        @AuraEnabled
        public OrgNode manager;
        @AuraEnabled
        public List<OrgNode> focus = new List<OrgNode>();
        @AuraEnabled
        public List<OrgNode> reports = new List<OrgNode>();
        @AuraEnabled
        public Boolean isHr = false;
        @AuraEnabled
        public String emptyMessage;
    }

    /**
     * Visao inicial. Com employeeId (pagina de registro): a partir daquele colaborador. Sem: a partir do usuario
     * atual; o RH comeca pela raiz.
     */
    @AuraEnabled
    public static OrgChartView getInitial(Id employeeId) {
        try {
            OrgChartView view = new OrgChartView();
            view.isHr = FeatureManagement.checkPermission('HR_Admin_Access');
            Employee__c start;
            if (employeeId != null) {
                List<Employee__c> rows = EmployeeSelector.byIds(new Set<Id>{ employeeId });
                start = rows.isEmpty() ? null : rows[0];
            } else if (view.isHr) {
                for (Employee__c root : EmployeeSelector.roots()) {
                    view.focus.add(new OrgNode(root));
                }
                if (view.focus.size() == 1) {
                    view.reports = children(view.focus[0].id);
                }
                if (view.focus.isEmpty()) {
                    view.emptyMessage = 'Nenhum colaborador cadastrado.';
                }
                return view;
            } else {
                start = EmployeeSelector.currentUserEmployee();
            }
            if (start == null) {
                view.emptyMessage = 'Seu usuário ainda não está vinculado a um colaborador. Fale com o RH.';
                return view;
            }
            view.focus.add(new OrgNode(start));
            view.reports = children(start.Id);
            if (start.Manager__c != null) {
                view.manager = managerCard(start.Manager__c);
            }
            return view;
        } catch (Exception e) {
            throw new AuraHandledException('Não foi possível carregar o organograma. ' + e.getMessage());
        }
    }

    /** Subordinados diretos visiveis ao usuario. */
    @AuraEnabled
    public static List<OrgNode> children(Id employeeId) {
        List<OrgNode> result = new List<OrgNode>();
        for (Employee__c e : EmployeeSelector.directReports(employeeId)) {
            if (e.Status__c != 'Desligado') {
                result.add(new OrgNode(e));
            }
        }
        return result;
    }

    /** Busca por nome entre os colaboradores visiveis ao usuario (minimo de 2 caracteres). */
    @AuraEnabled
    public static List<OrgNode> search(String term) {
        List<OrgNode> result = new List<OrgNode>();
        if (String.isBlank(term) || term.trim().length() < 2) {
            return result;
        }
        for (Employee__c e : EmployeeSelector.searchByName(term, SEARCH_LIMIT)) {
            result.add(new OrgNode(e));
        }
        return result;
    }

    private static OrgNode managerCard(Id managerId) {
        List<Employee__c> visible = EmployeeSelector.byIds(new Set<Id>{ managerId });
        if (!visible.isEmpty()) {
            return new OrgNode(visible[0]);
        }
        return new ManagerCardReader().readCard(managerId);
    }

    @TestVisible
    private static String initialsOf(String fullName) {
        if (String.isBlank(fullName)) {
            return '';
        }
        List<String> parts = fullName.trim().split('\\s+');
        String first = parts[0].left(1);
        String last = parts.size() > 1 ? parts[parts.size() - 1].left(1) : '';
        return (first + last).toUpperCase();
    }

    /** Leitura em modo sistema restrita a nome, cargo e departamento do gestor (ver comentario da classe). */
    private without sharing class ManagerCardReader {
        private OrgNode readCard(Id managerId) {
            List<Employee__c> rows = [
                SELECT Id, Name, Position__r.Name, Department__r.Name, Direct_Reports_Count__c
                FROM Employee__c
                WHERE Id = :managerId
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                return null;
            }
            OrgNode node = new OrgNode(rows[0]);
            // O usuario nao pode expandir a equipe do gestor: so ve a propria linha.
            node.hasChildren = false;
            return node;
        }
    }
}
