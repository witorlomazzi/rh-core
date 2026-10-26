import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReviewForm from '@salesforce/apex/PerformanceReviewController.getReviewForm';
import saveReview from '@salesforce/apex/PerformanceReviewController.saveReview';

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

export default class PerformanceReviewForm extends LightningElement {
    _reviewId;
    view;
    loading = false;
    busy = false;
    error;
    rating;
    comments = '';

    @api
    get reviewId() {
        return this._reviewId;
    }
    set reviewId(value) {
        this.applyId(value);
    }

    applyId(value) {
        if (value && value !== this._reviewId) {
            this._reviewId = value;
            this.load();
        }
    }

    // Permite usar o componente numa pagina de registro de Performance_Review__c.
    @api
    get recordId() {
        return this._reviewId;
    }
    set recordId(value) {
        this.applyId(value);
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.apply(await getReviewForm({ reviewId: this._reviewId }));
        } catch (e) {
            this.error = errorMessage(e);
            this.view = undefined;
        } finally {
            this.loading = false;
        }
    }

    apply(view) {
        this.view = view;
        this.rating = view.managerRating === null || view.managerRating === undefined ? undefined : String(view.managerRating);
        this.comments = view.managerComments || '';
    }

    get hasView() {
        return !!this.view;
    }

    get statusLabel() {
        return this.view ? REVIEW_STATUS_LABELS[this.view.reviewStatus] || this.view.reviewStatus : '';
    }

    get ratingOptions() {
        const options = [];
        const max = this.view && this.view.cycle ? this.view.cycle.scaleMax || 5 : 5;
        for (let i = 1; i <= max; i++) {
            options.push({ label: String(i), value: String(i) });
        }
        return options;
    }

    get goalRows() {
        if (!this.view) {
            return [];
        }
        return this.view.goals.map((g) => ({
            ...g,
            weightLabel: g.weight + '%',
            scoreLabel: g.selfScore === null || g.selfScore === undefined ? 'sem nota' : 'nota ' + g.selfScore
        }));
    }

    get hasGoals() {
        return !!this.view && this.view.goals.length > 0;
    }

    get hasSelf() {
        return !!(this.view && this.view.selfAssessment);
    }

    get selfSubmitted() {
        return this.hasSelf && this.view.selfAssessment.submitted;
    }

    get readOnly() {
        return !this.view || !this.view.canEdit;
    }

    get hasFinalRating() {
        return !!this.view && this.view.finalRating !== null && this.view.finalRating !== undefined;
    }

    get hasCalibration() {
        return !!this.view && this.view.calibratedRating !== null && this.view.calibratedRating !== undefined;
    }

    get submitDisabled() {
        return this.busy || !this.rating || !this.comments || !this.comments.trim();
    }

    handleField(event) {
        this[event.target.dataset.field] = event.detail.value;
    }

    handleSaveDraft() {
        return this.save(false, 'Rascunho salvo', 'A avaliação segue em andamento.');
    }

    handleSubmit() {
        return this.save(true, 'Avaliação enviada', 'Depois do envio ela não pode mais ser alterada.');
    }

    async save(submitReview, title, message) {
        this.busy = true;
        try {
            this.apply(
                await saveReview({
                    reviewId: this._reviewId,
                    rating: this.rating ? Number(this.rating) : null,
                    comments: this.comments,
                    submitReview
                })
            );
            this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
            this.dispatchEvent(new CustomEvent('saved', { detail: { reviewId: this._reviewId, submitted: submitReview } }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível salvar', message: errorMessage(e), variant: 'error' }));
        } finally {
            this.busy = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}
