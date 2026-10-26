import { LightningElement, api } from 'lwc';
import getOpeningSummary from '@salesforce/apex/RecruitingInsightsController.getOpeningSummary';

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

export default class RecruitingOpeningSummary extends LightningElement {
    /** Id da vaga (pagina de registro de Job_Opening__c). */
    @api recordId;

    summary;
    loading = true;
    error;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.summary = await getOpeningSummary({ openingId: this.recordId });
        } catch (e) {
            this.summary = undefined;
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    handleRefresh() {
        this.load();
    }

    get hasSummary() {
        return !!this.summary;
    }

    get totalLabel() {
        return this.summary ? `${this.summary.total} no total, ${this.summary.inProgress} em andamento` : '';
    }

    get rows() {
        if (!this.summary) {
            return [];
        }
        const max = Math.max(1, ...this.summary.stages.map((s) => s.count));
        return this.summary.stages.map((s) => ({
            ...s,
            averageLabel:
                s.averageDays === null || s.averageDays === undefined ? 'sem dados' : `${s.averageDays} dias`,
            barStyle: `width: ${Math.round((s.count / max) * 100)}%; background-color: ${s.color || '#706e6b'}`
        }));
    }
}
