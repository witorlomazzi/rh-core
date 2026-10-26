import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPending from '@salesforce/apex/ApprovalController.getPending';
import decide from '@salesforce/apex/ApprovalController.decide';

const TYPE_LABELS = { Leave: 'Férias', Promotion: 'Promoção' };
const APPROVER_LABELS = {
    Direct_Manager: 'Gestor direto',
    Second_Level_Manager: 'Gestor de segundo nível',
    HR_Team: 'Equipe de RH'
};

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

export default class CoreApprovalInbox extends NavigationMixin(LightningElement) {
    items = [];
    loading = true;
    error;
    rejectingId;
    comment = '';
    commentError;
    busyId;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            const rows = await getPending();
            this.items = rows.map((r) => ({
                ...r,
                typeLabel: TYPE_LABELS[r.requestType] || r.requestType,
                approverLabel: APPROVER_LABELS[r.approverType] || r.approverType,
                title: r.requestName ? r.requestName : r.stepName,
                subtitle: r.employeeName ? r.employeeName : 'Solicitação sem resumo disponível'
            }));
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get viewItems() {
        return this.items.map((i) => ({
            ...i,
            isRejecting: i.stepId === this.rejectingId,
            isBusy: i.stepId === this.busyId,
            stepLabel: `Etapa ${i.stepOrder}: ${i.approverLabel}`
        }));
    }

    get isEmpty() {
        return !this.loading && !this.error && this.items.length === 0;
    }

    get countLabel() {
        return this.items.length === 1 ? '1 pendente' : `${this.items.length} pendentes`;
    }

    handleApprove(event) {
        this.submitDecision(event.currentTarget.dataset.id, true, null);
    }

    handleStartReject(event) {
        this.rejectingId = event.currentTarget.dataset.id;
        this.comment = '';
        this.commentError = undefined;
    }

    handleCancelReject() {
        this.rejectingId = undefined;
        this.commentError = undefined;
    }

    handleCommentChange(event) {
        this.comment = event.target.value;
    }

    handleConfirmReject(event) {
        if (!this.comment || !this.comment.trim()) {
            this.commentError = 'Informe um comentário para rejeitar a solicitação.';
            return;
        }
        this.submitDecision(event.currentTarget.dataset.id, false, this.comment.trim());
    }

    async submitDecision(stepId, approve, comments) {
        this.busyId = stepId;
        try {
            await decide({ stepId, approve, comments });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: approve ? 'Aprovado' : 'Rejeitado',
                    message: approve ? 'A decisão foi registrada.' : 'A solicitação foi rejeitada.',
                    variant: 'success'
                })
            );
            this.rejectingId = undefined;
            await this.load();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível decidir', message: errorMessage(e), variant: 'error' }));
        } finally {
            this.busyId = undefined;
        }
    }

    handleOpen(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    handleRefresh() {
        this.load();
    }
}
