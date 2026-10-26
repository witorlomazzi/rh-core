import { LightningElement, api } from 'lwc';
import getHistory from '@salesforce/apex/PromotionRequestController.getHistory';

const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

function formatDate(iso) {
    if (!iso) {
        return '';
    }
    const [year, month, day] = iso.split('-');
    return `${day}/${month}/${year}`;
}

const REASON_ICONS = {
    Admissao: 'utility:adduser',
    Promocao: 'utility:trending',
    Merito: 'utility:favorite',
    Transferencia: 'utility:change_owner'
};

/**
 * Linha do tempo de cargos de um colaborador. Sem recordId nem employeeId mostra o historico do proprio usuario.
 * O salario so aparece quando o servidor o envia (o usuario tem acesso ao campo).
 */
export default class PositionHistoryTimeline extends LightningElement {
    @api recordId;
    @api employeeId;

    entries = [];
    salaryVisible = false;
    loading = true;
    error;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            const result = await getHistory({ employeeId: this.employeeId || this.recordId || null });
            this.salaryVisible = Boolean(result.salaryVisible);
            this.entries = result.entries || [];
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get isEmpty() {
        return !this.loading && !this.error && this.entries.length === 0;
    }

    get hasEntries() {
        return !this.loading && !this.error && this.entries.length > 0;
    }

    get rows() {
        return this.entries.map((e) => ({
            ...e,
            key: e.id,
            icon: REASON_ICONS[e.reason] || 'utility:user',
            period: e.endDate ? `${formatDate(e.startDate)} a ${formatDate(e.endDate)}` : `Desde ${formatDate(e.startDate)}`,
            showSalary: this.salaryVisible && e.salary !== null && e.salary !== undefined,
            salaryText: e.salary === null || e.salary === undefined ? '' : currency.format(e.salary),
            itemClass: e.isCurrent ? 'timeline-item timeline-item_current' : 'timeline-item'
        }));
    }
}
