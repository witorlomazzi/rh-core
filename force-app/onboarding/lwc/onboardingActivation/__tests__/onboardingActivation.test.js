import { createElement } from 'lwc';
import OnboardingActivation from 'c/onboardingActivation';
import getActivationContext from '@salesforce/apex/OnboardingController.getActivationContext';
import activate from '@salesforce/apex/OnboardingController.activate';

const ShowToastEventName = 'lightning__showtoast';

jest.mock('@salesforce/apex/OnboardingController.getActivationContext', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OnboardingController.activate', () => ({ default: jest.fn() }), { virtual: true });

const CONTEXT = {
    employees: [
        {
            id: 'e1',
            name: 'Bruno Lima',
            employeeNumber: 'PRE-000012',
            email: 'bruno@exemplo.com',
            hireDate: '2030-03-10',
            positionId: 'pos1',
            positionName: 'Analista',
            departmentName: 'Comercial',
            managerId: 'm1',
            managerName: 'Ana Souza'
        },
        {
            id: 'e2',
            name: 'Carla Dias',
            employeeNumber: 'PRE-000013',
            hireDate: '2030-03-20',
            positionId: null,
            managerId: null
        }
    ],
    positions: [
        { value: 'pos1', label: 'Analista' },
        { value: 'pos2', label: 'Coordenador' }
    ],
    managers: [
        { value: 'm1', label: 'Ana Souza' },
        { value: 'm2', label: 'Paulo Reis' }
    ]
};

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function mount() {
    const el = createElement('c-onboarding-activation', { is: OnboardingActivation });
    document.body.appendChild(el);
    await flush();
    return el;
}

function change(el, selector, value) {
    el.shadowRoot.querySelector(selector).dispatchEvent(new CustomEvent('change', { detail: { value } }));
}

async function select(el, employeeId) {
    change(el, 'lightning-combobox.employee', employeeId);
    await flush();
}

describe('c-onboarding-activation', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista os colaboradores em pre-admissao com a data prevista', async () => {
        getActivationContext.mockResolvedValue(CONTEXT);
        const el = await mount();

        const options = el.shadowRoot.querySelector('lightning-combobox.employee').options;
        expect(options).toHaveLength(2);
        expect(options[0].label).toBe('Bruno Lima (início previsto em 10/03/2030)');
        expect(el.shadowRoot.querySelector('lightning-input.number')).toBeNull();
        expect(el.shadowRoot.querySelector('lightning-button.submit').disabled).toBe(true);
    });

    it('preenche data, gestor e cargo ao escolher o colaborador', async () => {
        getActivationContext.mockResolvedValue(CONTEXT);
        const el = await mount();
        await select(el, 'e1');

        expect(el.shadowRoot.querySelector('.provisional').textContent).toContain('PRE-000012');
        expect(el.shadowRoot.querySelector('lightning-input.hire-date').value).toBe('2030-03-10');
        expect(el.shadowRoot.querySelector('lightning-combobox.manager').value).toBe('m1');
        expect(el.shadowRoot.querySelector('lightning-combobox.position').value).toBe('pos1');
        expect(el.shadowRoot.querySelector('lightning-combobox.position').options).toHaveLength(2);
        expect(el.shadowRoot.querySelector('lightning-combobox.manager').options).toHaveLength(2);
        expect(el.shadowRoot.querySelector('lightning-button.submit').disabled).toBe(false);
    });

    it('recusa matricula vazia, matricula provisoria e falta de cargo sem chamar o servidor', async () => {
        getActivationContext.mockResolvedValue(CONTEXT);
        const el = await mount();
        await select(el, 'e2');

        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toBe('Informe a matrícula.');

        change(el, 'lightning-input.number', 'pre-77');
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toContain('matrícula definitiva');

        change(el, 'lightning-input.number', 'VTR-0042');
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toContain('Informe o cargo');

        change(el, 'lightning-combobox.position', 'pos2');
        change(el, 'lightning-input.hire-date', '');
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toBe('Informe a data de admissão.');

        expect(activate).not.toHaveBeenCalled();
    });

    it('ativa o colaborador com os dados informados e recarrega a lista', async () => {
        getActivationContext.mockResolvedValue(CONTEXT);
        activate.mockResolvedValue();
        const el = await mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await select(el, 'e1');

        change(el, 'lightning-input.number', '  VTR-0042 ');
        change(el, 'lightning-input.hire-date', '2030-03-15');
        change(el, 'lightning-combobox.manager', 'm2');
        change(el, 'lightning-combobox.position', 'pos2');
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        await flush();

        expect(activate).toHaveBeenCalledWith({
            employeeId: 'e1',
            employeeNumber: 'VTR-0042',
            hireDate: '2030-03-15',
            managerId: 'm2',
            positionId: 'pos2'
        });
        expect(toast).toHaveBeenCalledTimes(1);
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
        expect(getActivationContext).toHaveBeenCalledTimes(2);
        expect(el.shadowRoot.querySelector('lightning-input.number')).toBeNull();
    });

    it('mostra o erro do servidor no formulario e mantem os dados', async () => {
        getActivationContext.mockResolvedValue(CONTEXT);
        activate.mockRejectedValue({ body: { message: 'Já existe um colaborador com esta matrícula.' } });
        const el = await mount();
        await select(el, 'e1');

        change(el, 'lightning-input.number', 'VTR-0001');
        el.shadowRoot.querySelector('lightning-button.submit').click();
        await flush();
        await flush();

        expect(el.shadowRoot.querySelector('.form-error').textContent).toBe('Já existe um colaborador com esta matrícula.');
        expect(el.shadowRoot.querySelector('lightning-input.number').value).toBe('VTR-0001');
        expect(getActivationContext).toHaveBeenCalledTimes(1);
    });

    it('mostra o estado vazio quando ninguem esta em pre-admissao', async () => {
        getActivationContext.mockResolvedValue({ employees: [], positions: [], managers: [] });
        const el = await mount();

        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
        expect(el.shadowRoot.querySelector('lightning-combobox.employee')).toBeNull();
    });

    it('mostra o erro de carregamento para quem nao e do RH', async () => {
        getActivationContext.mockRejectedValue({ body: { message: 'Somente o RH pode fazer esta operação.' } });
        const el = await mount();

        expect(el.shadowRoot.querySelector('.load-error').textContent).toContain('Somente o RH');
        expect(el.shadowRoot.querySelector('lightning-combobox.employee')).toBeNull();
    });
});
