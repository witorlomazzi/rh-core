// RH Core, dados de demonstracao da Vetra Distribuidora (empresa ficticia). Fase 0: usuarios de demonstracao.
// Projeto demonstrativo, empresa e dados ficticios. Nenhum dado real.
//
// Roda ANTES das demais fases e sozinha, porque cria usuarios e atribuicoes de permissao (objetos de
// configuracao) e o Apex anonimo nao permite misturar esse DML com o de objetos de dados (MIXED_DML_OPERATION).
// Idempotente: reexecutar nao duplica usuario, atribuicao nem participacao no grupo.
// Requisito: o admin que executa ja deve ter HR_Admin e HR_Manager (scripts/apex/assign-admin-psg.apex).
//
// Usuarios: 3 da licenca "Salesforce Platform" (perfil Usuario de plataforma padrao), cada um vinculado depois a um
// colaborador (fase 1): Carolina Fontes (colaboradora), Marcelo Ibrahim (recrutador), Claudia Rezende (RH).
// O nome de usuario leva um sufixo da org porque o username e unico entre todas as orgs Salesforce.
// Sem licenca livre, o usuario e ignorado e a demonstracao segue so com o admin.

String suffix = UserInfo.getOrganizationId().toLowerCase().right(6);
List<String> specs = new List<String>{
    'carolina.fontes#Carolina#Fontes#cfontes#HR_Employee',
    'marcelo.ibrahim#Marcelo#Ibrahim#mibrahim#HR_Recruiter',
    'claudia.rezende#Cláudia#Rezende#crezende#HR_Admin'
};

List<Profile> profiles = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Salesforce Platform' ORDER BY Name LIMIT 1];
if (profiles.isEmpty()) {
    System.debug('Nenhum perfil da licenca Salesforce Platform: usuarios de demonstracao ignorados.');
    return;
}
Integer freeLicenses = 0;
for (UserLicense l : [SELECT TotalLicenses, UsedLicenses FROM UserLicense WHERE Name = 'Salesforce Platform']) {
    freeLicenses = l.TotalLicenses - l.UsedLicenses;
}

Set<String> usernames = new Set<String>();
for (String s : specs) {
    usernames.add(s.split('#')[0] + '.' + suffix + '@vetra-rh.example');
}
Map<String, User> existing = new Map<String, User>();
for (User u : [SELECT Id, Username FROM User WHERE Username IN :usernames]) {
    existing.put(u.Username, u);
}

Database.DMLOptions opts = new Database.DMLOptions();
opts.EmailHeader.triggerUserEmail = false;
List<User> toInsert = new List<User>();
for (String s : specs) {
    List<String> p = s.split('#');
    String username = p[0] + '.' + suffix + '@vetra-rh.example';
    if (existing.containsKey(username)) {
        continue;
    }
    if (freeLicenses <= toInsert.size()) {
        System.debug('Sem licenca livre para ' + p[1] + ' ' + p[2] + ': ignorado.');
        continue;
    }
    User u = new User(
        Username = username, Email = p[0] + '@vetra.example', FirstName = p[1], LastName = p[2], Alias = p[3],
        ProfileId = profiles[0].Id, TimeZoneSidKey = 'America/Sao_Paulo', LocaleSidKey = 'pt_BR',
        LanguageLocaleKey = 'pt_BR', EmailEncodingKey = 'UTF-8', IsActive = true
    );
    u.setOptions(opts);
    toInsert.add(u);
}
if (!toInsert.isEmpty()) {
    insert toInsert;
    for (User u : toInsert) {
        existing.put(u.Username, u);
    }
}

// Atribuicao dos grupos de permissao e do grupo HR_Team (RH).
Map<String, Id> psgByName = new Map<String, Id>();
for (PermissionSetGroup g : [SELECT Id, DeveloperName FROM PermissionSetGroup WHERE Status = 'Updated']) {
    psgByName.put(g.DeveloperName, g.Id);
}
Set<Id> userIds = new Set<Id>();
for (User u : existing.values()) {
    userIds.add(u.Id);
}
Set<String> assigned = new Set<String>();
for (PermissionSetAssignment a : [
    SELECT AssigneeId, PermissionSetGroupId FROM PermissionSetAssignment WHERE AssigneeId IN :userIds AND PermissionSetGroupId != NULL
]) {
    assigned.add(a.AssigneeId + '|' + a.PermissionSetGroupId);
}
List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
List<GroupMember> members = new List<GroupMember>();
List<Group> hrGroups = [SELECT Id FROM Group WHERE DeveloperName = 'HR_Team' AND Type = 'Regular' LIMIT 1];
Set<Id> inHr = new Set<Id>();
if (!hrGroups.isEmpty()) {
    for (GroupMember m : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :hrGroups[0].Id]) {
        inHr.add(m.UserOrGroupId);
    }
}
for (String s : specs) {
    List<String> p = s.split('#');
    User u = existing.get(p[0] + '.' + suffix + '@vetra-rh.example');
    Id psgId = psgByName.get(p[4]);
    if (u == null || psgId == null) {
        continue;
    }
    if (!assigned.contains(u.Id + '|' + psgId)) {
        assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetGroupId = psgId));
    }
    if (p[4] == 'HR_Admin' && !hrGroups.isEmpty() && !inHr.contains(u.Id)) {
        members.add(new GroupMember(GroupId = hrGroups[0].Id, UserOrGroupId = u.Id));
    }
}
insert assignments;
insert members;
System.debug('Fase 0 (usuarios): ' + toInsert.size() + ' usuarios criados, ' + assignments.size() + ' atribuicoes, ' + members.size() + ' no grupo HR_Team.');
