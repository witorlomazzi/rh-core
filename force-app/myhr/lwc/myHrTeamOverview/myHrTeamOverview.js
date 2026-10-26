import { LightningElement } from 'lwc';
import getTeamOverview from '@salesforce/apex/MyHrController.getTeamOverview';
import { errorMessage, formatDate, formatRange, plural, badgeClass } from 'c/myHrUtils';

/** Equipe direta do gestor: situacao, saldo, proximas ferias, alerta de prazo concessivo e atalhos. */
export default class MyHrTeamOverview extends LightningElement {
    overview;
    loading = true;
    error;
    modal; // 'promotion' ou 'calendar'

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.overview = await getTeamOverview();
        } catch (e) {
            this.error = errorMessage(e);
            this.overview = undefined;
        } finally {
            this.loading = false;
        }
    }

    get showError() {
        return !this.loading && Boolean(this.error);
    }

    get showEmpty() {
        return !this.loading && !this.error && Boolean(this.overview) && this.overview.members.length === 0;
    }

    get emptyText() {
        return this.overview.emptyMessage || 'Você não tem pessoas na sua equipe direta.';
    }

    get hasMembers() {
        return !this.loading && !this.error && Boolean(this.overview) && this.overview.members.length > 0;
    }

    get isManager() {
        return Boolean(this.overview && this.overview.isManager);
    }

    get summary() {
        const count = this.overview ? this.overview.members.length : 0;
        return plural(count, 'pessoa na equipe direta', 'pessoas na equipe direta');
    }

    get hasAlerts() {
        return Boolean(this.overview && this.overview.alertCount > 0);
    }

    get alertSummary() {
        return plural(
            this.overview.alertCount,
            'pessoa com prazo concessivo próximo ou vencido',
            'pessoas com prazo concessivo próximo ou vencido'
        );
    }

    get rows() {
        return this.overview.members.map((m) => ({
            ...m,
            statusClass: badgeClass(m.status),
            balanceLabel: m.hasOpenPeriod ? plural(m.balanceDays, 'dia', 'dias') : 'Sem período disponível',
            hasNextLeave: Boolean(m.nextLeave),
            nextLeaveRange: m.nextLeave ? formatRange(m.nextLeave.startDate, m.nextLeave.endDate) : '',
            nextLeaveClass: m.nextLeave ? badgeClass(m.nextLeave.status) : '',
            nextLeaveStatus: m.nextLeave ? m.nextLeave.statusLabel : '',
            deadlineLabel: this.deadlineLabel(m),
            deadlineClass: this.deadlineClass(m),
            hasDeadline: Boolean(m.concessionDeadline)
        }));
    }

    deadlineLabel(m) {
        if (!m.concessionDeadline) {
            return '';
        }
        if (m.deadlineOverdue) {
            return `Vencido em ${formatDate(m.concessionDeadline)}`;
        }
        return `${formatDate(m.concessionDeadline)} (${plural(m.daysToDeadline, 'dia', 'dias')})`;
    }

    deadlineClass(m) {
        if (m.deadlineOverdue) {
            return 'slds-badge slds-theme_error deadline';
        }
        return m.deadlineAlert ? 'slds-badge slds-theme_warning deadline' : 'deadline';
    }

    // ------------------------------------------------------------------------------------------ atalhos

    get showPromotionModal() {
        return this.modal === 'promotion';
    }

    get showCalendarModal() {
        return this.modal === 'calendar';
    }

    handleOpenPromotion() {
        this.modal = 'promotion';
    }

    handleOpenCalendar() {
        this.modal = 'calendar';
    }

    handleCloseModal() {
        this.modal = undefined;
    }

    handleRefresh() {
        this.load();
    }
}
