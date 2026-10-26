import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingForHr from '@salesforce/apex/PromotionRequestController.getPendingForHr';
import getHrReview from '@salesforce/apex/PromotionRequestController.getHrReview';
import hrDecide from '@salesforce/apex/PromotionRequestController.hrDecide';

const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const percent = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

function formatMoney(value) {
    return value === null || value === undefined ? 'não informado' : currency.format(value);
}

function formatDate(iso) {
    if (!iso) {
        return '';
    }
    const [year, month, day] = iso.split('-');
    return `${day}/${month}/${year}`;
}

export default class PromotionHrReview extends LightningElement {
    @api recordId;

    pending = [];
    review;
    loading = true;
    error;
    busy = false;
    salaryText = '';
    comment = '';
    decisionError;

    connectedCallback() {
        if (this.recordId) {
            this.loadReview(this.recordId);
        } else {
            this.loadPending();
        }
    }

    async loadPending() {
        this.loading = true;
        this.error = undefined;
        this.review = undefined;
        try {
            this.pending = await getPendingForHr();
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    async loadReview(requestId) {
        this.loading = true;
        this.error = undefined;
        this.decisionError = undefined;
        try {
            this.review = await getHrReview({ requestId });
            this.salaryText =
                this.review.proposedSalary === null || this.review.proposedSalary === undefined ? '' : String(this.review.proposedSalary);
            this.comment = '';
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    // ------------------------------------------------------------------------------------------ lista

    get showList() {
        return !this.loading && !this.error && !this.review && !this.recordId;
    }

    get isListEmpty() {
        return this.showList && this.pending.length === 0;
    }

    get pendingRows() {
        return this.pending.map((p) => ({
            ...p,
            title: p.requestName || p.stepName,
            subtitle: p.employeeName || 'Solicitação sem resumo disponível'
        }));
    }

    handleSelect(event) {
        this.loadReview(event.currentTarget.dataset.id);
    }

    handleBack() {
        this.loadPending();
    }

    get canGoBack() {
        return !this.recordId;
    }

    // ------------------------------------------------------------------------------------------ revisao

    get showReview() {
        return !this.loading && !this.error && Boolean(this.review);
    }

    get reviewView() {
        const r = this.review;
        return {
            ...r,
            effectiveDateText: formatDate(r.effectiveDate),
            currentSalaryText: formatMoney(r.currentSalary),
            bandText: this.hasBand ? `${formatMoney(r.bandMin)} a ${formatMoney(r.bandMax)}` : 'Cargo sem faixa salarial cadastrada'
        };
    }

    get hasBand() {
        return Boolean(this.review) && (this.review.bandMin !== null && this.review.bandMin !== undefined);
    }

    get salary() {
        const value = parseFloat(this.salaryText);
        return Number.isNaN(value) ? null : value;
    }

    /** Percentual de aumento sobre o salario atual, ou texto vazio sem os dois valores. */
    get increaseText() {
        const current = this.review ? this.review.currentSalary : null;
        if (this.salary === null || !current) {
            return '';
        }
        const value = ((this.salary - current) / current) * 100;
        return `${value > 0 ? '+' : ''}${percent.format(value)} %`;
    }

    /** Dentro, Abaixo, Acima, SemFaixa ou vazio (sem salario informado). */
    get bandStatus() {
        if (!this.review) {
            return '';
        }
        if (!this.hasBand) {
            return 'SemFaixa';
        }
        if (this.salary === null) {
            return '';
        }
        if (this.salary < this.review.bandMin) {
            return 'Abaixo';
        }
        if (this.salary > this.review.bandMax) {
            return 'Acima';
        }
        return 'Dentro';
    }

    get outsideBand() {
        return this.bandStatus === 'Abaixo' || this.bandStatus === 'Acima';
    }

    get bandBadge() {
        const map = {
            Dentro: { label: 'Dentro da faixa', css: 'slds-badge slds-theme_success band-badge' },
            Abaixo: { label: 'Abaixo da faixa', css: 'slds-badge slds-theme_warning band-badge' },
            Acima: { label: 'Acima da faixa', css: 'slds-badge slds-theme_warning band-badge' },
            SemFaixa: { label: 'Cargo sem faixa', css: 'slds-badge band-badge' }
        };
        return map[this.bandStatus] || null;
    }

    get commentLabel() {
        return this.outsideBand ? 'Justificativa (obrigatória fora da faixa)' : 'Comentário';
    }

    get decisionDisabled() {
        return this.busy || !this.review || !this.review.canDecide;
    }

    handleSalaryChange(event) {
        this.salaryText = event.detail.value === null || event.detail.value === undefined ? '' : String(event.detail.value);
    }

    handleCommentChange(event) {
        this.comment = event.detail.value;
    }

    handleApprove() {
        if (this.salary === null || this.salary <= 0) {
            this.decisionError = 'Informe o salário proposto antes de aprovar.';
            return;
        }
        if (this.outsideBand && !this.comment.trim()) {
            this.decisionError = 'O salário proposto está fora da faixa do cargo: informe uma justificativa na decisão.';
            return;
        }
        this.submitDecision(true);
    }

    handleReject() {
        if (!this.comment.trim()) {
            this.decisionError = 'Informe um comentário para rejeitar a solicitação.';
            return;
        }
        this.submitDecision(false);
    }

    async submitDecision(approve) {
        this.busy = true;
        this.decisionError = undefined;
        try {
            await hrDecide({
                requestId: this.review.requestId,
                proposedSalary: approve ? this.salary : null,
                approve,
                comments: this.comment.trim() ? this.comment.trim() : null
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: approve ? 'Promoção aprovada' : 'Promoção rejeitada',
                    message: approve ? 'A decisão do RH foi registrada.' : 'A solicitação foi rejeitada.',
                    variant: 'success'
                })
            );
            this.dispatchEvent(new CustomEvent('decided', { detail: { requestId: this.review.requestId, approved: approve } }));
            if (this.recordId) {
                await this.loadReview(this.recordId);
            } else {
                await this.loadPending();
            }
        } catch (e) {
            this.decisionError = errorMessage(e);
        } finally {
            this.busy = false;
        }
    }
}
