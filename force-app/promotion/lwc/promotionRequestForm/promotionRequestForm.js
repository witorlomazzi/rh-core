import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTeam from '@salesforce/apex/PromotionRequestController.getTeam';
import getFormContext from '@salesforce/apex/PromotionRequestController.getFormContext';
import submitRequest from '@salesforce/apex/PromotionRequestController.submitRequest';

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

function todayIso() {
    const d = new Date();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${month}-${day}`;
}

export default class PromotionRequestForm extends LightningElement {
    team = [];
    context;
    loading = true;
    loadingContext = false;
    submitting = false;
    loadError;
    formError;
    employeeId;
    positionId;
    effectiveDate;
    justification = '';

    connectedCallback() {
        this.loadTeam();
    }

    async loadTeam() {
        this.loading = true;
        this.loadError = undefined;
        try {
            this.team = await getTeam();
        } catch (e) {
            this.loadError = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get hasTeam() {
        return this.team.length > 0;
    }

    get showEmptyTeam() {
        return !this.loading && !this.loadError && this.team.length === 0;
    }

    get showForm() {
        return !this.loading && !this.loadError && this.team.length > 0;
    }

    get employeeOptions() {
        return this.team.map((m) => ({
            value: m.id,
            label: m.positionName ? `${m.name} (${m.positionName})` : `${m.name} (sem cargo)`
        }));
    }

    get positionOptions() {
        if (!this.context) {
            return [];
        }
        return this.context.options.map((o) => ({
            value: o.value,
            label: o.isNext ? `${o.label} (próximo da trilha)` : o.label
        }));
    }

    get noEmployee() {
        return !this.employeeId || this.loadingContext || !this.context;
    }

    get trailHint() {
        if (!this.context) {
            return undefined;
        }
        return this.context.nextPositionName
            ? `Cargo atual: ${this.context.currentPositionName || 'não informado'}. Próximo da trilha: ${this.context.nextPositionName}.`
            : `Cargo atual: ${this.context.currentPositionName || 'não informado'}. Este cargo não tem próximo passo definido na trilha.`;
    }

    get offTrackWarning() {
        return Boolean(this.positionId && this.context && this.context.nextPositionId !== this.positionId);
    }

    get minDate() {
        return todayIso();
    }

    get submitDisabled() {
        return this.submitting || this.noEmployee;
    }

    async handleEmployeeChange(event) {
        this.employeeId = event.detail.value;
        this.positionId = undefined;
        this.context = undefined;
        this.formError = undefined;
        this.loadingContext = true;
        try {
            this.context = await getFormContext({ employeeId: this.employeeId });
        } catch (e) {
            this.formError = errorMessage(e);
        } finally {
            this.loadingContext = false;
        }
    }

    handlePositionChange(event) {
        this.positionId = event.detail.value;
    }

    handleDateChange(event) {
        this.effectiveDate = event.detail.value;
    }

    handleJustificationChange(event) {
        this.justification = event.detail.value;
    }

    validate() {
        if (!this.employeeId) {
            return 'Escolha o colaborador.';
        }
        if (!this.positionId) {
            return 'Escolha o novo cargo.';
        }
        if (!this.effectiveDate) {
            return 'Informe a data de efetivação.';
        }
        if (this.effectiveDate < todayIso()) {
            return 'A data de efetivação não pode estar no passado.';
        }
        if (!this.justification || !this.justification.trim()) {
            return 'Informe a justificativa da promoção.';
        }
        return undefined;
    }

    async handleSubmit() {
        this.formError = this.validate();
        if (this.formError) {
            return;
        }
        this.submitting = true;
        try {
            const result = await submitRequest({
                employeeId: this.employeeId,
                proposedPositionId: this.positionId,
                effectiveDate: this.effectiveDate,
                justification: this.justification.trim()
            });
            const base = `Solicitação ${result.requestName || ''} enviada para aprovação.`.replace('  ', ' ');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Solicitação enviada',
                    message: result.warning ? `${base} ${result.warning}` : base,
                    variant: result.warning ? 'warning' : 'success'
                })
            );
            this.dispatchEvent(new CustomEvent('submitted', { detail: { requestId: result.requestId } }));
            this.reset();
        } catch (e) {
            this.formError = errorMessage(e);
        } finally {
            this.submitting = false;
        }
    }

    reset() {
        this.employeeId = undefined;
        this.positionId = undefined;
        this.context = undefined;
        this.effectiveDate = undefined;
        this.justification = '';
    }
}
