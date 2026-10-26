import { LightningElement, wire } from 'lwc';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import LEAVE_CHANGED from '@salesforce/messageChannel/LeaveChanged__c';
import getContext from '@salesforce/apex/MyHrController.getContext';
import { errorMessage, formatDate, formatRange, plural, tenureLabel, badgeClass } from 'c/myHrUtils';

/** Pagina inicial do Meu RH: compoe os componentes dos outros modulos conforme a persona (colaborador, gestor). */
export default class MyHrHome extends LightningElement {
    context;
    loading = true;
    error;
    showLeaveModal = false;
    requestPeriodId;
    subscription;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscription = subscribe(this.messageContext, LEAVE_CHANGED, () => this.load(true), {
            scope: APPLICATION_SCOPE
        });
        this.load(false);
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = undefined;
        }
    }

    async load(silent) {
        if (!silent) {
            this.loading = true;
        }
        this.error = undefined;
        try {
            this.context = await getContext();
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    // ------------------------------------------------------------------------------------------ estados

    get showError() {
        return !this.loading && Boolean(this.error);
    }

    get showEmpty() {
        return !this.loading && !this.error && Boolean(this.context) && !this.context.linked;
    }

    get showHome() {
        return !this.loading && !this.error && Boolean(this.context) && this.context.linked;
    }

    get emptyText() {
        return (
            (this.context && this.context.emptyMessage) ||
            'Seu usuário ainda não está vinculado a um colaborador. Fale com o RH.'
        );
    }

    get isManager() {
        return Boolean(this.context && this.context.isManager);
    }

    get hasOnboarding() {
        return Boolean(this.context && this.context.hasOnboardingPlan);
    }

    // ------------------------------------------------------------------------------------------ cabecalho

    get subtitle() {
        const parts = [this.context.positionName, this.context.departmentName].filter(Boolean);
        return parts.length > 0 ? parts.join(' - ') : 'Cargo e departamento não informados';
    }

    get managerText() {
        return this.context.managerName ? `Gestor: ${this.context.managerName}` : 'Sem gestor definido';
    }

    get tenureText() {
        return `Tempo de casa: ${tenureLabel(this.context.tenureMonths)}`;
    }

    get hireText() {
        return this.context.hireDate ? `Admissão em ${formatDate(this.context.hireDate)}` : '';
    }

    get statusClass() {
        return badgeClass(this.context.status);
    }

    // ------------------------------------------------------------------------------------------ proximas ferias

    get hasNextLeave() {
        return Boolean(this.context && this.context.nextLeave);
    }

    get nextLeaveRange() {
        const leave = this.context.nextLeave;
        return formatRange(leave.startDate, leave.endDate);
    }

    get nextLeaveDays() {
        return plural(this.context.nextLeave.days || 0, 'dia', 'dias');
    }

    get nextLeaveBadge() {
        return badgeClass(this.context.nextLeave.status);
    }

    get nextLeaveStatus() {
        return this.context.nextLeave.statusLabel;
    }

    // ------------------------------------------------------------------------------------------ acoes

    handleRetry() {
        this.load(false);
    }

    handleRequestLeave(event) {
        this.requestPeriodId = event.detail && event.detail.periodId;
        this.showLeaveModal = true;
    }

    handleCloseLeaveModal() {
        this.showLeaveModal = false;
    }

    handleLeaveSubmitted() {
        this.showLeaveModal = false;
        this.load(true);
    }
}
