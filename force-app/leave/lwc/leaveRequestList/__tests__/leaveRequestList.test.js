import { createElement } from 'lwc';
import LeaveRequestList from 'c/leaveRequestList';
import getRequests from '@salesforce/apex/LeaveRequestController.getRequests';
import cancelRequest from '@salesforce/apex/LeaveRequestController.cancelRequest';
import { subscribe, publish } from 'lightning/messageService';

const ShowToastEventName = 'lightning__showtoast';

jest.mock('@salesforce/apex/LeaveRequestController.getRequests', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/LeaveRequestController.cancelRequest', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/messageChannel/LeaveChanged__c', () => ({ default: 'LeaveChanged__c' }), { virtual: true });

const REQUESTS = [
    {
        id: 'r1',
        name: 'FE-000001',
        status: 'Pendente',
        statusLabel: 'Pendente',
        awaitingLabel: 'Aguardando o gestor',
        startDate: '2026-05-04',
        endDate: '2026-05-17',
        days: 14,
        soldDays: 0,
        notes: 'Viagem em família',
        teamConflictWarning: 'Coincide com as férias de 1 colega da mesma equipe no período.',
        canCancel: true
    },
    {
        id: 'r2',
        name: 'FE-000002',
        status: 'Aprovado',
        statusLabel: 'Aprovado',
        awaitingLabel: null,
        startDate: '2026-08-03',
        endDate: '2026-08-22',
        days: 20,
        soldDays: 10,
        notes: null,
        teamConflictWarning: null,
        canCancel: false
    }
];

// Espera a fila de microtarefas e renderizacao do componente nos testes.
// eslint-disable-next-line @lwc/lwc/no-async-operation
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount(props = {}) {
    const el = createElement('c-leave-request-list', { is: LeaveRequestList });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

describe('c-leave-request-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista as solicitacoes com situacao, dias e etapa atual', async () => {
        getRequests.mockResolvedValue(REQUESTS);
        const el = mount();
        await flush();
        const items = el.shadowRoot.querySelectorAll('.request');
        expect(items.length).toBe(2);
        expect(el.shadowRoot.querySelector('.count').textContent).toBe('2 solicitações');
        expect(items[0].querySelector('.request-range').textContent).toBe('04/05/2026 a 17/05/2026');
        expect(items[0].querySelector('.request-name').textContent).toBe('FE-000001');
        expect(items[0].querySelector('.slds-badge').className).toContain('slds-theme_warning');
        expect(items[0].querySelector('.request-days').textContent).toBe('14 dias de gozo');
        expect(items[0].querySelector('.awaiting').textContent).toContain('Aguardando o gestor');
        expect(items[0].querySelector('.conflict').textContent).toContain('1 colega');
        expect(items[0].querySelector('.notes').textContent).toBe('Viagem em família');
        expect(items[1].querySelector('.request-days').textContent).toBe('20 dias de gozo e 10 dias vendidos');
        expect(items[1].querySelector('.awaiting')).toBeNull();
        expect(items[1].querySelector('.ask-cancel')).toBeNull();
        expect(getRequests).toHaveBeenCalledWith({ employeeId: null });
    });

    it('usa o registro da pagina de colaborador', async () => {
        getRequests.mockResolvedValue([]);
        mount({ recordId: 'e7' });
        await flush();
        expect(getRequests).toHaveBeenCalledWith({ employeeId: 'e7' });
    });

    it('mostra estado vazio e erro', async () => {
        getRequests.mockResolvedValueOnce([]);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('Nenhuma solicitação');

        getRequests.mockRejectedValueOnce(new Error('Sem acesso'));
        el.shadowRoot.querySelector('lightning-button-icon.refresh').click();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem acesso');
    });

    it('pede confirmacao antes de cancelar e permite manter', async () => {
        getRequests.mockResolvedValue(REQUESTS);
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('lightning-button.ask-cancel').click();
        await flush();
        expect(el.shadowRoot.querySelector('.confirm-box')).not.toBeNull();
        expect(cancelRequest).not.toHaveBeenCalled();
        el.shadowRoot.querySelector('lightning-button.keep').click();
        await flush();
        expect(el.shadowRoot.querySelector('.confirm-box')).toBeNull();
        expect(cancelRequest).not.toHaveBeenCalled();
    });

    it('cancela, avisa os outros componentes e recarrega', async () => {
        getRequests.mockResolvedValueOnce(REQUESTS).mockResolvedValueOnce([REQUESTS[1]]);
        cancelRequest.mockResolvedValue();
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        el.shadowRoot.querySelector('lightning-button.ask-cancel').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.confirm-cancel').click();
        await flush();
        expect(cancelRequest).toHaveBeenCalledWith({ requestId: 'r1' });
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
        expect(publish).toHaveBeenCalledWith(undefined, 'LeaveChanged__c', { employeeId: null });
        expect(el.shadowRoot.querySelectorAll('.request').length).toBe(1);
    });

    it('mostra o erro do servidor ao cancelar', async () => {
        getRequests.mockResolvedValue(REQUESTS);
        cancelRequest.mockRejectedValue({ body: { message: 'Somente quem fez a solicitação pode cancelá-la.' } });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        el.shadowRoot.querySelector('lightning-button.ask-cancel').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.confirm-cancel').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('Somente quem fez');
        expect(publish).not.toHaveBeenCalled();
    });

    it('recarrega pelo metodo publico e pela mensagem de alteracao', async () => {
        getRequests.mockResolvedValue([]);
        const el = mount();
        await flush();
        el.refresh();
        await flush();
        expect(getRequests).toHaveBeenCalledTimes(2);
        subscribe.mock.calls[0][2]({ employeeId: 'e1' });
        await flush();
        expect(getRequests).toHaveBeenCalledTimes(3);
    });
});
