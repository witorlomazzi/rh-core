/* eslint-disable @lwc/lwc/no-async-operation */
import { createElement } from 'lwc';
import PerformanceMyCycle from 'c/performanceMyCycle';
import getMyCycle from '@salesforce/apex/PerformanceReviewController.getMyCycle';
import saveGoal from '@salesforce/apex/GoalController.saveGoal';
import cancelGoal from '@salesforce/apex/GoalController.cancelGoal';
import setScore from '@salesforce/apex/GoalController.setScore';
import saveDraft from '@salesforce/apex/SelfAssessmentController.saveDraft';
import submitAssessment from '@salesforce/apex/SelfAssessmentController.submitAssessment';

jest.mock('@salesforce/apex/PerformanceReviewController.getMyCycle', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/GoalController.saveGoal', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/GoalController.cancelGoal', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/GoalController.setScore', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/SelfAssessmentController.saveDraft', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/SelfAssessmentController.submitAssessment', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const TOAST = 'lightning__showtoast';

function view(overrides) {
    return {
        hasEmployee: true,
        employeeId: 'e1',
        employeeName: 'Bruno Lima',
        cycle: { id: 'c1', name: 'Ciclo 2026', status: 'Autoavaliacao', selfDue: '2026-11-30', scaleMax: 5 },
        cycles: [{ id: 'c1', name: 'Ciclo 2026' }],
        selfAssessment: { id: 'sa1', rating: null, strengths: '', improvements: '', submitted: false },
        goals: [
            { id: 'g1', name: 'Reduzir retrabalho', target: '10%', description: 'Melhorar', weight: 60, selfScore: null, status: 'Ativa' },
            { id: 'g2', name: 'Antiga', target: '', description: '', weight: 20, selfScore: null, status: 'Cancelada' }
        ],
        weightSum: 60,
        canEditGoals: true,
        canEditSelf: true,
        released: null,
        ...overrides
    };
}

function mount() {
    const el = createElement('c-performance-my-cycle', { is: PerformanceMyCycle });
    document.body.appendChild(el);
    return el;
}

function setValue(el, selector, value) {
    const field = el.shadowRoot.querySelector(selector);
    field.dispatchEvent(new CustomEvent('change', { detail: { value } }));
}

describe('c-performance-my-cycle', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra ciclo, metas e aviso enquanto os pesos nao fecham 100%', async () => {
        getMyCycle.mockResolvedValue(view());
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.cycle-name').textContent).toBe('Ciclo 2026');
        expect(el.shadowRoot.querySelector('.cycle-status').textContent).toBe('Autoavaliação');
        expect(el.shadowRoot.querySelectorAll('.goal-item').length).toBe(2);
        const warning = el.shadowRoot.querySelector('.weight-warning');
        expect(warning.textContent).toContain('somam 60%');
        expect(el.shadowRoot.querySelector('.submit-self').disabled).toBe(true);
    });

    it('libera o envio quando os pesos fecham 100% e ha nota', async () => {
        getMyCycle.mockResolvedValue(view({ weightSum: 100, selfAssessment: { id: 'sa1', rating: 4, strengths: 'a', improvements: 'b', submitted: false } }));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.weight-ok')).not.toBeNull();
        expect(el.shadowRoot.querySelector('.submit-self').disabled).toBe(false);
    });

    it('adiciona meta e recarrega', async () => {
        getMyCycle.mockResolvedValue(view());
        saveGoal.mockResolvedValue('g3');
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        setValue(el, '.new-name', 'Nova meta');
        setValue(el, '.new-target', 'Alvo');
        setValue(el, '.new-weight', '40');
        el.shadowRoot.querySelector('.add-goal').click();
        await flush();
        expect(saveGoal).toHaveBeenCalledWith({
            goalId: null,
            cycleId: 'c1',
            name: 'Nova meta',
            target: 'Alvo',
            description: '',
            weight: 40,
            selfScore: null
        });
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
        expect(getMyCycle).toHaveBeenCalledTimes(2);
    });

    it('remove meta e grava a nota da meta', async () => {
        getMyCycle.mockResolvedValue(view());
        cancelGoal.mockResolvedValue();
        setScore.mockResolvedValue();
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.goal-cancel').click();
        await flush();
        expect(cancelGoal).toHaveBeenCalledWith({ goalId: 'g1' });
        setValue(el, '.goal-score', '4');
        await flush();
        expect(setScore).toHaveBeenCalledWith({ goalId: 'g1', selfScore: 4 });
    });

    it('salva rascunho com os campos digitados', async () => {
        getMyCycle.mockResolvedValue(view({ weightSum: 100 }));
        saveDraft.mockResolvedValue();
        const el = mount();
        await flush();
        setValue(el, '.self-rating', '5');
        setValue(el, '.self-strengths', 'Forcas');
        setValue(el, '.self-improvements', 'Melhorias');
        el.shadowRoot.querySelector('.save-draft').click();
        await flush();
        expect(saveDraft).toHaveBeenCalledWith({ assessmentId: 'sa1', rating: 5, strengths: 'Forcas', improvements: 'Melhorias' });
    });

    it('envia a autoavaliacao com os dados do formulario', async () => {
        getMyCycle.mockResolvedValue(view({ weightSum: 100 }));
        submitAssessment.mockResolvedValue();
        const el = mount();
        await flush();
        setValue(el, '.self-rating', '4');
        setValue(el, '.self-strengths', 'Forcas');
        await flush();
        el.shadowRoot.querySelector('.submit-self').click();
        await flush();
        expect(submitAssessment).toHaveBeenCalledWith({ assessmentId: 'sa1', rating: 4, strengths: 'Forcas', improvements: '' });
    });

    it('mostra o erro do servidor ao enviar', async () => {
        getMyCycle.mockResolvedValue(view({ weightSum: 100, selfAssessment: { id: 'sa1', rating: 3, strengths: '', improvements: '', submitted: false } }));
        submitAssessment.mockRejectedValue({ body: { message: 'Os pesos das metas ativas somam 80%.' } });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        el.shadowRoot.querySelector('.submit-self').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('80%');
    });

    it('autoavaliacao enviada fica somente leitura e mostra o resultado liberado', async () => {
        getMyCycle.mockResolvedValue(
            view({
                cycle: { id: 'c1', name: 'Ciclo 2026', status: 'Concluido', selfDue: null, scaleMax: 5 },
                selfAssessment: { id: 'sa1', rating: 4, strengths: 'a', improvements: 'b', submitted: true },
                canEditGoals: false,
                canEditSelf: false,
                weightSum: 100,
                released: { managerRating: 5, finalRating: 3, managerComments: 'Excelente' }
            })
        );
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.submitted-note')).not.toBeNull();
        expect(el.shadowRoot.querySelector('.submit-self')).toBeNull();
        expect(el.shadowRoot.querySelector('.new-goal')).toBeNull();
        expect(el.shadowRoot.querySelector('.manager-rating').textContent).toBe('5');
        expect(el.shadowRoot.querySelector('.final-rating').textContent).toBe('3');
        expect(el.shadowRoot.querySelector('.manager-comments').textContent).toBe('Excelente');
    });

    it('troca de ciclo pelo seletor', async () => {
        getMyCycle.mockResolvedValue(view({ cycles: [{ id: 'c1', name: 'Ciclo 2026' }, { id: 'c0', name: 'Ciclo 2025' }] }));
        const el = mount();
        await flush();
        setValue(el, '.cycle-picker', 'c0');
        await flush();
        expect(getMyCycle).toHaveBeenLastCalledWith({ cycleId: 'c0' });
    });

    it('trata usuario sem colaborador e sem ciclo', async () => {
        getMyCycle.mockResolvedValueOnce({ hasEmployee: false, cycles: [], goals: [] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.no-employee')).not.toBeNull();

        getMyCycle.mockResolvedValueOnce({ hasEmployee: true, cycles: [], goals: [] });
        const el2 = mount();
        await flush();
        expect(el2.shadowRoot.querySelector('.no-cycle')).not.toBeNull();
    });

    it('mostra erro ao carregar', async () => {
        getMyCycle.mockRejectedValue({ body: { message: 'Sem acesso' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem acesso');
    });
});
