import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import LEAVE_CHANGED from '@salesforce/messageChannel/LeaveChanged__c';
import getBalance from '@salesforce/apex/LeaveRequestController.getBalance';
import checkRules from '@salesforce/apex/LeaveRequestController.checkRules';
import submitRequest from '@salesforce/apex/LeaveRequestController.submitRequest';
import { errorMessage, formatRange } from 'c/leaveUtils';

const LEVEL_ICON = { ok: 'utility:success', warning: 'utility:warning', blocked: 'utility:error' };
const LEVEL_TEXT = { ok: 'Regra cumprida', warning: 'Aviso', blocked: 'Bloqueio' };

export default class LeaveRequestForm extends LightningElement {
    /** Registro de Employee__c quando o componente esta numa pagina de registro. Sem ele, usa o usuario atual. */
    @api recordId;
    /** Periodo pre-selecionado (ex.: vindo do evento requestleave do cartao de saldo). */
    @api
    get periodId() {
        return this.selectedPeriodId;
    }
    set periodId(value) {
        this.selectedPeriodId = value;
        this.check = undefined;
    }

    selectedPeriodId;
    periods = [];
    isHr = false;
    startDate;
    days;
    soldDays;
    notes = '';
    allowException = false;
    check;
    loading = true;
    busy = false;
    error;
    emptyMessage;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.loadPeriods();
    }

    async loadPeriods() {
        this.loading = true;
        this.error = undefined;
        try {
            const view = await getBalance({ employeeId: this.recordId || null });
            this.isHr = view.isHr === true;
            this.periods = (view.periods || []).filter((p) => p.canRequest);
            this.emptyMessage = view.emptyMessage;
            const stillValid = this.periods.some((p) => p.id === this.selectedPeriodId);
            if (!stillValid) {
                this.selectedPeriodId = this.periods.length === 1 ? this.periods[0].id : undefined;
            }
        } catch (e) {
            this.error = errorMessage(e);
            this.periods = [];
        } finally {
            this.loading = false;
        }
    }

    // ------------------------------------------------------------------------------------------ dados da tela

    get periodOptions() {
        return this.periods.map((p) => ({
            value: p.id,
            label: `${formatRange(p.startDate, p.endDate)} (saldo de ${p.balanceDays} dias)`
        }));
    }

    get hasPeriods() {
        return this.periods.length > 0;
    }

    get showNoPeriods() {
        return !this.loading && !this.error && this.periods.length === 0;
    }

    get noPeriodsText() {
        return this.emptyMessage || 'Nenhum período aquisitivo disponível para solicitar férias agora.';
    }

    get showForm() {
        return !this.loading && !this.error && this.hasPeriods;
    }

    get canCheck() {
        return Boolean(this.selectedPeriodId && this.startDate && Number(this.days) >= 1);
    }

    get checkDisabled() {
        return !this.canCheck || this.busy;
    }

    get submitDisabled() {
        return !this.check || !this.check.canSubmit || this.busy;
    }

    get ruleViews() {
        if (!this.check) {
            return [];
        }
        return this.check.rules.map((r) => ({
            ...r,
            icon: LEVEL_ICON[r.level],
            levelText: LEVEL_TEXT[r.level],
            itemClass: `rule rule-${r.level} slds-grid slds-m-bottom_x-small`,
            iconClass: `rule-icon rule-icon-${r.level} slds-m-right_x-small`
        }));
    }

    get hasResult() {
        return Boolean(this.check);
    }

    get summaryText() {
        if (!this.check) {
            return '';
        }
        if (this.check.hasBlocking) {
            return 'Há regras impeditivas. Ajuste o pedido para poder enviar.';
        }
        if (this.check.hasWarning) {
            return 'O pedido pode ser enviado, mas leia os avisos.';
        }
        return 'Todas as regras foram cumpridas.';
    }

    get summaryClass() {
        const base = 'summary slds-p-around_small slds-m-bottom_small';
        if (!this.check) {
            return base;
        }
        if (this.check.hasBlocking) {
            return `${base} summary-blocked`;
        }
        return this.check.hasWarning ? `${base} summary-warning` : `${base} summary-ok`;
    }

    // ------------------------------------------------------------------------------------------ eventos

    handleChange(event) {
        const field = event.target.dataset.field;
        const value = field === 'allowException' ? event.target.checked : event.target.value;
        if (field === 'selectedPeriodId') {
            this.selectedPeriodId = value;
        } else if (field === 'allowException') {
            this.allowException = value;
        } else {
            this[field] = value;
        }
        // Qualquer mudanca invalida a verificacao anterior: o envio exige verificar de novo.
        this.check = undefined;
    }

    payload() {
        return {
            periodId: this.selectedPeriodId,
            startDate: this.startDate,
            days: Number(this.days),
            soldDays: this.soldDays ? Number(this.soldDays) : 0,
            allowNoticeException: this.allowException
        };
    }

    async handleCheck() {
        this.busy = true;
        try {
            this.check = await checkRules(this.payload());
        } catch (e) {
            this.check = undefined;
            this.toast('Não foi possível verificar as regras', errorMessage(e), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleSubmit() {
        if (this.submitDisabled) {
            return;
        }
        this.busy = true;
        try {
            const result = await submitRequest({ ...this.payload(), notes: this.notes });
            if (result.submitted) {
                this.toast('Solicitação enviada', 'O pedido foi enviado para aprovação.', 'success');
                this.dispatchEvent(new CustomEvent('submitted', { detail: { requestId: result.requestId } }));
                publish(this.messageContext, LEAVE_CHANGED, { employeeId: this.recordId || null });
                this.resetForm();
                await this.loadPeriods();
            } else {
                this.check = result;
                this.toast('Pedido não enviado', 'As regras mudaram desde a verificação. Veja os bloqueios.', 'error');
            }
        } catch (e) {
            this.toast('Não foi possível enviar', errorMessage(e), 'error');
        } finally {
            this.busy = false;
        }
    }

    resetForm() {
        this.startDate = undefined;
        this.days = undefined;
        this.soldDays = undefined;
        this.notes = '';
        this.allowException = false;
        this.check = undefined;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
