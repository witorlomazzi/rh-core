import { createElement } from 'lwc';
import LeaveBalanceCard from 'c/leaveBalanceCard';
import getBalance from '@salesforce/apex/LeaveRequestController.getBalance';
import { subscribe, unsubscribe } from 'lightning/messageService';

jest.mock('@salesforce/apex/LeaveRequestController.getBalance', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/messageChannel/LeaveChanged__c', () => ({ default: 'LeaveChanged__c' }), { virtual: true });

const PERIODS = [
    {
        id: 'p2',
        name: 'PA-000002',
        startDate: '2026-03-10',
        endDate: '2027-03-09',
        concessionDeadline: '2028-03-09',
        daysToDeadline: 500,
        entitledDays: 30,
        daysTaken: 0,
        daysSold: 0,
        daysPending: 0,
        balanceDays: 30,
        status: 'Em_Aquisicao',
        statusLabel: 'Em aquisição',
        canRequest: false
    },
    {
        id: 'p1',
        name: 'PA-000001',
        startDate: '2025-03-10',
        endDate: '2026-03-09',
        concessionDeadline: '2027-03-09',
        daysToDeadline: 40,
        entitledDays: 30,
        daysTaken: 10,
        daysSold: 5,
        daysPending: 5,
        balanceDays: 10,
        status: 'Prazo_Proximo',
        statusLabel: 'Prazo próximo',
        canRequest: true
    },
    {
        id: 'p0',
        name: 'PA-000000',
        startDate: '2024-03-10',
        endDate: '2025-03-09',
        concessionDeadline: '2025-12-01',
        daysToDeadline: -20,
        entitledDays: 30,
        daysTaken: 0,
        daysSold: 0,
        daysPending: 0,
        balanceDays: 30,
        status: 'Disponivel',
        statusLabel: 'Disponível',
        canRequest: true
    },
    {
        id: 'px',
        name: 'PA-000009',
        startDate: '2020-03-10',
        endDate: '2021-03-09',
        concessionDeadline: '2022-03-09',
        daysToDeadline: -2000,
        entitledDays: 0,
        daysTaken: 0,
        daysSold: 0,
        daysPending: 0,
        balanceDays: 0,
        status: 'Perdido',
        statusLabel: 'Perdido',
        canRequest: false
    }
];

// Espera a fila de microtarefas e renderizacao do componente nos testes.
// eslint-disable-next-line @lwc/lwc/no-async-operation
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount(props = {}) {
    const el = createElement('c-leave-balance-card', { is: LeaveBalanceCard });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

describe('c-leave-balance-card', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista os periodos com situacao, intervalo e totais', async () => {
        getBalance.mockResolvedValue({ employeeId: 'e1', employeeName: 'Ana', periods: PERIODS });
        const el = mount();
        await flush();
        const items = el.shadowRoot.querySelectorAll('.period');
        expect(items.length).toBe(4);
        expect(items[0].querySelector('.period-range').textContent).toBe('10/03/2026 a 09/03/2027');
        expect(items[0].querySelector('.slds-badge').textContent).toBe('Em aquisição');
        expect(items[1].querySelector('.entitled').textContent).toBe('30');
        expect(items[1].querySelector('.taken').textContent).toBe('10');
        expect(items[1].querySelector('.sold').textContent).toBe('5');
        expect(items[1].querySelector('.pending').textContent).toBe('5');
        expect(items[1].querySelector('.balance').textContent).toBe('10');
        expect(items[1].querySelector('.slds-badge').className).toContain('slds-theme_warning');
        expect(getBalance).toHaveBeenCalledWith({ employeeId: null });
    });

    it('mostra o prazo concessivo e destaca quando esta proximo ou vencido', async () => {
        getBalance.mockResolvedValue({ employeeId: 'e1', periods: PERIODS });
        const el = mount();
        await flush();
        const items = el.shadowRoot.querySelectorAll('.period');
        expect(items[0].querySelector('.deadline').textContent).toContain('O período aquisitivo termina em 09/03/2027');
        expect(items[0].querySelector('.deadline').className).not.toContain('slds-text-color_error');
        expect(items[1].querySelector('.deadline').textContent).toContain('09/03/2027 (40 dias restantes)');
        expect(items[1].querySelector('.deadline').className).toContain('slds-text-color_error');
        expect(items[2].querySelector('.deadline').textContent).toContain('Prazo concessivo vencido');
        expect(items[3].querySelector('.deadline')).toBeNull();
    });

    it('calcula a barra de uso com gozados, vendidos e pendentes', async () => {
        getBalance.mockResolvedValue({ employeeId: 'e1', periods: PERIODS });
        const el = mount();
        await flush();
        const bars = el.shadowRoot.querySelectorAll('lightning-progress-bar');
        expect(bars[0].value).toBe(0);
        expect(bars[1].value).toBe(67);
        expect(el.shadowRoot.querySelectorAll('.period')[1].textContent).toContain('20 de 30 dias usados ou reservados');
    });

    it('usa o registro quando esta numa pagina de colaborador', async () => {
        getBalance.mockResolvedValue({ employeeId: 'e9', employeeName: 'Bruno Lima', periods: [PERIODS[1]] });
        const el = mount({ recordId: 'e9' });
        await flush();
        expect(getBalance).toHaveBeenCalledWith({ employeeId: 'e9' });
        expect(el.shadowRoot.querySelector('lightning-card').title).toBe('Saldo de férias de Bruno Lima');
    });

    it('oferece solicitar so quando o periodo permite e avisa o pai', async () => {
        getBalance.mockResolvedValue({ employeeId: 'e1', periods: PERIODS });
        const el = mount();
        const handler = jest.fn();
        el.addEventListener('requestleave', handler);
        await flush();
        const buttons = el.shadowRoot.querySelectorAll('lightning-button.request');
        expect(buttons.length).toBe(2);
        buttons[0].click();
        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail).toEqual({ periodId: 'p1' });
    });

    it('mostra estado vazio com a mensagem do servidor', async () => {
        getBalance.mockResolvedValue({ periods: [], emptyMessage: 'Seu usuário ainda não está vinculado a um colaborador.' });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('não está vinculado');
        expect(el.shadowRoot.querySelectorAll('.period').length).toBe(0);
    });

    it('mostra estado vazio padrao e erro de carregamento', async () => {
        getBalance.mockResolvedValueOnce({ periods: [] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('Nenhum período aquisitivo encontrado.');

        getBalance.mockRejectedValueOnce({ body: { message: 'Sem acesso ao objeto' } });
        el.shadowRoot.querySelector('lightning-button-icon.refresh').click();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem acesso ao objeto');
        expect(el.shadowRoot.querySelector('.empty')).toBeNull();
    });

    it('recarrega pelo metodo publico e pela mensagem de alteracao', async () => {
        getBalance.mockResolvedValue({ employeeId: 'e1', periods: [PERIODS[0]] });
        const el = mount();
        await flush();
        expect(subscribe).toHaveBeenCalledTimes(1);
        el.refresh();
        await flush();
        expect(getBalance).toHaveBeenCalledTimes(2);

        const listener = subscribe.mock.calls[0][2];
        listener({ employeeId: 'e1' });
        await flush();
        expect(getBalance).toHaveBeenCalledTimes(3);
    });

    it('cancela a assinatura ao sair da pagina', async () => {
        subscribe.mockReturnValue({ id: 'sub1' });
        getBalance.mockResolvedValue({ employeeId: 'e1', periods: [] });
        const el = mount();
        await flush();
        document.body.removeChild(el);
        expect(unsubscribe).toHaveBeenCalledWith({ id: 'sub1' });
    });
});
