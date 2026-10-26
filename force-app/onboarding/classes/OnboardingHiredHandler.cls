/**
 * Implementacao do contrato HiredApplicationHandler (spec 13, C10). O recrutamento a resolve por nome
 * (Type.forName('OnboardingHiredHandler')) quando uma candidatura entra em Contratado e a chama na mesma transacao:
 * uma excecao daqui desfaz a contratacao, porque nao pode existir contratado sem colaborador e plano.
 *
 * Toda a regra esta em OnboardingService.createFromApplication (contexto de sistema documentado na spec 02).
 */
public with sharing class OnboardingHiredHandler implements HiredApplicationHandler {
    public void handle(Set<Id> applicationIds) {
        OnboardingService.createFromApplication(applicationIds);
    }
}
