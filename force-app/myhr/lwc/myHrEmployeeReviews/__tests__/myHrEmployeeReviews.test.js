/* eslint-disable @lwc/lwc/no-async-operation */
import { createElement } from 'lwc';
import MyHrEmployeeReviews from 'c/myHrEmployeeReviews';
import getEmployeeReviews from '@salesforce/apex/MyHrController.getEmployeeReviews';

jest.mock('@salesforce/apex/MyHrController.getEmployeeReviews', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount() {
    const el = createElement('c-my-hr-employee-reviews', { is: MyHrEmployeeReviews });
    el.recordId = 'e1';
    document.body.appendChild(el);
    return el;
}

describe('c-my-hr-employee-reviews', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista as avaliacoes com situacao e nota final liberada', async () => {
        getEmployeeReviews.mockResolvedValue([
            { id: 'r1', cycleName: 'Ciclo 2026', status: 'Liberada', finalRating: 4, releasedDate: '2026-10-20T12:00:00.000Z' },
            { id: 'r2', cycleName: 'Ciclo 2025', status: 'Pendente', finalRating: null, releasedDate: null }
        ]);
        const el = mount();
        await flush();
        expect(getEmployeeReviews).toHaveBeenCalledWith({ employeeId: 'e1' });
        const items = el.shadowRoot.querySelectorAll('.review');
        expect(items.length).toBe(2);
        expect(items[0].querySelector('.cycle-name').textContent).toBe('Ciclo 2026');
        expect(items[0].querySelector('.slds-badge').textContent).toBe('Liberada');
        expect(items[0].querySelector('.rating').textContent).toBe('Nota final: 4');
        expect(items[0].querySelector('.released').textContent).toBe('Liberada em 20/10/2026');
        expect(items[1].querySelector('.rating')).toBeNull();
    });

    it('sem avaliacoes visiveis mostra mensagem vazia', async () => {
        getEmployeeReviews.mockResolvedValue([]);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty').textContent).toBe('Nenhuma avaliação disponível para você ver.');
    });

    it('erro do servidor mostra o alerta', async () => {
        getEmployeeReviews.mockRejectedValue({ body: { message: 'Sem acesso.' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error h2').textContent).toBe('Sem acesso.');
        expect(el.shadowRoot.querySelector('.review')).toBeNull();
    });
});
