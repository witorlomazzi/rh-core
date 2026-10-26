import { LightningElement, api } from 'lwc';
import getEmployeeReviews from '@salesforce/apex/MyHrController.getEmployeeReviews';
import { errorMessage, formatDate, badgeClass } from 'c/myHrUtils';

const STATUS_LABEL = {
    Pendente: 'Pendente',
    Em_Andamento: 'Em andamento',
    Enviada: 'Enviada',
    Calibrada: 'Calibrada',
    Liberada: 'Liberada'
};

/** Aba Desempenho do registro do colaborador: so mostra o que o compartilhamento permite ao usuario ler. */
export default class MyHrEmployeeReviews extends LightningElement {
    @api recordId;

    reviews = [];
    loading = true;
    error;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.reviews = await getEmployeeReviews({ employeeId: this.recordId });
        } catch (e) {
            this.error = errorMessage(e);
            this.reviews = [];
        } finally {
            this.loading = false;
        }
    }

    get rows() {
        return this.reviews.map((r) => ({
            ...r,
            statusLabel: STATUS_LABEL[r.status] || r.status,
            statusClass: badgeClass(r.status),
            hasRating: r.finalRating !== null && r.finalRating !== undefined,
            releasedLabel: r.releasedDate ? `Liberada em ${formatDate(String(r.releasedDate).substring(0, 10))}` : ''
        }));
    }

    get showEmpty() {
        return !this.loading && !this.error && this.reviews.length === 0;
    }

    get hasRows() {
        return !this.loading && !this.error && this.reviews.length > 0;
    }
}
