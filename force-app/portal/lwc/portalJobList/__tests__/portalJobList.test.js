import { createElement } from 'lwc';
import PortalJobList from 'c/portalJobList';
import getJobs from '@salesforce/apex/JobPortalController.getJobs';

jest.mock('@salesforce/apex/JobPortalController.getJobs', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/community/basePath', () => ({ __esModule: true, default: '/vagas' }), { virtual: true });

const JOBS = [
    {
        title: 'Analista Fiscal',
        slug: 'analista-fiscal',
        department: 'Financeiro',
        location: 'São Paulo',
        workModel: 'Hibrido',
        employmentType: 'CLT',
        openedDate: '2026-10-12'
    },
    {
        title: 'Estagiário de Logística',
        slug: 'estagiario-de-logistica',
        department: 'Logística',
        location: 'Campinas',
        workModel: 'Presencial',
        employmentType: 'Estagio',
        openedDate: '2026-10-05'
    },
    {
        title: 'Desenvolvedor Salesforce',
        slug: 'desenvolvedor-salesforce',
        department: 'Tecnologia',
        location: 'Remoto',
        workModel: 'Remoto',
        employmentType: 'PJ',
        openedDate: null
    }
];

async function flush() {
    for (let i = 0; i < 10; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
}

async function mount(props = {}) {
    const el = createElement('c-portal-job-list', { is: PortalJobList });
    Object.assign(el, props);
    document.body.appendChild(el);
    await flush();
    return el;
}

function titles(el) {
    return Array.from(el.shadowRoot.querySelectorAll('.card-title a')).map((a) => a.textContent);
}

async function choose(el, selector, value) {
    const select = el.shadowRoot.querySelector(selector);
    select.value = value;
    select.dispatchEvent(new CustomEvent('change'));
    await flush();
}

describe('c-portal-job-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra o carregamento e depois os cartoes com link para a vaga', async () => {
        let resolve;
        getJobs.mockReturnValue(new Promise((r) => (resolve = r)));
        const el = await mount();
        expect(el.shadowRoot.querySelector('.loading').textContent).toBe('Carregando vagas...');

        resolve(JOBS);
        await flush();
        expect(el.shadowRoot.querySelector('.loading')).toBeNull();
        expect(titles(el)).toEqual(['Analista Fiscal', 'Estagiário de Logística', 'Desenvolvedor Salesforce']);
        const first = el.shadowRoot.querySelector('.card-title a');
        expect(first.getAttribute('href')).toBe('/vagas/vaga?vaga=analista-fiscal');
        expect(el.shadowRoot.querySelector('.count').textContent).toBe('3 vagas encontradas');
        const chips = Array.from(el.shadowRoot.querySelectorAll('.card')[0].querySelectorAll('.chip')).map(
            (c) => c.textContent
        );
        expect(chips).toEqual(['Financeiro', 'Híbrido', 'CLT', 'São Paulo']);
        expect(el.shadowRoot.querySelectorAll('.opened')[0].textContent).toBe('Aberta em 12/10/2026');
        expect(el.shadowRoot.querySelectorAll('.opened')[2].textContent).toBe('');
    });

    it('usa a pagina de detalhe configurada', async () => {
        getJobs.mockResolvedValue(JOBS);
        const el = await mount({ detailPath: 'detalhe' });
        expect(el.shadowRoot.querySelector('.card-title a').getAttribute('href')).toBe(
            '/vagas/detalhe?vaga=analista-fiscal'
        );
    });

    it('filtra por modelo de trabalho e por area e limpa os filtros', async () => {
        getJobs.mockResolvedValue(JOBS);
        const el = await mount();

        const modelLabels = Array.from(
            el.shadowRoot.querySelectorAll('#filter-model option, select.control option')
        ).map((o) => o.textContent.trim());
        expect(modelLabels).toEqual(expect.arrayContaining(['Todos os modelos', 'Híbrido', 'Presencial', 'Remoto']));

        await choose(el, 'select.control', 'Remoto');
        expect(titles(el)).toEqual(['Desenvolvedor Salesforce']);
        expect(el.shadowRoot.querySelector('.count').textContent).toBe('1 vaga encontrada');

        const selects = el.shadowRoot.querySelectorAll('select.control');
        selects[1].value = 'Financeiro';
        selects[1].dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(titles(el)).toEqual([]);
        expect(el.shadowRoot.querySelector('.empty').textContent).toBe('Nenhuma vaga encontrada com esses filtros.');

        el.shadowRoot.querySelector('.clear').click();
        await flush();
        expect(titles(el)).toHaveLength(3);
        expect(el.shadowRoot.querySelector('.clear')).toBeNull();
    });

    it('mostra o estado vazio quando nao ha vagas abertas', async () => {
        getJobs.mockResolvedValue([]);
        const el = await mount();
        expect(el.shadowRoot.querySelector('.empty').textContent).toBe(
            'No momento não há vagas abertas. Volte em breve.'
        );
        expect(el.shadowRoot.querySelector('.filters')).toBeNull();
        expect(el.shadowRoot.querySelector('.cards')).toBeNull();
    });

    it('mostra erro amigavel quando o servidor falha', async () => {
        getJobs.mockRejectedValue({ body: { message: 'Erro interno com detalhe tecnico' } });
        const el = await mount();
        const alert = el.shadowRoot.querySelector('[role="alert"]');
        expect(alert).not.toBeNull();
        expect(alert.textContent).toBe('Não foi possível carregar as vagas agora. Tente novamente em alguns minutos.');
        expect(alert.textContent).not.toContain('tecnico');
        expect(el.shadowRoot.querySelector('.empty')).toBeNull();
    });

    it('exibe o aviso de projeto demonstrativo', async () => {
        getJobs.mockResolvedValue(JOBS);
        const el = await mount();
        expect(el.shadowRoot.querySelector('.notice').textContent).toContain('Projeto demonstrativo');
    });
});
