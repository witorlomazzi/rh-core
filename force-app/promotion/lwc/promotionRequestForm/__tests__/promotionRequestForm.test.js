import { createElement } from 'lwc';
import PromotionRequestForm from 'c/promotionRequestForm';
import getTeam from '@salesforce/apex/PromotionRequestController.getTeam';
import getFormContext from '@salesforce/apex/PromotionRequestController.getFormContext';
import submitRequest from '@salesforce/apex/PromotionRequestController.submitRequest';

const ShowToastEventName = 'lightning__showtoast';

jest.mock('@salesforce/apex/PromotionRequestController.getTeam', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PromotionRequestController.getFormContext', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PromotionRequestController.submitRequest', () => ({ default: jest.fn() }), { virtual: true });

const TEAM = [
    { id: 'e1', name: 'Bruno Lima', positionName: 'Analista Junior', departmentName: 'Comercial' },
    { id: 'e2', name: 'Carla Dias', positionName: null, departmentName: 'Comercial' }
];

const CONTEXT = {
    currentPositionId: 'pA',
    currentPositionName: 'Analista Junior',
    nextPositionId: 'pB',
    nextPositionName: 'Analista Pleno',
    options: [
        { value: 'pB', label: 'Analista Pleno', isNext: true },
        { value: 'pC', label: 'Coordenador', isNext: false }
    ]
};

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount() {
    const el = createElement('c-promotion-request-form', { is: PromotionRequestForm });
    document.body.appendChild(el);
    return el;
}

function change(el, selector, value) {
    el.shadowRoot.querySelector(selector).dispatchEvent(new CustomEvent('change', { detail: { value } }));
}

async function fillValid(el, positionId = 'pB') {
    change(el, 'lightning-combobox.employee', 'e1');
    await flush();
    change(el, 'lightning-combobox.position', positionId);
    change(el, 'lightning-input.effective-date', '2999-01-10');
    change(el, 'lightning-textarea.justification', '  Entrega acima do esperado  ');
    await flush();
}

describe('c-promotion-request-form', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista a equipe do gestor com o cargo atual', async () => {
        getTeam.mockResolvedValue(TEAM);
        const el = mount();
        await flush();
        const combo = el.shadowRoot.querySelector('lightning-combobox.employee');
        expect(combo.options).toEqual([
            { value: 'e1', label: 'Bruno Lima (Analista Junior)' },
            { value: 'e2', label: 'Carla Dias (sem cargo)' }
        ]);
        expect(el.shadowRoot.querySelector('lightning-combobox.position')).toBeNull();
        expect(el.shadowRoot.querySelector('.submit').disabled).toBe(true);
    });

    it('avisa quando nao ha equipe', async () => {
        getTeam.mockResolvedValue([]);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty-team')).not.toBeNull();
        expect(el.shadowRoot.querySelector('lightning-combobox.employee')).toBeNull();
    });

    it('mostra erro ao carregar a equipe', async () => {
        getTeam.mockRejectedValue({ body: { message: 'Sem acesso' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.load-error').textContent).toContain('Sem acesso');
    });

    it('destaca o proximo da trilha ao escolher o colaborador', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockResolvedValue(CONTEXT);
        const el = mount();
        await flush();
        change(el, 'lightning-combobox.employee', 'e1');
        await flush();
        expect(getFormContext).toHaveBeenCalledWith({ employeeId: 'e1' });
        const position = el.shadowRoot.querySelector('lightning-combobox.position');
        expect(position.options[0].label).toBe('Analista Pleno (próximo da trilha)');
        expect(position.options[1].label).toBe('Coordenador');
        expect(el.shadowRoot.querySelector('.trail-hint').textContent).toContain('Próximo da trilha: Analista Pleno');
        expect(el.shadowRoot.querySelector('.off-track')).toBeNull();
    });

    it('mostra o aviso de fora da trilha sem bloquear', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockResolvedValue(CONTEXT);
        const el = mount();
        await flush();
        change(el, 'lightning-combobox.employee', 'e1');
        await flush();
        change(el, 'lightning-combobox.position', 'pC');
        await flush();
        expect(el.shadowRoot.querySelector('.off-track').textContent).toContain('Promoção fora da trilha prevista.');
        change(el, 'lightning-combobox.position', 'pB');
        await flush();
        expect(el.shadowRoot.querySelector('.off-track')).toBeNull();
    });

    it('informa quando o cargo atual nao tem proximo passo', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockResolvedValue({ ...CONTEXT, nextPositionId: null, nextPositionName: null });
        const el = mount();
        await flush();
        change(el, 'lightning-combobox.employee', 'e1');
        await flush();
        expect(el.shadowRoot.querySelector('.trail-hint').textContent).toContain('não tem próximo passo');
    });

    it('valida os campos antes de enviar', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockResolvedValue(CONTEXT);
        const el = mount();
        await flush();
        change(el, 'lightning-combobox.employee', 'e1');
        await flush();

        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toBe('Escolha o novo cargo.');

        change(el, 'lightning-combobox.position', 'pB');
        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toBe('Informe a data de efetivação.');

        change(el, 'lightning-input.effective-date', '2000-01-01');
        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toBe('A data de efetivação não pode estar no passado.');

        change(el, 'lightning-input.effective-date', '2999-01-10');
        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toBe('Informe a justificativa da promoção.');
        expect(submitRequest).not.toHaveBeenCalled();
    });

    it('envia a solicitacao e limpa o formulario', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockResolvedValue(CONTEXT);
        submitRequest.mockResolvedValue({ requestId: 'r1', requestName: 'PR-000001', warning: null });
        const el = mount();
        const toast = jest.fn();
        const submitted = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        el.addEventListener('submitted', submitted);
        await flush();
        await fillValid(el);

        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(submitRequest).toHaveBeenCalledWith({
            employeeId: 'e1',
            proposedPositionId: 'pB',
            effectiveDate: '2999-01-10',
            justification: 'Entrega acima do esperado'
        });
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
        expect(toast.mock.calls[0][0].detail.message).toContain('PR-000001');
        expect(submitted.mock.calls[0][0].detail.requestId).toBe('r1');
        expect(el.shadowRoot.querySelector('lightning-combobox.position')).toBeNull();
    });

    it('mostra o aviso do servidor no toast', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockResolvedValue(CONTEXT);
        submitRequest.mockResolvedValue({ requestId: 'r1', requestName: 'PR-000002', warning: 'Promoção fora da trilha prevista.' });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        await fillValid(el, 'pC');
        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('warning');
        expect(toast.mock.calls[0][0].detail.message).toContain('fora da trilha');
    });

    it('mostra o erro do servidor e mantem os dados', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockResolvedValue(CONTEXT);
        submitRequest.mockRejectedValue({ body: { message: 'Este colaborador já tem uma solicitação de promoção pendente.' } });
        const el = mount();
        await flush();
        await fillValid(el);
        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toContain('já tem uma solicitação');
        expect(el.shadowRoot.querySelector('lightning-combobox.position').value).toBe('pB');
    });

    it('mostra erro ao carregar os cargos', async () => {
        getTeam.mockResolvedValue(TEAM);
        getFormContext.mockRejectedValue({ body: { message: 'Você só pode solicitar promoção para alguém da sua equipe.' } });
        const el = mount();
        await flush();
        change(el, 'lightning-combobox.employee', 'e1');
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toContain('sua equipe');
        expect(el.shadowRoot.querySelector('lightning-combobox.position')).toBeNull();
    });
});
