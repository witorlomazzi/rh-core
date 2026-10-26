import { LightningElement } from 'lwc';

/**
 * Pagina "Minhas ferias": o cartao de saldo dispara requestleave com periodId; este container repassa o periodo ao
 * formulario (propriedade period-id). Componentes irmaos em FlexiPage nao conseguem se falar, por isso o container.
 */
export default class MyHrLeave extends LightningElement {
    periodId;

    handleRequestLeave(event) {
        this.periodId = event.detail && event.detail.periodId;
        const form = this.template.querySelector('c-leave-request-form');
        if (form && form.scrollIntoView) {
            form.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }
}
