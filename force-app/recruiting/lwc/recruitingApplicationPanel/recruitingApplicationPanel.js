import { LightningElement, api } from 'lwc';
import getHistory from '@salesforce/apex/RecruitingInsightsController.getHistory';

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

export default class RecruitingApplicationPanel extends LightningElement {
    /** Id da candidatura (pagina de registro de Job_Application__c). */
    @api recordId;

    items = [];
    loading = true;
    error;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            const rows = await getHistory({ applicationId: this.recordId });
            this.items = rows.map((r) => ({
                ...r,
                title: r.fromLabel ? `${r.fromLabel} para ${r.toLabel}` : `Entrada na etapa ${r.toLabel}`,
                daysLabel:
                    r.daysInPreviousStage === null || r.daysInPreviousStage === undefined
                        ? ''
                        : `${r.daysInPreviousStage} dias em ${r.fromLabel}`,
                byLabel: r.changedBy ? `por ${r.changedBy}` : ''
            }));
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    handleRefresh() {
        this.load();
    }

    get isEmpty() {
        return !this.loading && !this.error && this.items.length === 0;
    }

    get hasItems() {
        return this.items.length > 0;
    }
}
