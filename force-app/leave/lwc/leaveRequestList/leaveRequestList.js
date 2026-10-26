import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, publish, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import LEAVE_CHANGED from '@salesforce/messageChannel/LeaveChanged__c';
import getRequests from '@salesforce/apex/LeaveRequestController.getRequests';
import cancelRequest from '@salesforce/apex/LeaveRequestController.cancelRequest';
import { errorMessage, formatRange, plural, badgeClass } from 'c/leaveUtils';

export default class LeaveRequestList extends LightningElement {
    /** Registro de Employee__c quando o componente esta numa pagina de registro. Sem ele, usa o usuario atual. */
    @api recordId;

    requests = [];
    loading = true;
    error;
    confirmingId;
    busyId;
    subscription;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscription = subscribe(this.messageContext, LEAVE_CHANGED, () => this.load(), {
            scope: APPLICATION_SCOPE
        });
        this.load();
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = undefined;
        }
    }

    @api
    refresh() {
        return this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.requests = await getRequests({ employeeId: this.recordId || null });
        } catch (e) {
            this.error = errorMessage(e);
            this.requests = [];
        } finally {
            this.loading = false;
        }
    }

    get requestViews() {
        return this.requests.map((r) => ({
            ...r,
            rangeLabel: formatRange(r.startDate, r.endDate),
            daysLabel: this.daysLabel(r),
            badgeClass: badgeClass(r.status),
            isConfirming: r.id === this.confirmingId,
            isBusy: r.id === this.busyId,
            hasConflict: Boolean(r.teamConflictWarning)
        }));
    }

    daysLabel(r) {
        const gozo = plural(r.days, 'dia de gozo', 'dias de gozo');
        return r.soldDays > 0 ? `${gozo} e ${plural(r.soldDays, 'dia vendido', 'dias vendidos')}` : gozo;
    }

    get isEmpty() {
        return !this.loading && !this.error && this.requests.length === 0;
    }

    get hasRequests() {
        return this.requests.length > 0;
    }

    get countLabel() {
        return plural(this.requests.length, 'solicitação', 'solicitações');
    }

    handleRefresh() {
        this.load();
    }

    handleAskCancel(event) {
        this.confirmingId = event.currentTarget.dataset.id;
    }

    handleKeep() {
        this.confirmingId = undefined;
    }

    async handleConfirmCancel(event) {
        const requestId = event.currentTarget.dataset.id;
        this.busyId = requestId;
        try {
            await cancelRequest({ requestId });
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Solicitação cancelada', message: 'O saldo foi liberado.', variant: 'success' })
            );
            this.confirmingId = undefined;
            publish(this.messageContext, LEAVE_CHANGED, { employeeId: this.recordId || null });
            await this.load();
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Não foi possível cancelar', message: errorMessage(e), variant: 'error' })
            );
        } finally {
            this.busyId = undefined;
        }
    }
}
