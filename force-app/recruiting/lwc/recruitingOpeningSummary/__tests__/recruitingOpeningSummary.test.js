import { createElement } from 'lwc';
import RecruitingOpeningSummary from 'c/recruitingOpeningSummary';
import getOpeningSummary from '@salesforce/apex/RecruitingInsightsController.getOpeningSummary';

jest.mock('@salesforce/apex/RecruitingInsightsController.getOpeningSummary', () => ({ default: jest.fn() }), { virtual: true });

const SUMMARY = {
    openingId: 'v1',
    openingName: 'Analista Fiscal',
    openingStatus: 'Aberta',
    total: 5,
    inProgress: 4,
    stages: [
        { stage: 'Nova', label: 'Nova', color: '#706e6b', isTerminal: false, count: 1, averageDays: 3.5 },
        { stage: 'Triagem', label: 'Triagem', color: '#1b96ff', isTerminal: false, count: 3, averageDays: null },
        { stage: 'Reprovado', label: 'Reprovado', color: '#ba0517', isTerminal: true, count: 1, averageDays: null }
    ]
};

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function mount() {
    const el = createElement('c-recruiting-opening-summary', { is: RecruitingOpeningSummary });
    el.recordId = 'v1';
    document.body.appendChild(el);
    await flush();
    return el;
}

describe('c-recruiting-opening-summary', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra a contagem por etapa e o tempo medio', async () => {
        getOpeningSummary.mockResolvedValue(SUMMARY);
        const el = await mount();
        expect(getOpeningSummary).toHaveBeenCalledWith({ openingId: 'v1' });
        expect(el.shadowRoot.querySelector('.total').textContent).toBe('5 no total, 4 em andamento');
        const rows = el.shadowRoot.querySelectorAll('.stage-row');
        expect(rows.length).toBe(3);
        expect(rows[0].querySelector('.row-label').textContent).toBe('Nova');
        expect(rows[0].querySelector('.row-count').textContent).toBe('1');
        expect(rows[0].querySelector('.row-average').textContent).toBe('3.5 dias');
        expect(rows[1].querySelector('.row-count').textContent).toBe('3');
        expect(rows[1].querySelector('.row-average').textContent).toBe('sem dados');
        // A maior coluna ocupa 100% da barra.
        expect(rows[1].querySelector('.bar').style.width).toBe('100%');
        expect(rows[0].querySelector('.bar').style.width).toBe('33%');
    });

    it('mostra o erro do servidor e nenhuma tabela', async () => {
        getOpeningSummary.mockRejectedValue({ body: { message: 'Vaga não encontrada ou sem acesso.' } });
        const el = await mount();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Vaga não encontrada');
        expect(el.shadowRoot.querySelector('table')).toBeNull();
    });

    it('recarrega ao atualizar', async () => {
        getOpeningSummary.mockResolvedValue(SUMMARY);
        const el = await mount();
        el.shadowRoot.querySelector('lightning-button-icon.refresh').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(getOpeningSummary).toHaveBeenCalledTimes(2);
    });
});
