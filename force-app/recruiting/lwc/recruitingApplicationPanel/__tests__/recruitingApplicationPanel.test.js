import { createElement } from 'lwc';
import RecruitingApplicationPanel from 'c/recruitingApplicationPanel';
import getHistory from '@salesforce/apex/RecruitingInsightsController.getHistory';

jest.mock('@salesforce/apex/RecruitingInsightsController.getHistory', () => ({ default: jest.fn() }), { virtual: true });

const HISTORY = [
    {
        id: 'h1',
        fromStage: null,
        fromLabel: '',
        toStage: 'Nova',
        toLabel: 'Nova',
        changedAt: '2026-10-01T12:00:00.000Z',
        changedBy: 'Rita RH',
        daysInPreviousStage: null,
        note: null
    },
    {
        id: 'h2',
        fromStage: 'Nova',
        fromLabel: 'Nova',
        toStage: 'Triagem',
        toLabel: 'Triagem',
        changedAt: '2026-10-04T12:00:00.000Z',
        changedBy: 'Rita RH',
        daysInPreviousStage: 3,
        note: null
    },
    {
        id: 'h3',
        fromStage: 'Triagem',
        fromLabel: 'Triagem',
        toStage: 'Reprovado',
        toLabel: 'Reprovado',
        changedAt: '2026-10-05T12:00:00.000Z',
        changedBy: null,
        daysInPreviousStage: 1.5,
        note: 'Vaga encerrada'
    }
];

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function mount() {
    const el = createElement('c-recruiting-application-panel', { is: RecruitingApplicationPanel });
    el.recordId = 'a1';
    document.body.appendChild(el);
    await flush();
    return el;
}

describe('c-recruiting-application-panel', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra a linha do tempo com dias, autor e observacao', async () => {
        getHistory.mockResolvedValue(HISTORY);
        const el = await mount();
        expect(getHistory).toHaveBeenCalledWith({ applicationId: 'a1' });
        const items = el.shadowRoot.querySelectorAll('.timeline-item');
        expect(items.length).toBe(3);
        expect(items[0].querySelector('.item-title').textContent).toBe('Entrada na etapa Nova');
        expect(items[0].querySelector('.item-days')).toBeNull();
        expect(items[1].querySelector('.item-title').textContent).toBe('Nova para Triagem');
        expect(items[1].querySelector('.item-days').textContent).toBe('3 dias em Nova');
        expect(items[1].querySelector('.item-by').textContent).toContain('por Rita RH');
        expect(items[2].querySelector('.item-note').textContent).toBe('Vaga encerrada');
    });

    it('mostra mensagem quando nao ha historico', async () => {
        getHistory.mockResolvedValue([]);
        const el = await mount();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('Nenhuma mudança');
        expect(el.shadowRoot.querySelector('.timeline')).toBeNull();
    });

    it('mostra o erro do servidor', async () => {
        getHistory.mockRejectedValue({ body: { message: 'Sem acesso ao histórico.' } });
        const el = await mount();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem acesso ao histórico.');
    });

    it('recarrega ao atualizar', async () => {
        getHistory.mockResolvedValue(HISTORY);
        const el = await mount();
        el.shadowRoot.querySelector('lightning-button-icon.refresh').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(getHistory).toHaveBeenCalledTimes(2);
    });
});
