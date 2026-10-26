import { createElement } from 'lwc';
import PerformanceReviewForm from 'c/performanceReviewForm';
import getReviewForm from '@salesforce/apex/PerformanceReviewController.getReviewForm';
import saveReview from '@salesforce/apex/PerformanceReviewController.saveReview';

jest.mock('@salesforce/apex/PerformanceReviewController.getReviewForm', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PerformanceReviewController.saveReview', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const TOAST = 'lightning__showtoast';

function form(overrides) {
    return {
        reviewId: 'r1',
        employeeId: 'e1',
        employeeName: 'Bruno Lima',
        positionName: 'Analista',
        cycle: { id: 'c1', name: 'Ciclo 2026', status: 'Avaliacao_Gestor', scaleMax: 5 },
        reviewStatus: 'Pendente',
        managerRating: null,
        managerComments: null,
        calibratedRating: null,
        finalRating: null,
        canEdit: true,
        selfAssessment: { id: 'sa1', rating: 4, strengths: 'Entrega', improvements: 'Comunicacao', submitted: true },
        goals: [{ id: 'g1', name: 'Meta 1', target: 'Alvo', weight: 100, selfScore: 4, status: 'Ativa' }],
        weightSum: 100,
        ...overrides
    };
}

function mount(reviewId) {
    const el = createElement('c-performance-review-form', { is: PerformanceReviewForm });
    el.reviewId = reviewId;
    document.body.appendChild(el);
    return el;
}

function setValue(el, selector, value) {
    el.shadowRoot.querySelector(selector).dispatchEvent(new CustomEvent('change', { detail: { value } }));
}

describe('c-performance-review-form', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra colaborador, metas e autoavaliacao', async () => {
        getReviewForm.mockResolvedValue(form());
        const el = mount('r1');
        await flush();
        expect(getReviewForm).toHaveBeenCalledWith({ reviewId: 'r1' });
        expect(el.shadowRoot.querySelector('.employee-name').textContent).toBe('Bruno Lima');
        expect(el.shadowRoot.querySelectorAll('.goal-row').length).toBe(1);
        expect(el.shadowRoot.querySelector('.self-rating').textContent).toBe('4');
        expect(el.shadowRoot.querySelector('.review-status').textContent).toBe('Pendente');
        expect(el.shadowRoot.querySelector('.submit-review').disabled).toBe(true);
    });

    it('avisa quando o colaborador nao enviou a autoavaliacao nem registrou metas', async () => {
        getReviewForm.mockResolvedValue(
            form({ goals: [], selfAssessment: { id: 'sa1', rating: null, submitted: false } })
        );
        const el = mount('r1');
        await flush();
        expect(el.shadowRoot.querySelector('.no-goals')).not.toBeNull();
        expect(el.shadowRoot.querySelector('.self-pending')).not.toBeNull();
    });

    it('salva rascunho e atualiza a situacao', async () => {
        getReviewForm.mockResolvedValue(form());
        saveReview.mockResolvedValue(form({ reviewStatus: 'Em_Andamento', managerRating: 4, managerComments: 'Bom' }));
        const el = mount('r1');
        const saved = jest.fn();
        el.addEventListener('saved', saved);
        await flush();
        setValue(el, '.manager-rating', '4');
        setValue(el, '.manager-comments', 'Bom');
        el.shadowRoot.querySelector('.save-draft').click();
        await flush();
        expect(saveReview).toHaveBeenCalledWith({ reviewId: 'r1', rating: 4, comments: 'Bom', submitReview: false });
        expect(el.shadowRoot.querySelector('.review-status').textContent).toBe('Em andamento');
        expect(saved).toHaveBeenCalled();
        expect(saved.mock.calls[0][0].detail.submitted).toBe(false);
    });

    it('envia a avaliacao e trava a edicao', async () => {
        getReviewForm.mockResolvedValue(form());
        saveReview.mockResolvedValue(form({ reviewStatus: 'Enviada', managerRating: 5, managerComments: 'Excelente', canEdit: false }));
        const el = mount('r1');
        await flush();
        setValue(el, '.manager-rating', '5');
        setValue(el, '.manager-comments', 'Excelente');
        await flush();
        expect(el.shadowRoot.querySelector('.submit-review').disabled).toBe(false);
        el.shadowRoot.querySelector('.submit-review').click();
        await flush();
        expect(saveReview).toHaveBeenCalledWith({ reviewId: 'r1', rating: 5, comments: 'Excelente', submitReview: true });
        expect(el.shadowRoot.querySelector('.submit-review')).toBeNull();
        expect(el.shadowRoot.querySelector('.locked-note')).not.toBeNull();
    });

    it('mostra o erro do servidor ao salvar', async () => {
        getReviewForm.mockResolvedValue(form());
        saveReview.mockRejectedValue({ body: { message: 'O ciclo não está na fase de avaliação do gestor.' } });
        const el = mount('r1');
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        el.shadowRoot.querySelector('.save-draft').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('fase de avaliação');
    });

    it('somente leitura mostra a nota final e a calibrada para o RH', async () => {
        getReviewForm.mockResolvedValue(
            form({ reviewStatus: 'Liberada', canEdit: false, managerRating: 5, managerComments: 'Ok', calibratedRating: 4, finalRating: 4 })
        );
        const el = mount('r1');
        await flush();
        expect(el.shadowRoot.querySelector('.calibrated-rating').textContent).toBe('4');
        expect(el.shadowRoot.querySelector('.final-rating').textContent).toBe('4');
        expect(el.shadowRoot.querySelector('.save-draft')).toBeNull();
    });

    it('usa recordId e fecha pelo botao voltar', async () => {
        getReviewForm.mockResolvedValue(form());
        const el = createElement('c-performance-review-form', { is: PerformanceReviewForm });
        el.recordId = 'r9';
        document.body.appendChild(el);
        const closed = jest.fn();
        el.addEventListener('close', closed);
        await flush();
        expect(getReviewForm).toHaveBeenCalledWith({ reviewId: 'r9' });
        expect(el.reviewId).toBe('r9');
        el.shadowRoot.querySelector('.close').click();
        expect(closed).toHaveBeenCalled();
    });

    it('mostra erro ao carregar', async () => {
        getReviewForm.mockRejectedValue({ body: { message: 'Avaliação não encontrada ou sem acesso.' } });
        const el = mount('r1');
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('sem acesso');
    });
});
