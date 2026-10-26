import { createElement } from 'lwc';
import OnboardingChecklist from 'c/onboardingChecklist';
import getChecklist from '@salesforce/apex/OnboardingController.getChecklist';
import setTaskDone from '@salesforce/apex/OnboardingController.setTaskDone';
import syncPlan from '@salesforce/apex/OnboardingController.syncPlan';

const ShowToastEventName = 'lightning__showtoast';

jest.mock('@salesforce/apex/OnboardingController.getChecklist', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OnboardingController.setTaskDone', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OnboardingController.syncPlan', () => ({ default: jest.fn() }), { virtual: true });

function task(overrides) {
    return {
        id: 't1',
        title: 'Enviar documentos admissionais',
        description: 'Enviar ao RH os documentos pessoais.',
        dueDate: '2030-01-05',
        status: 'Pendente',
        statusLabel: 'Pendente',
        done: false,
        overdue: false,
        assignedToId: 'u1',
        assignedToName: 'Ana Souza',
        canChange: true,
        ...overrides
    };
}

function view(overrides) {
    return {
        hasPlan: true,
        planId: 'p1',
        planName: 'ON-000001',
        employeeId: 'e1',
        employeeName: 'Bruno Lima',
        employeeStatus: 'Pre_Admissao',
        planStatus: 'Em_Andamento',
        planStatusLabel: 'Em andamento',
        startDate: '2030-01-15',
        total: 3,
        resolved: 1,
        progressPercent: 33,
        overdueCount: 1,
        isHr: false,
        datesOutOfSync: false,
        groups: [
            {
                role: 'Colaborador',
                roleLabel: 'Colaborador',
                total: 1,
                resolved: 1,
                tasks: [task({ id: 't1', status: 'Concluida', statusLabel: 'Concluída', done: true })]
            },
            {
                role: 'Gestor',
                roleLabel: 'Gestor',
                total: 2,
                resolved: 0,
                tasks: [
                    task({ id: 't2', title: 'Reunião de boas-vindas', dueDate: '2020-02-01', overdue: true }),
                    task({ id: 't3', title: 'Plano de 30 dias definido', canChange: false, assignedToName: null })
                ]
            }
        ],
        ...overrides
    };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function mount(recordId) {
    const el = createElement('c-onboarding-checklist', { is: OnboardingChecklist });
    if (recordId) {
        el.recordId = recordId;
    }
    document.body.appendChild(el);
    await flush();
    return el;
}

describe('c-onboarding-checklist', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra tarefas agrupadas por responsavel, progresso e atraso', async () => {
        getChecklist.mockResolvedValue(view());
        const el = await mount('e1');

        expect(getChecklist).toHaveBeenCalledWith({ recordId: 'e1' });
        expect(el.shadowRoot.querySelector('lightning-card').title).toBe('Onboarding de Bruno Lima');
        const groups = el.shadowRoot.querySelectorAll('section.group');
        expect(groups).toHaveLength(2);
        expect(groups[0].dataset.role).toBe('Colaborador');
        expect(groups[1].querySelector('.group-summary').textContent).toBe('0 de 2');
        expect(el.shadowRoot.querySelector('.progress-text').textContent).toBe('1 de 3 tarefas resolvidas (33%)');
        expect(el.shadowRoot.querySelector('lightning-progress-bar').value).toBe(33);
        expect(el.shadowRoot.querySelector('.overdue-badge').textContent).toContain('1 tarefa atrasada');
        expect(el.shadowRoot.querySelector('.start-text').textContent).toBe('Início em 15/01/2030');
    });

    it('destaca a tarefa vencida e mostra o responsavel', async () => {
        getChecklist.mockResolvedValue(view());
        const el = await mount('e1');

        const rows = el.shadowRoot.querySelectorAll('li.task-row');
        expect(rows).toHaveLength(3);
        const overdue = rows[1];
        expect(overdue.querySelector('.task-due').textContent).toBe('Prazo: 01/02/2020');
        expect(overdue.querySelector('.task-due').classList.contains('slds-text-color_error')).toBe(true);
        expect(overdue.querySelector('.task-late')).not.toBeNull();
        expect(overdue.querySelector('.task-assignee').textContent).toBe('Ana Souza');
        expect(rows[2].querySelector('.task-assignee').textContent).toBe('Sem responsável');
        expect(rows[0].querySelector('.task-late')).toBeNull();
    });

    it('so habilita o checkbox de quem pode alterar a tarefa', async () => {
        getChecklist.mockResolvedValue(view());
        const el = await mount('e1');

        const checks = el.shadowRoot.querySelectorAll('lightning-input.task-check');
        expect(checks[0].checked).toBe(true);
        expect(checks[0].disabled).toBe(false);
        expect(checks[1].disabled).toBe(false);
        expect(checks[2].disabled).toBe(true);
    });

    it('conclui a tarefa e recarrega o checklist', async () => {
        getChecklist.mockResolvedValue(view());
        setTaskDone.mockResolvedValue();
        const el = await mount('e1');

        const check = el.shadowRoot.querySelector('lightning-input[data-id="t2"]');
        check.dispatchEvent(new CustomEvent('change', { detail: { checked: true } }));
        await flush();
        await flush();

        expect(setTaskDone).toHaveBeenCalledWith({ taskId: 't2', done: true });
        expect(getChecklist).toHaveBeenCalledTimes(2);
    });

    it('mostra o erro do servidor ao concluir e recarrega para desfazer o checkbox', async () => {
        getChecklist.mockResolvedValue(view());
        setTaskDone.mockRejectedValue({ body: { message: 'Somente o responsável pela tarefa ou o RH pode alterar a situação.' } });
        const el = await mount('e1');
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);

        el.shadowRoot.querySelector('lightning-input[data-id="t2"]').dispatchEvent(new CustomEvent('change', { detail: { checked: true } }));
        await flush();
        await flush();

        expect(toast).toHaveBeenCalledTimes(1);
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('Somente o responsável');
        expect(getChecklist).toHaveBeenCalledTimes(2);
    });

    it('sem recordId carrega o plano do usuario atual', async () => {
        getChecklist.mockResolvedValue(view());
        await mount();

        expect(getChecklist).toHaveBeenCalledWith({ recordId: null });
    });

    it('mostra o estado vazio quando nao ha plano', async () => {
        getChecklist.mockResolvedValue({ hasPlan: false, groups: [] });
        const el = await mount('e1');

        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
        expect(el.shadowRoot.querySelector('section.group')).toBeNull();
    });

    it('mostra o erro de carregamento', async () => {
        getChecklist.mockRejectedValue({ body: { message: 'Sem acesso.' } });
        const el = await mount('e1');

        expect(el.shadowRoot.querySelector('.load-error').textContent).toContain('Sem acesso.');
    });

    it('oferece ao RH recalcular prazos quando a data de admissao mudou', async () => {
        getChecklist.mockResolvedValue(view({ isHr: true, datesOutOfSync: true }));
        syncPlan.mockResolvedValue();
        const el = await mount('e1');

        const button = el.shadowRoot.querySelector('lightning-button.sync-button');
        expect(button).not.toBeNull();
        button.click();
        await flush();
        await flush();

        expect(syncPlan).toHaveBeenCalledWith({ employeeId: 'e1' });
        expect(getChecklist).toHaveBeenCalledTimes(2);
    });

    it('nao oferece o recalculo a quem nao e do RH nem quando os prazos estao em dia', async () => {
        getChecklist.mockResolvedValue(view({ isHr: false, datesOutOfSync: true }));
        let el = await mount('e1');
        expect(el.shadowRoot.querySelector('.sync-button')).toBeNull();

        document.body.removeChild(el);
        getChecklist.mockResolvedValue(view({ isHr: true, datesOutOfSync: false }));
        el = await mount('e1');
        expect(el.shadowRoot.querySelector('.sync-button')).toBeNull();
    });

    it('mostra erro ao falhar o recalculo', async () => {
        getChecklist.mockResolvedValue(view({ isHr: true, datesOutOfSync: true }));
        syncPlan.mockRejectedValue({ body: { message: 'Somente o RH pode fazer esta operação.' } });
        const el = await mount('e1');
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);

        el.shadowRoot.querySelector('lightning-button.sync-button').click();
        await flush();
        await flush();

        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
    });

    it('marca plano concluido e tarefa nao aplicavel', async () => {
        const na = task({ id: 't9', status: 'Nao_Aplicavel', statusLabel: 'Não aplicável', done: false });
        getChecklist.mockResolvedValue(
            view({
                planStatus: 'Concluido',
                planStatusLabel: 'Concluído',
                overdueCount: 0,
                groups: [{ role: 'TI', roleLabel: 'TI', total: 1, resolved: 1, tasks: [na] }]
            })
        );
        const el = await mount('e1');

        expect(el.shadowRoot.querySelector('.status-badge').classList.contains('slds-theme_success')).toBe(true);
        expect(el.shadowRoot.querySelector('.task-na')).not.toBeNull();
        expect(el.shadowRoot.querySelector('lightning-input.task-check').disabled).toBe(true);
        expect(el.shadowRoot.querySelector('.overdue-badge')).toBeNull();
    });
});
