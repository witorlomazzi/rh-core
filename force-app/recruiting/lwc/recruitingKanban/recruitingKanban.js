import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOpenings from '@salesforce/apex/RecruitingKanbanController.getOpenings';
import getBoard from '@salesforce/apex/RecruitingKanbanController.getBoard';
import moveCard from '@salesforce/apex/RecruitingKanbanController.moveCard';
import rateCard from '@salesforce/apex/RecruitingKanbanController.rateCard';

const RATE_ACTION = '__rate__';

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

export default class RecruitingKanban extends LightningElement {
    /** Quando a pagina e de uma vaga, o kanban abre direto nela e esconde o seletor. */
    @api recordId;

    openings = [];
    selectedOpeningId;
    board;
    loading = true;
    error;
    busyId;
    draggingId;
    dragOverStage;
    announcement = '';

    // Modal de motivo e nota
    modal;
    modalReason = '';
    modalScore = '';
    modalError;
    modalFocusPending = false;

    connectedCallback() {
        this.init();
    }

    async init() {
        this.loading = true;
        this.error = undefined;
        try {
            if (this.recordId) {
                this.selectedOpeningId = this.recordId;
            } else {
                this.openings = await getOpenings();
                if (this.openings.length) {
                    this.selectedOpeningId = this.openings[0].id;
                }
            }
            if (this.selectedOpeningId) {
                await this.loadBoard();
            }
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    async loadBoard() {
        this.loading = true;
        this.error = undefined;
        try {
            this.board = await getBoard({ openingId: this.selectedOpeningId });
        } catch (e) {
            this.board = undefined;
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    // ---------------------------------------------------------------------------------------------

    get showPicker() {
        return !this.recordId;
    }

    get openingOptions() {
        return this.openings.map((o) => ({
            label: `${o.name} (${o.applicationsCount})`,
            value: o.id
        }));
    }

    get hasOpenings() {
        return this.showPicker ? this.openings.length > 0 : true;
    }

    get isEmptyList() {
        return !this.loading && !this.error && this.showPicker && this.openings.length === 0;
    }

    get hasBoard() {
        return !!this.board;
    }

    get boardTitle() {
        return this.board ? this.board.openingName : 'Funil de recrutamento';
    }

    get stageMap() {
        const map = {};
        if (this.board) {
            this.board.stages.forEach((s) => {
                map[s.value] = s;
            });
        }
        return map;
    }

    get columns() {
        if (!this.board) {
            return [];
        }
        const stages = this.stageMap;
        return this.board.stages.map((stage) => {
            const cards = this.board.cards
                .filter((c) => c.stage === stage.value)
                .map((c) => this.decorateCard(c, stage, stages));
            const dropAllowed = this.draggingId ? this.canDrop(this.draggingId, stage.value) : false;
            const isOver = this.dragOverStage === stage.value;
            return {
                value: stage.value,
                label: stage.label,
                count: cards.length,
                countLabel: `${cards.length} ${cards.length === 1 ? 'candidatura' : 'candidaturas'}`,
                cards,
                isEmpty: cards.length === 0,
                barStyle: `background-color: ${stage.color || '#706e6b'}`,
                columnClass:
                    'column slds-col' +
                    (isOver && dropAllowed ? ' column-over' : '') +
                    (this.draggingId && !dropAllowed ? ' column-blocked' : ''),
                ariaLabel: `Etapa ${stage.label}, ${cards.length} candidaturas`
            };
        });
    }

    decorateCard(card, stage, stages) {
        const moves = stage.allowedNext.map((v) => ({
            value: v,
            label: `Mover para ${stages[v] ? stages[v].label : v}`
        }));
        const hasScore = card.score !== null && card.score !== undefined;
        return {
            ...card,
            scoreLabel: hasScore ? `Nota ${card.score}` : 'Sem nota',
            scoreClass: 'slds-badge ' + (hasScore ? 'slds-theme_info' : ''),
            daysLabel: card.daysInStage === 1 ? '1 dia na etapa' : `${card.daysInStage} dias na etapa`,
            movable: !stage.isTerminal,
            draggable: !stage.isTerminal && this.busyId !== card.id,
            isBusy: this.busyId === card.id,
            cardClass: 'slds-box slds-box_x-small card' + (this.busyId === card.id ? ' card-busy' : ''),
            menuItems: [...moves, { value: RATE_ACTION, label: 'Dar nota' }],
            menuAlt: `Ações de ${card.candidateName || card.applicationNumber}`,
            reasonLabel: card.rejectionReason ? this.reasonLabel(card.rejectionReason) : ''
        };
    }

    reasonLabel(value) {
        const found = (this.board.rejectionReasons || []).find((r) => r.value === value);
        return found ? found.label : value;
    }

    // ---------------------------------------------------------------------------------------------
    // Seletor de vaga

    handleOpeningChange(event) {
        this.selectedOpeningId = event.detail.value;
        this.loadBoard();
    }

    handleRefresh() {
        if (this.selectedOpeningId) {
            this.loadBoard();
        } else {
            this.init();
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Arrastar e soltar

    handleDragStart(event) {
        const id = event.currentTarget.dataset.id;
        this.draggingId = id;
        if (event.dataTransfer) {
            event.dataTransfer.setData('text/plain', id);
            event.dataTransfer.effectAllowed = 'move';
        }
    }

    handleDragEnd() {
        this.draggingId = undefined;
        this.dragOverStage = undefined;
    }

    handleDragOver(event) {
        const stage = event.currentTarget.dataset.stage;
        if (this.draggingId && this.canDrop(this.draggingId, stage)) {
            event.preventDefault();
            if (event.dataTransfer) {
                event.dataTransfer.dropEffect = 'move';
            }
        }
        if (this.dragOverStage !== stage) {
            this.dragOverStage = stage;
        }
    }

    handleDragLeave(event) {
        if (this.dragOverStage === event.currentTarget.dataset.stage) {
            this.dragOverStage = undefined;
        }
    }

    handleDrop(event) {
        event.preventDefault();
        const stage = event.currentTarget.dataset.stage;
        const id = (event.dataTransfer && event.dataTransfer.getData('text/plain')) || this.draggingId;
        this.draggingId = undefined;
        this.dragOverStage = undefined;
        if (id && stage) {
            this.requestMove(id, stage);
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Menu "Mover para" (versao acessivel, sem arrastar)

    handleMenuSelect(event) {
        const id = event.currentTarget.dataset.id;
        const value = event.detail.value;
        if (value === RATE_ACTION) {
            this.openRateModal(id);
        } else {
            this.requestMove(id, value);
        }
    }

    // ---------------------------------------------------------------------------------------------

    findCard(id) {
        return this.board ? this.board.cards.find((c) => c.id === id) : undefined;
    }

    canDrop(id, toStage) {
        const card = this.findCard(id);
        const from = card ? this.stageMap[card.stage] : undefined;
        return !!from && from.allowedNext.includes(toStage);
    }

    /** Valida no cliente apenas para poupar a viagem; o servidor decide (C1 e C2). */
    requestMove(id, toStage) {
        const card = this.findCard(id);
        if (!card || card.stage === toStage || this.busyId) {
            return;
        }
        const stages = this.stageMap;
        const from = stages[card.stage];
        const target = stages[toStage];
        if (!from || !target || !from.allowedNext.includes(toStage)) {
            const message = `Mudança de etapa não permitida: de ${from ? from.label : card.stage} para ${target ? target.label : toStage}.`;
            this.error = message;
            this.announcement = message;
            this.toast('Mudança não permitida', message, 'error');
            return;
        }
        this.error = undefined;
        const needsReason = target.requiresRejectionReason && !card.rejectionReason;
        const needsScore = target.requiresScore && (card.score === null || card.score === undefined);
        if (needsReason || needsScore) {
            this.modal = {
                mode: 'move',
                id,
                toStage,
                title: `Mover para ${target.label}`,
                candidateName: card.candidateName,
                needsReason,
                needsScore,
                confirmLabel: 'Mover'
            };
            this.modalReason = '';
            this.modalScore = card.score === null || card.score === undefined ? '' : String(card.score);
            this.modalError = undefined;
            this.modalFocusPending = true;
            return;
        }
        this.executeMove(id, toStage, card.rejectionReason, card.score);
    }

    openRateModal(id) {
        const card = this.findCard(id);
        if (!card) {
            return;
        }
        this.modal = {
            mode: 'rate',
            id,
            title: 'Dar nota',
            candidateName: card.candidateName,
            needsReason: false,
            needsScore: true,
            confirmLabel: 'Salvar nota'
        };
        this.modalScore = card.score === null || card.score === undefined ? '' : String(card.score);
        this.modalError = undefined;
        this.modalFocusPending = true;
    }

    async executeMove(id, toStage, rejectionReason, score) {
        this.busyId = id;
        this.error = undefined;
        try {
            const updated = await moveCard({
                applicationId: id,
                toStage,
                rejectionReason: rejectionReason || null,
                score: score === null || score === undefined || score === '' ? null : Number(score)
            });
            this.replaceCard(updated);
            const stage = this.stageMap[updated.stage];
            const message = `${updated.candidateName || updated.applicationNumber} movido para ${stage ? stage.label : updated.stage}.`;
            this.announcement = message;
            this.toast('Candidatura movida', message, 'success');
            this.modal = undefined;
        } catch (e) {
            const message = errorMessage(e);
            this.error = message;
            this.modalError = this.modal ? message : undefined;
            this.announcement = message;
            this.toast('Não foi possível mover', message, 'error');
        } finally {
            this.busyId = undefined;
        }
    }

    async executeRate(id, score) {
        this.busyId = id;
        try {
            const updated = await rateCard({ applicationId: id, score: Number(score) });
            this.replaceCard(updated);
            this.announcement = `Nota ${updated.score} registrada.`;
            this.toast('Nota registrada', `Nota ${updated.score} para ${updated.candidateName || updated.applicationNumber}.`, 'success');
            this.modal = undefined;
        } catch (e) {
            const message = errorMessage(e);
            this.modalError = message;
            this.toast('Não foi possível salvar a nota', message, 'error');
        } finally {
            this.busyId = undefined;
        }
    }

    replaceCard(updated) {
        this.board = {
            ...this.board,
            cards: this.board.cards.map((c) => (c.id === updated.id ? updated : c))
        };
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ---------------------------------------------------------------------------------------------
    // Modal de motivo e nota

    get hasModal() {
        return !!this.modal;
    }

    get modalTitle() {
        return this.modal ? this.modal.title : '';
    }

    get modalSubtitle() {
        return this.modal && this.modal.candidateName ? this.modal.candidateName : '';
    }

    get modalNeedsReason() {
        return !!this.modal && this.modal.needsReason;
    }

    get modalNeedsScore() {
        return !!this.modal && this.modal.needsScore;
    }

    get modalConfirmLabel() {
        return this.modal ? this.modal.confirmLabel : '';
    }

    get reasonOptions() {
        return this.board ? this.board.rejectionReasons || [] : [];
    }

    handleReasonChange(event) {
        this.modalReason = event.detail.value;
    }

    handleScoreChange(event) {
        this.modalScore = event.detail.value;
    }

    handleModalKeydown(event) {
        if (event.key === 'Escape') {
            this.handleCancelModal();
        }
    }

    handleCancelModal() {
        this.modal = undefined;
        this.modalError = undefined;
    }

    handleConfirmModal() {
        const m = this.modal;
        if (!m) {
            return;
        }
        if (m.needsReason && !this.modalReason) {
            this.modalError = 'Informe o motivo da reprovação.';
            return;
        }
        if (m.needsScore) {
            const score = this.modalScore === '' ? NaN : Number(this.modalScore);
            if (Number.isNaN(score) || score < 0 || score > 5) {
                this.modalError = 'Informe uma nota de 0 a 5.';
                return;
            }
        }
        this.modalError = undefined;
        if (m.mode === 'rate') {
            this.executeRate(m.id, this.modalScore);
        } else {
            this.executeMove(m.id, m.toStage, this.modalReason || null, m.needsScore ? this.modalScore : null);
        }
    }

    renderedCallback() {
        if (this.modalFocusPending && this.modal) {
            const target = this.template.querySelector('.modal-focus');
            if (target && typeof target.focus === 'function') {
                target.focus();
                this.modalFocusPending = false;
            }
        }
    }
}
