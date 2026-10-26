import { createElement } from 'lwc';
import CoreApprovalInbox from 'c/coreApprovalInbox';
import getPending from '@salesforce/apex/ApprovalController.getPending';
import decide from '@salesforce/apex/ApprovalController.decide';
const ShowToastEventName = 'lightning__showtoast';

jest.mock('@salesforce/apex/ApprovalController.getPending', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ApprovalController.decide', () => ({ default: jest.fn() }), { virtual: true });

const ITEMS = [
    {
        stepId: 's1',
        stepName: 'AP-000001',
        stepOrder: 1,
        approverType: 'Direct_Manager',
        requestType: 'Leave',
        requestId: 'r1',
        requestName: 'FE-000001',
        employeeName: 'Bruno Lima'
    },
    {
        stepId: 's2',
        stepName: 'AP-000002',
        stepOrder: 2,
        approverType: 'HR_Team',
        requestType: 'Promotion',
        requestId: 'r2',
        requestName: null,
        employeeName: null
    }
];

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount() {
    const el = createElement('c-core-approval-inbox', { is: CoreApprovalInbox });
    document.body.appendChild(el);
    return el;
}

describe('c-core-approval-inbox', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista as pendencias com tipo e etapa', async () => {
        getPending.mockResolvedValue(ITEMS);
        const el = mount();
        await flush();
        const rows = el.shadowRoot.querySelectorAll('.approval-item');
        expect(rows.length).toBe(2);
        expect(rows[0].textContent).toContain('Férias');
        expect(rows[0].textContent).toContain('FE-000001');
        expect(rows[0].textContent).toContain('Etapa 1: Gestor direto');
        expect(rows[1].textContent).toContain('AP-000002');
        expect(rows[1].textContent).toContain('sem resumo');
        expect(el.shadowRoot.querySelector('.count').textContent).toBe('2 pendentes');
    });

    it('mostra estado vazio', async () => {
        getPending.mockResolvedValue([]);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
    });

    it('aprova e recarrega', async () => {
        getPending.mockResolvedValueOnce(ITEMS).mockResolvedValueOnce([ITEMS[1]]);
        decide.mockResolvedValue();
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(decide).toHaveBeenCalledWith({ stepId: 's1', approve: true, comments: null });
        expect(toast).toHaveBeenCalled();
        expect(el.shadowRoot.querySelectorAll('.approval-item').length).toBe(1);
    });

    it('exige comentario para rejeitar', async () => {
        getPending.mockResolvedValue(ITEMS);
        decide.mockResolvedValue();
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('lightning-button.reject').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.confirm-reject').click();
        await flush();
        expect(decide).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.comment-error')).not.toBeNull();

        const textarea = el.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Fechamento do mês';
        textarea.dispatchEvent(new CustomEvent('change'));
        el.shadowRoot.querySelector('lightning-button.confirm-reject').click();
        await flush();
        expect(decide).toHaveBeenCalledWith({ stepId: 's1', approve: false, comments: 'Fechamento do mês' });
    });

    it('cancela a rejeicao', async () => {
        getPending.mockResolvedValue(ITEMS);
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('lightning-button.reject').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button.cancel-reject').click();
        await flush();
        expect(el.shadowRoot.querySelector('.reject-box')).toBeNull();
    });

    it('mostra erro do servidor ao decidir', async () => {
        getPending.mockResolvedValue(ITEMS);
        decide.mockRejectedValue({ body: { message: 'Você não é o aprovador desta etapa.' } });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(ShowToastEventName, toast);
        await flush();
        el.shadowRoot.querySelector('lightning-button.approve').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('aprovador');
    });

    it('mostra erro ao carregar', async () => {
        getPending.mockRejectedValue(new Error('Sem acesso'));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem acesso');
    });

    it('atualiza pela acao do cartao', async () => {
        getPending.mockResolvedValue([]);
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('lightning-button-icon').click();
        await flush();
        expect(getPending).toHaveBeenCalledTimes(2);
    });
});
