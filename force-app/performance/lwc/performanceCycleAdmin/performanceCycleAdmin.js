import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCycles from '@salesforce/apex/PerformanceReviewController.getCycles';
import getOverview from '@salesforce/apex/ReviewCycleController.getOverview';
import createCycle from '@salesforce/apex/ReviewCycleController.createCycle';
import launch from '@salesforce/apex/ReviewCycleController.launch';
import advance from '@salesforce/apex/ReviewCycleController.advance';
import release from '@salesforce/apex/ReviewCycleController.release';
import getCalibration from '@salesforce/apex/ReviewCycleController.getCalibration';
import calibrate from '@salesforce/apex/ReviewCycleController.calibrate';

const CYCLE_STATUS_LABELS = {
    Planejado: 'Planejado',
    Autoavaliacao: 'Autoavaliação',
    Avaliacao_Gestor: 'Avaliação do gestor',
    Calibracao: 'Calibração',
    Concluido: 'Concluído'
};

const REVIEW_STATUS_LABELS = {
    Pendente: 'Pendente',
    Em_Andamento: 'Em andamento',
    Enviada: 'Enviada',
    Calibrada: 'Calibrada',
    Liberada: 'Liberada'
};

const NEXT_ACTION = {
    Planejado: { key: 'launch', label: 'Lançar ciclo' },
    Autoavaliacao: { key: 'advance', label: 'Avançar para a avaliação do gestor' },
    Avaliacao_Gestor: { key: 'advance', label: 'Avançar para a calibração' },
    Calibracao: { key: 'release', label: 'Liberar resultados' }
};

const CONFIRM_TEXT = {
    launch: 'Lançar o ciclo cria a autoavaliação e a avaliação de cada colaborador ativo e avisa a todos. Confirmar?',
    release: 'Liberar os resultados encerra o ciclo e mostra a avaliação do gestor aos colaboradores. Confirmar?'
};

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

export default class PerformanceCycleAdmin extends LightningElement {
    cycles = [];
    cycleId;
    overview;
    calibrationRows = [];
    calibrationDraft = {};
    loading = true;
    busy = false;
    error;
    confirming;
    creating = false;
    newCycle = { name: '', startDate: null, endDate: null, selfDue: null, managerDue: null, scaleMax: 5 };

    connectedCallback() {
        this.init();
    }

    async init() {
        try {
            this.cycles = await getCycles();
            if (this.cycles.length) {
                this.cycleId = this.cycles[0].id;
                await this.loadCycle();
            }
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    async loadCycle() {
        this.loading = true;
        this.error = undefined;
        try {
            this.overview = await getOverview({ cycleId: this.cycleId });
            const status = this.overview.cycle.status;
            if (status === 'Calibracao' || status === 'Concluido') {
                this.calibrationRows = await getCalibration({ cycleId: this.cycleId });
            } else {
                this.calibrationRows = [];
            }
            this.calibrationDraft = {};
        } catch (e) {
            this.error = errorMessage(e);
            this.overview = undefined;
        } finally {
            this.loading = false;
        }
    }

    // --------------------------------------------------------------------------------------- estado derivado

    get cycleOptions() {
        return this.cycles.map((c) => ({ label: c.name, value: c.id }));
    }

    get noCycles() {
        return !this.loading && !this.error && this.cycles.length === 0;
    }

    get hasOverview() {
        return !!this.overview;
    }

    get statusLabel() {
        return this.overview ? CYCLE_STATUS_LABELS[this.overview.cycle.status] || this.overview.cycle.status : '';
    }

    get nextAction() {
        return this.overview ? NEXT_ACTION[this.overview.cycle.status] : undefined;
    }

    get hasNextAction() {
        return !!this.nextAction;
    }

    get nextActionLabel() {
        return this.nextAction ? this.nextAction.label : '';
    }

    get statusCounts() {
        if (!this.overview) {
            return [];
        }
        return this.overview.reviewsByStatus.map((s) => ({
            status: s.status,
            label: REVIEW_STATUS_LABELS[s.status] || s.status,
            total: s.total
        }));
    }

    get selfLabel() {
        return this.overview ? this.overview.selfSubmitted + ' de ' + this.overview.selfTotal : '';
    }

    get confirmText() {
        return this.confirming ? CONFIRM_TEXT[this.confirming] : '';
    }

    get showCalibration() {
        return this.calibrationRows.length > 0;
    }

    get calibrating() {
        return !!this.overview && this.overview.cycle.status === 'Calibracao';
    }

    get calibrationView() {
        const max = this.overview ? this.overview.cycle.scaleMax || 5 : 5;
        const options = [];
        for (let i = 1; i <= max; i++) {
            options.push({ label: String(i), value: String(i) });
        }
        return this.calibrationRows.map((r) => {
            const draft = this.calibrationDraft[r.reviewId];
            const current = r.calibratedRating === null || r.calibratedRating === undefined ? undefined : String(r.calibratedRating);
            return {
                ...r,
                statusLabel: REVIEW_STATUS_LABELS[r.status] || r.status,
                options,
                value: draft !== undefined ? draft : current,
                saveDisabled: this.busy || draft === undefined,
                finalLabel: r.finalRating === null || r.finalRating === undefined ? '-' : String(r.finalRating),
                managerLabel: r.managerRating === null || r.managerRating === undefined ? '-' : String(r.managerRating),
                calibratedLabel: r.calibratedRating === null || r.calibratedRating === undefined ? '-' : String(r.calibratedRating)
            };
        });
    }

    // ------------------------------------------------------------------------------------------- handlers

    handleCycleChange(event) {
        this.cycleId = event.detail.value;
        this.confirming = undefined;
        this.loadCycle();
    }

    handleNextAction() {
        const key = this.nextAction.key;
        if (key === 'advance') {
            this.execute('advance');
        } else {
            this.confirming = key;
        }
    }

    handleConfirm() {
        const key = this.confirming;
        this.confirming = undefined;
        this.execute(key);
    }

    handleCancelConfirm() {
        this.confirming = undefined;
    }

    async execute(key) {
        this.busy = true;
        try {
            const payload = { cycleId: this.cycleId };
            let message;
            if (key === 'launch') {
                const result = await launch(payload);
                message = result.async
                    ? 'O lançamento foi para processamento em lote; o ciclo abre ao terminar.'
                    : result.reviewsCreated + ' avaliações criadas e ' + result.selfAssessmentsCreated + ' autoavaliações criadas.';
            } else if (key === 'advance') {
                await advance(payload);
                message = 'A fase do ciclo foi atualizada.';
            } else {
                const result = await release(payload);
                message = result.released + ' avaliações liberadas.' + (result.notReleased ? ' ' + result.notReleased + ' ficaram sem liberação.' : '');
            }
            this.dispatchEvent(new ShowToastEvent({ title: 'Ciclo atualizado', message, variant: 'success' }));
            await this.loadCycle();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível concluir', message: errorMessage(e), variant: 'error' }));
        } finally {
            this.busy = false;
        }
    }

    handleCalibrationChange(event) {
        this.calibrationDraft = { ...this.calibrationDraft, [event.target.dataset.id]: event.detail.value };
    }

    async handleCalibrate(event) {
        const reviewId = event.currentTarget.dataset.id;
        this.busy = true;
        try {
            await calibrate({ reviewId, rating: Number(this.calibrationDraft[reviewId]) });
            this.dispatchEvent(new ShowToastEvent({ title: 'Nota calibrada', message: 'A avaliação foi calibrada.', variant: 'success' }));
            await this.loadCycle();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível calibrar', message: errorMessage(e), variant: 'error' }));
        } finally {
            this.busy = false;
        }
    }

    // ---------------------------------------------------------------------------------------------- novo ciclo

    handleToggleCreate() {
        this.creating = !this.creating;
    }

    handleNewField(event) {
        this.newCycle = { ...this.newCycle, [event.target.dataset.field]: event.detail.value };
    }

    async handleCreate() {
        this.busy = true;
        try {
            const c = this.newCycle;
            const id = await createCycle({
                name: c.name,
                startDate: c.startDate,
                endDate: c.endDate,
                selfDue: c.selfDue,
                managerDue: c.managerDue,
                scaleMax: Number(c.scaleMax)
            });
            this.dispatchEvent(new ShowToastEvent({ title: 'Ciclo criado', message: 'O ciclo nasce em Planejado.', variant: 'success' }));
            this.creating = false;
            this.cycles = await getCycles();
            this.cycleId = id;
            await this.loadCycle();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível criar', message: errorMessage(e), variant: 'error' }));
        } finally {
            this.busy = false;
        }
    }
}
