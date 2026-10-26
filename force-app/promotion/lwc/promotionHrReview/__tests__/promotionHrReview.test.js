import { createElement } from 'lwc';
import PromotionHrReview from 'c/promotionHrReview';
import getPendingForHr from '@salesforce/apex/PromotionRequestController.getPendingForHr';
import getHrReview from '@salesforce/apex/PromotionRequestController.getHrReview';
import hrDecide from '@salesforce/apex/PromotionRequestController.hrDecide';

const ShowToastEventName = 'lightning__showtoast';

jest.mock('@salesforce/apex/PromotionRequestController.getPendingForHr', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PromotionRequestController.getHrReview', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PromotionRequestController.hrDecide', () => ({ default: jest.fn() }), { virtual: true });

const PENDING = [
    { stepId: 's1', requestId: 'r1', requestName: 'PR-000001', employeeName: 'Bruno Lima' },
    { stepId: 's2', requestId: 'r2', requestName: null, stepName: 'AP-000002', employeeName: null }
];

const REVIEW = {
    requestId: 'r1',
    requestName: 'PR-000001',
    status: 'Pendente',
    employeeName: 'Bruno Lima',
    requestedByName: 'Gestora Ana',
    currentPositionName: 'Analista Junior',
    proposedPositionName: 'Analista Pleno',
    effectiveDate: '2026-12-01',
    justification: 'Entrega acima do esperado',
    currentSalary: 4000,
    proposedSalary: null,
    bandName: 'Faixa P2',
    bandMin: 5000,
    bandMax: 8000,
    canDecide: true
};

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount(recordId) {
    const el = createElement('c-promotion-hr-review', { is: PromotionHrReview });
    if (recordId) {
        el.recordId = recordId;
    }
    document.body.appendChild(el);
    return el;
}

function type(el, selector, value) {
    el.shadowRoot.querySelector(selector).dispatchEvent(new CustomEvent('change', { detail: { value } }));
}

describe('c-promotion-hr-review', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista as promocoes que aguardam o RH e abre a revisao', async () => {
        getPendingForHr.mockResolvedValue(PENDING);
        getHrReview.mockResolvedValue(REVIEW);
        const el = mount();
        await flush();
        const rows = el.shadowRoot.querySelectorAll('.pending-item');
        expect(rows.length).toBe(2);
        expect(rows[0].textContent).toContain('PR-000001');
        expect(rows[0].textContent).toContain('Bruno Lima');
        expect(rows[1].textContent).toContain('AP-000002');
        expect(rows[1].textContent).toContain('sem resumo');

        el.shadowRoot.querySelector('lightning-button.select').click();
        await flush();
        expect(getHrReview).toHaveBeenCalledWith({ requestId: 'r1' });
        expect(el.shadowRoot.querySelector('.review-title').textContent).toContain('Bruno Lima');
    });

    it('mostra estado vazio sem pendencias', async () => {
        getPendingForHr.mockResolvedValue([]);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
    });

    it('mostra erro ao carregar', async () => {
        getPendingForHr.mockRejectedValue({ body: { message: 'Sem acesso' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.load-error').textContent).toContain('Sem acesso');
    });

    it('mostra o resumo, a faixa e o salario atual na tela de registro', async () => {
        getHrReview.mockResolvedValue(REVIEW);
        const el = mount('r1');
        await flush();
        expect(getPendingForHr).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.current-position').textContent).toBe('Analista Junior');
        expect(el.shadowRoot.querySelector('.proposed-position').textContent).toBe('Analista Pleno');
        expect(el.shadowRoot.querySelector('.effective-date').textContent).toBe('01/12/2026');
        expect(el.shadowRoot.querySelector('.current-salary').textContent).toMatch(/4\.000,00/);
        expect(el.shadowRoot.querySelector('.band-range').textContent).toMatch(/5\.000,00.*8\.000,00/);
        expect(el.shadowRoot.querySelector('.justification').textContent).toContain('Entrega acima do esperado');
        expect(el.shadowRoot.querySelector('lightning-button.back')).toBeNull();
    });

    it('calcula o aumento e o indicador dentro, abaixo e acima da faixa', async () => {
        getHrReview.mockResolvedValue(REVIEW);
        const el = mount('r1');
        await flush();
        expect(el.shadowRoot.querySelector('.increase')).toBeNull();
        expect(el.shadowRoot.querySelector('.band-badge')).toBeNull();

        type(el, 'lightning-input.salary', 6000);
        await flush();
        expect(el.shadowRoot.querySelector('.increase').textContent).toMatch(/\+50,00 %/);
        expect(el.shadowRoot.querySelector('.band-badge').textContent).toBe('Dentro da faixa');

        type(el, 'lightning-input.salary', 4500);
        await flush();
        expect(el.shadowRoot.querySelector('.increase').textContent).toMatch(/\+12,50 %/);
        expect(el.shadowRoot.querySelector('.band-badge').textContent).toBe('Abaixo da faixa');

        type(el, 'lightning-input.salary', 9000);
        await flush();
        expect(el.shadowRoot.querySelector('.band-badge').textContent).toBe('Acima da faixa');
        expect(el.shadowRoot.querySelector('lightning-textarea.comment').label).toContain('obrigatória fora da faixa');

        type(el, 'lightning-input.salary', 3000);
        await flush();
        expect(el.shadowRoot.querySelector('.increase').textContent).toMatch(/-25,00 %/);
    });

    it('indica cargo sem faixa', async () => {
        getHrReview.mockResolvedValue({ ...REVIEW, bandName: null, bandMin: null, bandMax: null });
        const el = mount('r1');
        await flush();
        expect(el.shadowRoot.querySelector('.band-range').textContent).toContain('sem faixa');
        expect(el.shadowRoot.querySelector('.band-badge').textContent).toBe('Cargo sem faixa');
    });

    it('exige salario para aprovar', async () => {
        getHrReview.mockResolvedValue(REVIEW);
        const el = mount('r1');
        await flush();
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(el.shadowRoot.querySelector('.decision-error').textContent).toContain('Informe o salário proposto');
        expect(hrDecide).not.toHaveBeenCalled();
    });

    it('exige justificativa fora da faixa e aprova com ela', async () => {
        getHrReview.mockResolvedValue(REVIEW);
        hrDecide.mockResolvedValue();
        const el = mount('r1');
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        type(el, 'lightning-input.salary', 9000);
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(el.shadowRoot.querySelector('.decision-error').textContent).toContain('fora da faixa');
        expect(hrDecide).not.toHaveBeenCalled();

        type(el, 'lightning-textarea.comment', ' Retenção de talento ');
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(hrDecide).toHaveBeenCalledWith({
            requestId: 'r1',
            proposedSalary: 9000,
            approve: true,
            comments: 'Retenção de talento'
        });
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
    });

    it('aprova dentro da faixa sem comentario', async () => {
        getHrReview.mockResolvedValue(REVIEW);
        hrDecide.mockResolvedValue();
        const el = mount('r1');
        await flush();
        type(el, 'lightning-input.salary', 5500);
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(hrDecide).toHaveBeenCalledWith({ requestId: 'r1', proposedSalary: 5500, approve: true, comments: null });
    });

    it('exige comentario para rejeitar e rejeita sem salario', async () => {
        getHrReview.mockResolvedValue(REVIEW);
        hrDecide.mockResolvedValue();
        const el = mount('r1');
        await flush();
        el.shadowRoot.querySelector('lightning-button.reject').click();
        await flush();
        expect(el.shadowRoot.querySelector('.decision-error').textContent).toContain('comentário para rejeitar');
        expect(hrDecide).not.toHaveBeenCalled();

        type(el, 'lightning-textarea.comment', 'Fora do ciclo');
        el.shadowRoot.querySelector('lightning-button.reject').click();
        await flush();
        expect(hrDecide).toHaveBeenCalledWith({ requestId: 'r1', proposedSalary: null, approve: false, comments: 'Fora do ciclo' });
    });

    it('mostra o erro do servidor ao decidir', async () => {
        getHrReview.mockResolvedValue(REVIEW);
        hrDecide.mockRejectedValue({ body: { message: 'Esta solicitação não está aguardando a decisão do RH.' } });
        const el = mount('r1');
        await flush();
        type(el, 'lightning-input.salary', 5500);
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(el.shadowRoot.querySelector('.decision-error').textContent).toContain('não está aguardando');
    });

    it('oculta as acoes quando a solicitacao nao aguarda o RH', async () => {
        getHrReview.mockResolvedValue({ ...REVIEW, canDecide: false, status: 'Aprovado', proposedSalary: 6000 });
        const el = mount('r1');
        await flush();
        expect(el.shadowRoot.querySelector('lightning-button.approve')).toBeNull();
        expect(el.shadowRoot.querySelector('.not-awaiting')).not.toBeNull();
        expect(el.shadowRoot.querySelector('lightning-input.salary').value).toBe('6000');
    });

    it('volta para a lista e recarrega depois de decidir pela lista', async () => {
        getPendingForHr.mockResolvedValueOnce(PENDING).mockResolvedValueOnce([PENDING[1]]);
        getHrReview.mockResolvedValue(REVIEW);
        hrDecide.mockResolvedValue();
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('lightning-button.select').click();
        await flush();
        type(el, 'lightning-input.salary', 5500);
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(el.shadowRoot.querySelectorAll('.pending-item').length).toBe(1);

        getHrReview.mockResolvedValue(REVIEW);
        getPendingForHr.mockResolvedValueOnce(PENDING);
        el.shadowRoot.querySelector('lightning-button.select').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.back').click();
        await flush();
        expect(el.shadowRoot.querySelectorAll('.pending-item').length).toBe(2);
    });
});
