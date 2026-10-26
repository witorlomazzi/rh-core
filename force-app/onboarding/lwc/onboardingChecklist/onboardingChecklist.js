import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChecklist from '@salesforce/apex/OnboardingController.getChecklist';
import setTaskDone from '@salesforce/apex/OnboardingController.setTaskDone';
import syncPlan from '@salesforce/apex/OnboardingController.syncPlan';

const ROLE_ICONS = {
    RH: 'utility:user',
    Gestor: 'utility:groups',
    TI: 'utility:settings',
    Colaborador: 'utility:adduser'
};

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

function formatDate(iso) {
    if (!iso) {
        return 'sem prazo';
    }
    const [year, month, day] = iso.split('-');
    return `${day}/${month}/${year}`;
}

export default class OnboardingChecklist extends LightningElement {
    /** Colaborador ou plano de onboarding. Sem valor (Meu RH), mostra o plano do usuario atual. */
    @api recordId;

    view;
    loading = true;
    error;
    busyTaskId;
    syncing = false;

    connectedCallback() {
        this.load(false);
    }

    async load(silent) {
        if (!silent) {
            this.loading = true;
        }
        try {
            this.view = await getChecklist({ recordId: this.recordId || null });
            this.error = undefined;
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get showEmpty() {
        return !this.loading && !this.error && Boolean(this.view) && !this.view.hasPlan;
    }

    get showChecklist() {
        return !this.loading && !this.error && Boolean(this.view) && this.view.hasPlan;
    }

    get title() {
        return this.view && this.view.employeeName ? `Onboarding de ${this.view.employeeName}` : 'Onboarding';
    }

    get startText() {
        return this.view && this.view.startDate ? `Início em ${formatDate(this.view.startDate)}` : 'Data de início não definida';
    }

    get progressText() {
        return `${this.view.resolved} de ${this.view.total} tarefas resolvidas (${this.view.progressPercent}%)`;
    }

    get hasOverdue() {
        return this.view.overdueCount > 0;
    }

    get overdueText() {
        const n = this.view.overdueCount;
        return n === 1 ? '1 tarefa atrasada' : `${n} tarefas atrasadas`;
    }

    get statusBadgeClass() {
        const map = {
            Concluido: 'slds-badge slds-theme_success status-badge',
            Em_Andamento: 'slds-badge slds-badge_inverse status-badge',
            Nao_Iniciado: 'slds-badge status-badge'
        };
        return map[this.view.planStatus] || 'slds-badge status-badge';
    }

    get showSync() {
        return this.view.isHr && this.view.datesOutOfSync;
    }

    get groups() {
        return this.view.groups.map((g) => ({
            ...g,
            icon: ROLE_ICONS[g.role] || 'utility:task',
            summary: `${g.resolved} de ${g.total}`,
            tasks: g.tasks.map((t) => ({
                ...t,
                dueText: formatDate(t.dueDate),
                dueClass: t.overdue ? 'slds-text-color_error task-due task-overdue' : 'slds-text-color_weak task-due',
                rowClass: t.done ? 'task-row task-done slds-p-vertical_x-small' : 'task-row slds-p-vertical_x-small',
                assigneeText: t.assignedToName ? t.assignedToName : 'Sem responsável',
                disabled: !t.canChange || this.busyTaskId === t.id || t.status === 'Nao_Aplicavel',
                notApplicable: t.status === 'Nao_Aplicavel'
            }))
        }));
    }

    async handleToggle(event) {
        const taskId = event.target.dataset.id;
        const done = event.detail.checked;
        this.busyTaskId = taskId;
        try {
            await setTaskDone({ taskId, done });
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível alterar a tarefa', message: errorMessage(e), variant: 'error' }));
        }
        this.busyTaskId = undefined;
        await this.load(true);
    }

    async handleSync() {
        this.syncing = true;
        try {
            await syncPlan({ employeeId: this.view.employeeId });
            this.dispatchEvent(new ShowToastEvent({ title: 'Prazos e responsáveis atualizados', variant: 'success' }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Não foi possível atualizar', message: errorMessage(e), variant: 'error' }));
        }
        this.syncing = false;
        await this.load(true);
    }
}
