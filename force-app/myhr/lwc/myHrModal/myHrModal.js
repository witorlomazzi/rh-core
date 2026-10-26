import { LightningElement, api } from 'lwc';

/** Modal SLDS reutilizado pelo Meu RH. Dispara "close" ao clicar em fechar, no fundo ou ao apertar Esc. */
export default class MyHrModal extends LightningElement {
    @api heading = '';
    @api size = 'medium';

    get dialogClass() {
        return `slds-modal slds-fade-in-open slds-modal_${this.size}`;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleKeydown(event) {
        if (event.key === 'Escape') {
            this.handleClose();
        }
    }
}
