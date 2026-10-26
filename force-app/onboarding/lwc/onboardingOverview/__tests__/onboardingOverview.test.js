import { createElement } from 'lwc';
import OnboardingOverview from 'c/onboardingOverview';
import getOverview from '@salesforce/apex/OnboardingController.getOverview';
import getChecklist from '@salesforce/apex/OnboardingController.getChecklist';

jest.mock('@salesforce/apex/OnboardingController.getOverview', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OnboardingController.getChecklist', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OnboardingController.setTaskDone', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OnboardingController.syncPlan', () => ({ default: jest.fn() }), { virtual: true });

const RESULT = {
    planCount: 2,
    overduePlanCount: 1,
    averageProgress: 40,
    plans: [
        {
            planId: 'p1',
            planName: 'ON-000001',
            employeeId: 'e1',
            employeeName: 'Bruno Lima',
            employeeStatus: 'Ativo',
            startDate: '2030-01-10',
            status: 'Em_Andamento',
            statusLabel: 'Em andamento',
            total: 8,
            resolved: 5,
            progressPercent: 63,
            overdueCount: 2
        },
        {
            planId: 'p2',
            planName: 'ON-000002',
            employeeId: 'e2',
            employeeName: 'Carla Dias',
            employeeStatus: 'Pre_Admissao',
            startDate: null,
            status: 'Nao_Iniciado',
            statusLabel: 'Não iniciado',
            total: 8,
            resolved: 0,
            progressPercent: 0,
            overdueCount: 0
        }
    ]
};

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function mount() {
    const el = createElement('c-onboarding-overview', { is: OnboardingOverview });
    document.body.appendChild(el);
    await flush();
    return el;
}

describe('c-onboarding-overview', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra os indicadores e a lista de planos com progresso e atraso', async () => {
        getOverview.mockResolvedValue(RESULT);
        const el = await mount();

        expect(getOverview).toHaveBeenCalledWith({ includeCompleted: false });
        expect(el.shadowRoot.querySelector('.tile-count .slds-text-heading_medium').textContent).toBe('2');
        expect(el.shadowRoot.querySelector('.tile-overdue .slds-text-heading_medium').textContent).toBe('1');
        expect(el.shadowRoot.querySelector('.tile-average .slds-text-heading_medium').textContent).toBe('40%');
        const rows = el.shadowRoot.querySelectorAll('tr.plan-row');
        expect(rows).toHaveLength(2);
        expect(rows[0].querySelector('.plan-open').textContent).toBe('Bruno Lima');
        expect(rows[0].querySelector('.plan-start').textContent).toBe('10/01/2030');
        expect(rows[0].querySelector('.plan-progress').textContent).toBe('5 de 8 (63%)');
        expect(rows[0].querySelector('.plan-overdue').textContent).toBe('2 atrasadas');
        expect(rows[1].querySelector('.plan-start').textContent).toBe('sem data');
        expect(rows[1].querySelector('.plan-overdue')).toBeNull();
    });

    it('usa o singular para um plano com uma tarefa atrasada', async () => {
        getOverview.mockResolvedValue({ ...RESULT, plans: [{ ...RESULT.plans[0], overdueCount: 1 }] });
        const el = await mount();

        expect(el.shadowRoot.querySelector('.plan-overdue').textContent).toBe('1 atrasada');
    });

    it('recarrega incluindo concluidos ao marcar a opcao', async () => {
        getOverview.mockResolvedValue(RESULT);
        const el = await mount();

        el.shadowRoot.querySelector('lightning-input.show-completed').dispatchEvent(new CustomEvent('change', { detail: { checked: true } }));
        await flush();

        expect(getOverview).toHaveBeenLastCalledWith({ includeCompleted: true });
    });

    it('atualiza a lista pelo botao', async () => {
        getOverview.mockResolvedValue(RESULT);
        const el = await mount();

        el.shadowRoot.querySelector('lightning-button-icon.refresh').click();
        await flush();

        expect(getOverview).toHaveBeenCalledTimes(2);
    });

    it('abre o checklist do plano escolhido e fecha o detalhe', async () => {
        getOverview.mockResolvedValue(RESULT);
        getChecklist.mockResolvedValue({ hasPlan: false, groups: [] });
        const el = await mount();

        el.shadowRoot.querySelector('button.plan-open[data-id="p2"]').click();
        await flush();

        const detail = el.shadowRoot.querySelector('c-onboarding-checklist');
        expect(detail).not.toBeNull();
        expect(detail.recordId).toBe('p2');

        el.shadowRoot.querySelector('lightning-button.close-detail').click();
        await flush();

        expect(el.shadowRoot.querySelector('c-onboarding-checklist')).toBeNull();
        expect(getOverview).toHaveBeenCalledTimes(2);
    });

    it('mostra o estado vazio sem planos', async () => {
        getOverview.mockResolvedValue({ planCount: 0, overduePlanCount: 0, averageProgress: 0, plans: [] });
        const el = await mount();

        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
        expect(el.shadowRoot.querySelector('table')).toBeNull();
    });

    it('mostra o erro do servidor', async () => {
        getOverview.mockRejectedValue({ body: { message: 'Sem acesso.' } });
        const el = await mount();

        expect(el.shadowRoot.querySelector('.load-error').textContent).toContain('Sem acesso.');
        expect(el.shadowRoot.querySelector('table')).toBeNull();
    });
});
