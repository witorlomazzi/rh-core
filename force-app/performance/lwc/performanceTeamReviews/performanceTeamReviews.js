import { LightningElement } from 'lwc';
import getCycles from '@salesforce/apex/PerformanceReviewController.getCycles';
import getTeam from '@salesforce/apex/PerformanceReviewController.getTeam';

const REVIEW_STATUS_LABELS = {
    Pendente: 'Pendente',
    Em_Andamento: 'Em andamento',
    Enviada: 'Enviada',
    Calibrada: 'Calibrada',
    Liberada: 'Liberada'
};

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

export default class PerformanceTeamReviews extends LightningElement {
    cycles = [];
    cycleId;
    team;
    loading = true;
    error;
    selectedReviewId;

    connectedCallback() {
        this.init();
    }

    async init() {
        try {
            this.cycles = await getCycles();
            const open = this.cycles.find((c) => c.status === 'Avaliacao_Gestor') || this.cycles[0];
            if (open) {
                this.cycleId = open.id;
                await this.loadTeam();
            }
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    async loadTeam() {
        this.loading = true;
        this.error = undefined;
        try {
            this.team = await getTeam({ cycleId: this.cycleId });
        } catch (e) {
            this.error = errorMessage(e);
            this.team = undefined;
        } finally {
            this.loading = false;
        }
    }

    get cycleOptions() {
        return this.cycles.map((c) => ({ label: c.name, value: c.id }));
    }

    get noCycles() {
        return !this.loading && !this.error && this.cycles.length === 0;
    }

    get rows() {
        if (!this.team) {
            return [];
        }
        return this.team.rows.map((r) => ({
            ...r,
            selfLabel: !r.hasSelfAssessment ? 'Sem autoavaliação' : r.selfSubmitted ? 'Enviada' : 'Pendente',
            statusLabel: REVIEW_STATUS_LABELS[r.reviewStatus] || r.reviewStatus,
            relationLabel: r.isReviewer ? 'Equipe direta' : 'Equipe indireta',
            actionLabel: r.canEdit ? 'Avaliar' : 'Abrir'
        }));
    }

    get isEmpty() {
        return !this.loading && !this.error && !!this.team && this.team.rows.length === 0;
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get showList() {
        return !this.selectedReviewId;
    }

    handleCycleChange(event) {
        this.cycleId = event.detail.value;
        this.loadTeam();
    }

    handleOpen(event) {
        this.selectedReviewId = event.currentTarget.dataset.id;
    }

    handleClose() {
        this.selectedReviewId = undefined;
        this.loadTeam();
    }

    handleRefresh() {
        this.loadTeam();
    }
}
