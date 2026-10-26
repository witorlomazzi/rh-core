import { LightningElement } from 'lwc';
import getOverview from '@salesforce/apex/OnboardingController.getOverview';

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

function formatDate(iso) {
    if (!iso) {
        return 'sem data';
    }
    const [year, month, day] = iso.split('-');
    return `${day}/${month}/${year}`;
}

export default class OnboardingOverview extends LightningElement {
    result;
    loading = true;
    error;
    includeCompleted = false;
    selectedPlanId;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.result = await getOverview({ includeCompleted: this.includeCompleted });
            this.error = undefined;
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get showContent() {
        return !this.loading && !this.error && Boolean(this.result);
    }

    get isEmpty() {
        return this.showContent && this.result.planCount === 0;
    }

    get hasPlans() {
        return this.showContent && this.result.planCount > 0;
    }

    get plans() {
        return this.result.plans.map((p) => ({
            ...p,
            startText: formatDate(p.startDate),
            progressText: `${p.resolved} de ${p.total} (${p.progressPercent}%)`,
            overdueText: p.overdueCount === 1 ? '1 atrasada' : `${p.overdueCount} atrasadas`,
            hasOverdue: p.overdueCount > 0,
            rowClass: p.planId === this.selectedPlanId ? 'plan-row slds-is-selected' : 'plan-row',
            statusClass:
                p.status === 'Concluido'
                    ? 'slds-badge slds-theme_success'
                    : p.status === 'Em_Andamento'
                    ? 'slds-badge slds-badge_inverse'
                    : 'slds-badge'
        }));
    }

    get hasSelection() {
        return Boolean(this.selectedPlanId);
    }

    handleToggleCompleted(event) {
        this.includeCompleted = event.detail.checked;
        this.selectedPlanId = undefined;
        this.load();
    }

    handleRefresh() {
        this.load();
    }

    handleSelect(event) {
        this.selectedPlanId = event.currentTarget.dataset.id;
    }

    handleCloseDetail() {
        this.selectedPlanId = undefined;
        this.load();
    }
}
