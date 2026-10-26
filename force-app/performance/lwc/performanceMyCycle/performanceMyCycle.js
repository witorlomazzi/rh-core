import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyCycle from '@salesforce/apex/PerformanceReviewController.getMyCycle';
import saveGoal from '@salesforce/apex/GoalController.saveGoal';
import cancelGoal from '@salesforce/apex/GoalController.cancelGoal';
import setScore from '@salesforce/apex/GoalController.setScore';
import saveDraft from '@salesforce/apex/SelfAssessmentController.saveDraft';
import submitAssessment from '@salesforce/apex/SelfAssessmentController.submitAssessment';

const STATUS_LABELS = {
    Planejado: 'Planejado',
    Autoavaliacao: 'Autoavaliação',
    Avaliacao_Gestor: 'Avaliação do gestor',
    Calibracao: 'Calibração',
    Concluido: 'Concluído'
};

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

function scaleOptions(max) {
    const options = [];
    for (let i = 1; i <= (max || 5); i++) {
        options.push({ label: String(i), value: String(i) });
    }
    return options;
}

export default class PerformanceMyCycle extends LightningElement {
    view;
    loading = true;
    error;
    busy = false;
    newName = '';
    newTarget = '';
    newDescription = '';
    newWeight;
    rating;
    strengths = '';
    improvements = '';

    connectedCallback() {
        this.load();
    }

    async load(cycleId) {
        this.loading = true;
        this.error = undefined;
        try {
            this.view = await getMyCycle({ cycleId: cycleId || null });
            const sa = this.view.selfAssessment;
            if (sa) {
                this.rating = sa.rating === null || sa.rating === undefined ? undefined : String(sa.rating);
                this.strengths = sa.strengths || '';
                this.improvements = sa.improvements || '';
            }
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    // ------------------------------------------------------------------------------------- estado derivado

    get hasCycle() {
        return !!(this.view && this.view.cycle);
    }

    get noEmployee() {
        return !this.loading && !!this.view && !this.view.hasEmployee;
    }

    get noCycle() {
        return !this.loading && !!this.view && this.view.hasEmployee && !this.view.cycle;
    }

    get statusLabel() {
        return this.hasCycle ? STATUS_LABELS[this.view.cycle.status] || this.view.cycle.status : '';
    }

    get cycleOptions() {
        return (this.view ? this.view.cycles : []).map((c) => ({ label: c.name, value: c.id }));
    }

    get showCyclePicker() {
        return !!this.view && this.view.cycles.length > 1;
    }

    get ratingOptions() {
        return scaleOptions(this.hasCycle ? this.view.cycle.scaleMax : 5);
    }

    get goalRows() {
        if (!this.view) {
            return [];
        }
        return this.view.goals.map((g) => ({
            ...g,
            weightLabel: g.weight + '%',
            cssClass: g.status === 'Cancelada' ? 'goal-item goal-cancelled' : 'goal-item',
            scoreValue: g.selfScore === null || g.selfScore === undefined ? undefined : String(g.selfScore),
            canScore: this.view.canEditGoals && g.status === 'Ativa'
        }));
    }

    get weightSum() {
        return this.view ? this.view.weightSum : 0;
    }

    get weightOk() {
        return this.weightSum === 100;
    }

    get weightMessage() {
        return this.weightOk
            ? 'Os pesos das metas somam 100%.'
            : 'Os pesos das metas ativas somam ' + this.weightSum + '%. É preciso fechar 100% para enviar a autoavaliação.';
    }

    get weightClass() {
        return this.weightOk ? 'slds-text-color_success weight-ok' : 'slds-text-color_error weight-warning';
    }

    get submitted() {
        return !!(this.view && this.view.selfAssessment && this.view.selfAssessment.submitted);
    }

    get selfReadOnly() {
        return !this.view || !this.view.canEditSelf;
    }

    get submitDisabled() {
        return this.busy || !this.weightOk || !this.rating;
    }

    get dueLabel() {
        const due = this.hasCycle ? this.view.cycle.selfDue : null;
        return due ? 'Prazo da autoavaliação: ' + due : '';
    }

    get released() {
        return this.view ? this.view.released : null;
    }

    // ------------------------------------------------------------------------------------------- handlers

    handleCycleChange(event) {
        this.load(event.detail.value);
    }

    handleField(event) {
        this[event.target.dataset.field] = event.detail.value;
    }

    async run(action, successTitle, successMessage) {
        this.busy = true;
        try {
            await action();
            if (successTitle) {
                this.dispatchEvent(new ShowToastEvent({ title: successTitle, message: successMessage, variant: 'success' }));
            }
            await this.load(this.view && this.view.cycle ? this.view.cycle.id : null);
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível salvar', message: errorMessage(e), variant: 'error' }));
        } finally {
            this.busy = false;
        }
    }

    handleAddGoal() {
        return this.run(
            async () => {
                await saveGoal({
                    goalId: null,
                    cycleId: this.view.cycle.id,
                    name: this.newName,
                    target: this.newTarget,
                    description: this.newDescription,
                    weight: Number(this.newWeight),
                    selfScore: null
                });
                this.newName = '';
                this.newTarget = '';
                this.newDescription = '';
                this.newWeight = undefined;
            },
            'Meta registrada',
            'A meta entrou no ciclo.'
        );
    }

    handleCancelGoal(event) {
        const goalId = event.currentTarget.dataset.id;
        return this.run(() => cancelGoal({ goalId }), 'Meta removida', 'A meta deixou de contar nos pesos.');
    }

    handleScore(event) {
        const goalId = event.target.dataset.id;
        const selfScore = Number(event.detail.value);
        return this.run(() => setScore({ goalId, selfScore }), null, null);
    }

    handleSaveDraft() {
        return this.run(() => saveDraft(this.selfPayload()), 'Rascunho salvo', 'Você pode continuar depois.');
    }

    handleSubmit() {
        return this.run(
            () => submitAssessment(this.selfPayload()),
            'Autoavaliação enviada',
            'Depois do envio ela não pode mais ser alterada.'
        );
    }

    selfPayload() {
        return {
            assessmentId: this.view.selfAssessment.id,
            rating: this.rating ? Number(this.rating) : null,
            strengths: this.strengths,
            improvements: this.improvements
        };
    }
}
