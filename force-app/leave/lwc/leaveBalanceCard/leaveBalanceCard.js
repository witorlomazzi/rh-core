import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import LEAVE_CHANGED from '@salesforce/messageChannel/LeaveChanged__c';
import getBalance from '@salesforce/apex/LeaveRequestController.getBalance';
import { errorMessage, formatDate, formatRange, plural, percent, badgeClass } from 'c/leaveUtils';

const WARNING_DAYS = 60;

export default class LeaveBalanceCard extends LightningElement {
    /** Registro de Employee__c quando o componente esta numa pagina de registro. Sem ele, usa o usuario atual. */
    @api recordId;

    periods = [];
    employeeName;
    emptyMessage;
    error;
    loading = true;
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
            const view = await getBalance({ employeeId: this.recordId || null });
            this.periods = view.periods || [];
            this.employeeName = view.employeeName;
            this.emptyMessage = view.emptyMessage;
        } catch (e) {
            this.error = errorMessage(e);
            this.periods = [];
        } finally {
            this.loading = false;
        }
    }

    get periodViews() {
        return this.periods.map((p) => {
            const used = (p.daysTaken || 0) + (p.daysSold || 0) + (p.daysPending || 0);
            return {
                ...p,
                rangeLabel: formatRange(p.startDate, p.endDate),
                badgeClass: badgeClass(p.status),
                usedPercent: percent(used, p.entitledDays),
                usedLabel: `${used} de ${p.entitledDays} dias usados ou reservados`,
                deadlineLabel: this.deadlineLabel(p),
                deadlineClass: this.deadlineClass(p),
                showDeadline: p.status !== 'Perdido' && p.status !== 'Concluido'
            };
        });
    }

    deadlineLabel(p) {
        if (p.status === 'Em_Aquisicao') {
            return `O período aquisitivo termina em ${formatDate(p.endDate)}.`;
        }
        if (p.daysToDeadline < 0) {
            return `Prazo concessivo vencido em ${formatDate(p.concessionDeadline)}. Férias após o prazo são devidas em dobro.`;
        }
        return `Prazo para tirar as férias: ${formatDate(p.concessionDeadline)} (${plural(p.daysToDeadline, 'dia restante', 'dias restantes')}).`;
    }

    deadlineClass(p) {
        const late = p.status !== 'Em_Aquisicao' && p.daysToDeadline <= WARNING_DAYS;
        return late ? 'deadline slds-text-color_error' : 'deadline slds-text-color_weak';
    }

    get hasPeriods() {
        return !this.loading && !this.error && this.periods.length > 0;
    }

    get showEmpty() {
        return !this.loading && !this.error && this.periods.length === 0;
    }

    get emptyText() {
        return this.emptyMessage || 'Nenhum período aquisitivo encontrado.';
    }

    get cardTitle() {
        return this.employeeName && this.recordId ? `Saldo de férias de ${this.employeeName}` : 'Saldo de férias';
    }

    handleRefresh() {
        this.load();
    }

    handleRequest(event) {
        this.dispatchEvent(
            new CustomEvent('requestleave', {
                detail: { periodId: event.currentTarget.dataset.id },
                bubbles: true,
                composed: true
            })
        );
    }
}
