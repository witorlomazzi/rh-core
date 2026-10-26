import { createElement } from 'lwc';
import PositionHistoryTimeline from 'c/positionHistoryTimeline';
import getHistory from '@salesforce/apex/PromotionRequestController.getHistory';

jest.mock('@salesforce/apex/PromotionRequestController.getHistory', () => ({ default: jest.fn() }), { virtual: true });

const ENTRIES = [
    {
        id: 'h2',
        positionName: 'Analista Pleno',
        departmentName: 'Comercial',
        startDate: '2026-10-01',
        endDate: null,
        reason: 'Promocao',
        reasonLabel: 'Promoção',
        salary: 6000,
        isCurrent: true
    },
    {
        id: 'h1',
        positionName: 'Analista Junior',
        departmentName: 'Comercial',
        startDate: '2024-03-04',
        endDate: '2026-09-30',
        reason: 'Admissao',
        reasonLabel: 'Admissão',
        salary: 4000,
        isCurrent: false
    }
];

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount(props = {}) {
    const el = createElement('c-position-history-timeline', { is: PositionHistoryTimeline });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

describe('c-position-history-timeline', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra cargo, departamento, periodo e motivo, do mais recente para o mais antigo', async () => {
        getHistory.mockResolvedValue({ salaryVisible: false, entries: ENTRIES.map((e) => ({ ...e, salary: null })) });
        const el = mount();
        await flush();
        const items = el.shadowRoot.querySelectorAll('.timeline-item');
        expect(items.length).toBe(2);
        expect(items[0].querySelector('.position-name').textContent).toBe('Analista Pleno');
        expect(items[0].querySelector('.department-name').textContent).toBe('Comercial');
        expect(items[0].querySelector('.period').textContent).toBe('Desde 01/10/2026');
        expect(items[0].querySelector('.reason').textContent).toBe('Promoção');
        expect(items[0].querySelector('.current')).not.toBeNull();
        expect(items[1].querySelector('.period').textContent).toBe('04/03/2024 a 30/09/2026');
        expect(items[1].querySelector('.current')).toBeNull();
    });

    it('nao mostra salario quando o servidor nao o envia', async () => {
        getHistory.mockResolvedValue({ salaryVisible: false, entries: ENTRIES.map((e) => ({ ...e, salary: null })) });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.salary')).toBeNull();
        expect(el.shadowRoot.textContent).not.toContain('Salário');
    });

    it('nao mostra salario sem acesso ao campo mesmo se o valor vier no payload', async () => {
        getHistory.mockResolvedValue({ salaryVisible: false, entries: ENTRIES });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.salary')).toBeNull();
    });

    it('mostra o salario para quem tem acesso ao campo', async () => {
        getHistory.mockResolvedValue({ salaryVisible: true, entries: ENTRIES });
        const el = mount();
        await flush();
        const salaries = el.shadowRoot.querySelectorAll('.salary');
        expect(salaries.length).toBe(2);
        expect(salaries[0].textContent).toMatch(/6\.000,00/);
        expect(salaries[1].textContent).toMatch(/4\.000,00/);
    });

    it('usa o registro da pagina como colaborador', async () => {
        getHistory.mockResolvedValue({ salaryVisible: false, entries: [] });
        mount({ recordId: 'e1' });
        await flush();
        expect(getHistory).toHaveBeenCalledWith({ employeeId: 'e1' });
    });

    it('prefere o employeeId informado e, sem nenhum, pede o historico do proprio usuario', async () => {
        getHistory.mockResolvedValue({ salaryVisible: false, entries: [] });
        mount({ recordId: 'e1', employeeId: 'e9' });
        await flush();
        expect(getHistory).toHaveBeenLastCalledWith({ employeeId: 'e9' });
        mount();
        await flush();
        expect(getHistory).toHaveBeenLastCalledWith({ employeeId: null });
    });

    it('mostra estado vazio', async () => {
        getHistory.mockResolvedValue({ salaryVisible: false, entries: [] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
        expect(el.shadowRoot.querySelector('.timeline')).toBeNull();
    });

    it('mostra erro do servidor', async () => {
        getHistory.mockRejectedValue({ body: { message: 'Não foi possível concluir a operação.' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.load-error').textContent).toContain('Não foi possível');
    });
});
