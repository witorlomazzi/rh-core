// Atribui os grupos de permissao HR_Admin e HR_Manager ao usuario que executa (admin da scratch org).
// Necessario para o admin enxergar os campos (FLS) no Apex anonimo, no describe e nas telas.
Set<String> names = new Set<String>{ 'HR_Admin', 'HR_Manager' };
Id me = UserInfo.getUserId();
Set<Id> already = new Set<Id>();
for (PermissionSetAssignment a : [SELECT PermissionSetGroupId FROM PermissionSetAssignment WHERE AssigneeId = :me AND PermissionSetGroupId != null]) {
    already.add(a.PermissionSetGroupId);
}
List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
for (PermissionSetGroup g : [SELECT Id, DeveloperName, Status FROM PermissionSetGroup WHERE DeveloperName IN :names]) {
    if (!already.contains(g.Id)) {
        toInsert.add(new PermissionSetAssignment(AssigneeId = me, PermissionSetGroupId = g.Id));
    }
}
insert toInsert;
List<Group> hr = [SELECT Id FROM Group WHERE DeveloperName = 'HR_Team' LIMIT 1];
if (!hr.isEmpty() && [SELECT COUNT() FROM GroupMember WHERE GroupId = :hr[0].Id AND UserOrGroupId = :me] == 0) {
    insert new GroupMember(GroupId = hr[0].Id, UserOrGroupId = me);
}
System.debug('PSG atribuidos: ' + toInsert.size());
