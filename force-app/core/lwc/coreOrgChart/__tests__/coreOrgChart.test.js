import { createElement } from 'lwc';
import CoreOrgChart from 'c/coreOrgChart';
import getInitial from '@salesforce/apex/OrgChartController.getInitial';
import getChildren from '@salesforce/apex/OrgChartController.children';
import searchEmployees from '@salesforce/apex/OrgChartController.search';

jest.mock('@salesforce/apex/OrgChartController.getInitial', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OrgChartController.children', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/OrgChartController.search', () => ({ default: jest.fn() }), { virtual: true });

const node = (id, name, reports = 0) => ({
    id,
    name,
    initials: name.slice(0, 2).toUpperCase(),
    positionName: 'Analista',
    departmentName: 'Comercial',
    directReports: reports,
    hasChildren: reports > 0
});

const VIEW = {
    isHr: false,
    manager: node('m1', 'Gestora Ana', 3),
    focus: [node('e1', 'Bruno Lima', 1)],
    reports: [node('e4', 'Carla Dias', 2)],
    emptyMessage: null
};

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount(recordId) {
    const el = createElement('c-core-org-chart', { is: CoreOrgChart });
    if (recordId) {
        el.recordId = recordId;
    }
    document.body.appendChild(el);
    return el;
}

describe('c-core-org-chart', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        jest.useRealTimers();
    });

    it('carrega gestor, colaborador e subordinados', async () => {
        getInitial.mockResolvedValue(VIEW);
        const el = mount('e1');
        await flush();
        expect(getInitial).toHaveBeenCalledWith({ employeeId: 'e1' });
        expect(el.shadowRoot.querySelector('.manager-card').textContent).toContain('Gestora Ana');
        const items = el.shadowRoot.querySelectorAll('li[role="treeitem"]');
        expect(items.length).toBe(2);
        expect(items[0].getAttribute('aria-level')).toBe('1');
        expect(items[0].getAttribute('aria-expanded')).toBe('true');
        expect(items[1].textContent).toContain('Carla Dias');
        expect(items[1].getAttribute('aria-expanded')).toBe('false');
    });

    it('expande e recolhe a equipe sob demanda', async () => {
        getInitial.mockResolvedValue(VIEW);
        getChildren.mockResolvedValue([node('e9', 'Diego Reis')]);
        const el = mount();
        await flush();
        const toggles = el.shadowRoot.querySelectorAll('button.toggle');
        toggles[1].click();
        await flush();
        expect(getChildren).toHaveBeenCalledWith({ employeeId: 'e4' });
        let items = el.shadowRoot.querySelectorAll('li[role="treeitem"]');
        expect(items.length).toBe(3);
        expect(items[2].getAttribute('aria-level')).toBe('3');

        el.shadowRoot.querySelectorAll('button.toggle')[1].click();
        await flush();
        items = el.shadowRoot.querySelectorAll('li[role="treeitem"]');
        expect(items.length).toBe(2);
        el.shadowRoot.querySelectorAll('button.toggle')[1].click();
        await flush();
        expect(getChildren).toHaveBeenCalledTimes(1);
        expect(el.shadowRoot.querySelectorAll('li[role="treeitem"]').length).toBe(3);
    });

    it('busca por nome com espera e mostra resultados', async () => {
        jest.useFakeTimers();
        getInitial.mockResolvedValue(VIEW);
        searchEmployees.mockResolvedValue([node('e2', 'Eva Souza')]);
        const el = mount();
        await Promise.resolve();
        const input = el.shadowRoot.querySelector('lightning-input');
        input.value = 'e';
        input.dispatchEvent(new CustomEvent('change'));
        jest.runAllTimers();
        expect(searchEmployees).not.toHaveBeenCalled();
        input.value = 'Eva';
        input.dispatchEvent(new CustomEvent('change'));
        jest.runAllTimers();
        expect(searchEmployees).toHaveBeenCalledWith({ term: 'Eva' });
        jest.useRealTimers();
        await flush();
        expect(el.shadowRoot.querySelector('button.result').textContent).toContain('Eva Souza');
    });

    it('mostra mensagem quando a busca nao encontra ninguem', async () => {
        jest.useFakeTimers();
        getInitial.mockResolvedValue(VIEW);
        searchEmployees.mockResolvedValue([]);
        const el = mount();
        await Promise.resolve();
        const input = el.shadowRoot.querySelector('lightning-input');
        input.value = 'Zz';
        input.dispatchEvent(new CustomEvent('change'));
        jest.runAllTimers();
        jest.useRealTimers();
        await flush();
        expect(el.shadowRoot.querySelector('.no-results')).not.toBeNull();
    });

    it('mostra erro do servidor', async () => {
        getInitial.mockRejectedValue({ body: { message: 'Falha de acesso' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Falha de acesso');
    });

    it('mostra estado vazio para usuario sem colaborador', async () => {
        getInitial.mockResolvedValue({ isHr: false, focus: [], reports: [], emptyMessage: 'Seu usuário ainda não está vinculado' });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('não está vinculado');
    });

    it('RH com varias raizes nao pre-carrega subordinados', async () => {
        getInitial.mockResolvedValue({ isHr: true, focus: [node('r1', 'Raiz Um', 2), node('r2', 'Raiz Dois', 0)], reports: [] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelectorAll('li[role="treeitem"]').length).toBe(2);
    });

    it('erro ao carregar equipe aparece na tela', async () => {
        getInitial.mockResolvedValue(VIEW);
        getChildren.mockRejectedValue(new Error('Sem rede'));
        const el = mount();
        await flush();
        el.shadowRoot.querySelectorAll('button.toggle')[1].click();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem rede');
    });
});
