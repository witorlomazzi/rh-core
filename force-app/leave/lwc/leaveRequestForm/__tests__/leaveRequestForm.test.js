import { createElement } from 'lwc';
import LeaveRequestForm from 'c/leaveRequestForm';
import getBalance from '@salesforce/apex/LeaveRequestController.getBalance';
import checkRules from '@salesforce/apex/LeaveRequestController.checkRules';
import submitRequest from '@salesforce/apex/LeaveRequestController.submitRequest';
import { publish } from 'lightning/messageService';

const ShowToastEventName = 'lightning__showtoast';

jest.mock('@salesforce/apex/LeaveRequestController.getBalance', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/LeaveRequestController.checkRules', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/LeaveRequestController.submitRequest', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/messageChannel/LeaveChanged__c', () => ({ default: 'LeaveChanged__c' }), { virtual: true });

const PERIOD = {
    id: 'p1',
    startDate: '2025-03-10',
    endDate: '2026-03-09',
    balanceDays: 30,
    canRequest: true
};
const PERIOD_B = { ...PERIOD, id: 'p2', startDate: '2024-03-10', endDate: '2025-03-09', balanceDays: 12 };
const BLOCKED_PERIOD = { ...PERIOD, id: 'p3', canRequest: false };

const RULES_OK = [
    { code: 'PERIODO_NAO_ADQUIRIDO', title: 'Período aquisitivo concluído', level: 'ok', message: null },
    { code: 'ANTECEDENCIA', title: 'Antecedência mínima', level: 'ok', message: null }
];
const CHECK_OK = { rules: RULES_OK, hasBlocking: false, hasWarning: false, canSubmit: true, isHr: false };
const CHECK_WARNING = {
    rules: [
        ...RULES_OK,
        { code: 'ABONO_PRAZO', title: 'Prazo do abono', level: 'warning', message: 'O abono pedido fora do prazo depende de concordância da empresa.' }
    ],
    hasBlocking: false,
    hasWarning: true,
    canSubmit: true
};
const CHECK_BLOCKED = {
    rules: [
        { code: 'ANTECEDENCIA', title: 'Antecedência mínima', level: 'blocked', message: 'O início precisa ter pelo menos 30 dias de antecedência a partir de hoje.' },
        { code: 'MINIMO_FRACAO', title: 'Tamanho mínimo da fração', level: 'ok', message: null }
    ],
    hasBlocking: true,
    hasWarning: false,
    canSubmit: false
};

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount(props = {}) {
    const el = createElement('c-leave-request-form', { is: LeaveRequestForm });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

function setField(el, selector, value) {
    const field = el.shadowRoot.querySelector(selector);
    field.value = value;
    field.dispatchEvent(new CustomEvent('change'));
}

async function fill(el, { start = '2026-05-04', days = '14', sold = '' } = {}) {
    setField(el, '.field-start', start);
    setField(el, '.field-days', days);
    if (sold) {
        setField(el, '.field-sold', sold);
    }
    await flush();
}

describe('c-leave-request-form', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('oferece so os periodos que permitem solicitar e preseleciona quando ha um', async () => {
        getBalance.mockResolvedValue({ isHr: false, periods: [PERIOD, BLOCKED_PERIOD] });
        const el = mount();
        await flush();
        const combo = el.shadowRoot.querySelector('.field-period');
        expect(combo.options).toEqual([{ value: 'p1', label: '10/03/2025 a 09/03/2026 (saldo de 30 dias)' }]);
        expect(combo.value).toBe('p1');
        expect(getBalance).toHaveBeenCalledWith({ employeeId: null });
    });

    it('nao preseleciona com varios periodos e respeita o periodo informado pelo pai', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD, PERIOD_B] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.field-period').value).toBeFalsy();

        const another = mount({ periodId: 'p2' });
        await flush();
        const combos = another.shadowRoot.querySelectorAll('.field-period');
        expect(combos[0].value).toBe('p2');
    });

    it('mostra aviso quando nao ha periodo disponivel', async () => {
        getBalance.mockResolvedValue({ periods: [BLOCKED_PERIOD] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.no-periods').textContent).toContain('Nenhum período aquisitivo disponível');
        expect(el.shadowRoot.querySelector('lightning-button.check')).toBeNull();
    });

    it('mostra erro ao carregar', async () => {
        getBalance.mockRejectedValue({ body: { message: 'Sem acesso' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem acesso');
    });

    it('so habilita a verificacao com periodo, inicio e dias', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        const el = mount();
        await flush();
        const check = el.shadowRoot.querySelector('lightning-button.check');
        expect(check.disabled).toBe(true);
        await fill(el);
        expect(el.shadowRoot.querySelector('lightning-button.check').disabled).toBe(false);
        expect(el.shadowRoot.querySelector('lightning-button.submit').disabled).toBe(true);
    });

    it('verifica as regras, mostra cada uma com icone e habilita o envio', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_WARNING);
        const el = mount();
        await flush();
        await fill(el, { sold: '5' });
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();

        expect(checkRules).toHaveBeenCalledWith({
            periodId: 'p1',
            startDate: '2026-05-04',
            days: 14,
            soldDays: 5,
            allowNoticeException: false
        });
        const rules = el.shadowRoot.querySelectorAll('.rule');
        expect(rules.length).toBe(3);
        expect(rules[0].querySelector('lightning-icon').iconName).toBe('utility:success');
        expect(rules[2].querySelector('lightning-icon').iconName).toBe('utility:warning');
        expect(rules[2].textContent).toContain('depende de concordância da empresa');
        expect(el.shadowRoot.querySelector('.summary').textContent).toContain('leia os avisos');
        expect(el.shadowRoot.querySelector('lightning-button.submit').disabled).toBe(false);
    });

    it('bloqueia o envio quando ha regra impeditiva', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_BLOCKED);
        const el = mount();
        await flush();
        await fill(el);
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        const rules = el.shadowRoot.querySelectorAll('.rule');
        expect(rules[0].querySelector('lightning-icon').iconName).toBe('utility:error');
        expect(rules[0].dataset.level).toBe('blocked');
        expect(rules[0].textContent).toContain('30 dias de antecedência');
        expect(el.shadowRoot.querySelector('.summary').textContent).toContain('regras impeditivas');
        expect(el.shadowRoot.querySelector('lightning-button.submit').disabled).toBe(true);
    });

    it('mostra resumo de sucesso quando tudo passa', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_OK);
        const el = mount();
        await flush();
        await fill(el);
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        expect(el.shadowRoot.querySelector('.summary').textContent).toContain('Todas as regras foram cumpridas');
    });

    it('invalida a verificacao quando qualquer campo muda', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_OK);
        const el = mount();
        await flush();
        await fill(el);
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        expect(el.shadowRoot.querySelector('lightning-button.submit').disabled).toBe(false);
        setField(el, '.field-days', '10');
        await flush();
        expect(el.shadowRoot.querySelector('.result')).toBeNull();
        expect(el.shadowRoot.querySelector('lightning-button.submit').disabled).toBe(true);
    });

    it('mostra erro do servidor ao verificar', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockRejectedValue({ body: { message: 'Período aquisitivo não encontrado ou sem acesso.' } });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        await fill(el);
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('não encontrado');
    });

    it('envia para aprovacao, avisa os outros componentes e limpa o formulario', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_OK);
        submitRequest.mockResolvedValue({ ...CHECK_OK, submitted: true, requestId: 'r1' });
        const el = mount({ recordId: 'e1' });
        const toast = jest.fn();
        const submitted = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        el.addEventListener('submitted', submitted);
        await flush();
        await fill(el);
        setField(el, '.field-notes', 'Viagem');
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();

        expect(submitRequest).toHaveBeenCalledWith({
            periodId: 'p1',
            startDate: '2026-05-04',
            days: 14,
            soldDays: 0,
            allowNoticeException: false,
            notes: 'Viagem'
        });
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
        expect(submitted.mock.calls[0][0].detail).toEqual({ requestId: 'r1' });
        expect(publish).toHaveBeenCalledWith(undefined, 'LeaveChanged__c', { employeeId: 'e1' });
        expect(el.shadowRoot.querySelector('.field-start').value).toBeUndefined();
        expect(el.shadowRoot.querySelector('.result')).toBeNull();
        expect(getBalance).toHaveBeenCalledTimes(2);
    });

    it('mostra os bloqueios quando o servidor recusa o envio', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_OK);
        submitRequest.mockResolvedValue({ ...CHECK_BLOCKED, submitted: false });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        await fill(el);
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(el.shadowRoot.querySelector('.summary').textContent).toContain('regras impeditivas');
        expect(publish).not.toHaveBeenCalled();
    });

    it('mostra erro do servidor ao enviar', async () => {
        getBalance.mockResolvedValue({ periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_OK);
        submitRequest.mockRejectedValue({ body: { message: 'Somente o colaborador ou o RH pode solicitar férias para este período.' } });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        await fill(el);
        el.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.message).toContain('colaborador ou o RH');
    });

    it('mostra a excecao de antecedencia so para o RH e a envia', async () => {
        getBalance.mockResolvedValue({ isHr: false, periods: [PERIOD] });
        const colaborador = mount();
        await flush();
        expect(colaborador.shadowRoot.querySelector('.field-exception')).toBeNull();

        getBalance.mockResolvedValue({ isHr: true, periods: [PERIOD] });
        checkRules.mockResolvedValue(CHECK_OK);
        const rh = mount();
        await flush();
        const boxes = document.body.querySelectorAll('c-leave-request-form');
        const rhEl = boxes[boxes.length - 1];
        const box = rhEl.shadowRoot.querySelector('.field-exception');
        expect(box).not.toBeNull();
        await fill(rh);
        box.checked = true;
        box.dispatchEvent(new CustomEvent('change'));
        await flush();
        rhEl.shadowRoot.querySelector('lightning-button.check').click();
        await flush();
        expect(checkRules).toHaveBeenCalledWith(expect.objectContaining({ allowNoticeException: true }));
    });
});
