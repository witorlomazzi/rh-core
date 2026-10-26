/**
 * Contrato entre recrutamento e admissao. O recrutamento chama a implementacao quando uma candidatura vira
 * Contratado (JobApplicationService.onHired). A implementacao e resolvida por nome (Type.forName), entao o
 * recrutamento funciona sozinho quando o modulo de admissao nao esta instalado.
 *
 * Implementacao esperada: OnboardingHiredHandler (modulo onboarding, spec 15). O metodo recebe os Ids das
 * candidaturas que acabaram de entrar na etapa Contratado e roda na mesma transacao da mudanca de etapa.
 */
public interface HiredApplicationHandler {
    void handle(Set<Id> applicationIds);
}
