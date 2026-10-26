import { createElement } from 'lwc';
import RecruitingKanban from 'c/recruitingKanban';
import getOpenings from '@salesforce/apex/RecruitingKanbanController.getOpenings';
import getBoard from '@salesforce/apex/RecruitingKanbanController.getBoard';
import moveCard from '@salesforce/apex/RecruitingKanbanController.moveCard';
import rateCard from '@salesforce/apex/RecruitingKanbanController.rateCard';

jest.mock('@salesforce/apex/RecruitingKanbanController.getOpenings', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RecruitingKanbanController.getBoard', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RecruitingKanbanController.moveCard', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RecruitingKanbanController.rateCard', () => ({ default: jest.fn() }), { virtual: true });

const OPENINGS = [
    { id: 'v1', name: 'Analista Fiscal', status: 'Aberta', applicationsCount: 2 },
    { id: 'v2', name: 'Auxiliar de Estoque', status: 'Aberta', applicationsCount: 0 }
];

const REASONS = [
    { value: 'Perfil', label: 'Perfil' },
    { value: 'Outro', label: 'Outro' }
];

function stage(value, label, color, allowedNext, extra = {}) {
    return {
        value,
        label,
        color,
        isTerminal: false,
        requiresScore: false,
        requiresRejectionReason: false,
        allowedNext,
        ...extra
    };
}

function board() {
    return {
        openingId: 'v1',
        openingName: 'Analista Fiscal',
        openingStatus: 'Aberta',
        rejectionReasons: REASONS,
        stages: [
            stage('Nova', 'Nova', '#706e6b', ['Triagem', 'Reprovado']),
            stage('Triagem', 'Triagem', '#1b96ff', ['Entrevista_Tecnica', 'Reprovado']),
            stage('Entrevista_Tecnica', 'Entrevista técnica', '#7f8de1', ['Proposta']),
            stage('Proposta', 'Proposta', '#dd7a01', [], { requiresScore: true }),
            stage('Reprovado', 'Reprovado', '#ba0517', [], { isTerminal: true, requiresRejectionReason: true })
        ],
        cards: [
            {
                id: 'c1',
                applicationNumber: 'CA-000001',
                candidateName: 'Ana Souza',
                stage: 'Nova',
                score: null,
                daysInStage: 3
            },
            {
                id: 'c2',
                applicationNumber: 'CA-000002',
                candidateName: 'Bruno Lima',
                stage: 'Entrevista_Tecnica',
                score: null,
                daysInStage: 1
            },
            {
                id: 'c3',
                applicationNumber: 'CA-000003',
                candidateName: 'Carla Mendes',
                stage: 'Reprovado',
                score: 2,
                daysInStage: 5,
                rejectionReason: 'Perfil'
            }
        ]
    };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function mount(props = {}) {
    const el = createElement('c-recruiting-kanban', { is: RecruitingKanban });
    Object.assign(el, props);
    document.body.appendChild(el);
    await flush();
    await flush();
    return el;
}

function card(el, id) {
    return Array.from(el.shadowRoot.querySelectorAll('li.card')).find((li) => li.dataset.id === id);
}

function column(el, stageValue) {
    return Array.from(el.shadowRoot.querySelectorAll('section.column')).find((s) => s.dataset.stage === stageValue);
}

function select(el, id, value) {
    const menu = Array.from(el.shadowRoot.querySelectorAll('lightning-button-menu')).find((m) => m.dataset.id === id);
    menu.dispatchEvent(new CustomEvent('select', { detail: { value } }));
}

function toastListener(el) {
    const handler = jest.fn();
    el.addEventListener('lightning__showtoast', handler);
    return handler;
}

describe('c-recruiting-kanban', () => {
    beforeEach(() => {
        getOpenings.mockResolvedValue(OPENINGS);
        getBoard.mockResolvedValue(board());
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('carrega a primeira vaga e mostra colunas na ordem com cartoes', async () => {
        const el = await mount();
        expect(getBoard).toHaveBeenCalledWith({ openingId: 'v1' });
        const titles = Array.from(el.shadowRoot.querySelectorAll('.column-title')).map((t) => t.textContent);
        expect(titles).toEqual(['Nova', 'Triagem', 'Entrevista técnica', 'Proposta', 'Reprovado']);
        const ana = card(el, 'c1');
        expect(ana.textContent).toContain('Ana Souza');
        expect(ana.textContent).toContain('CA-000001');
        expect(ana.textContent).toContain('Sem nota');
        expect(ana.textContent).toContain('3 dias na etapa');
        expect(card(el, 'c2').textContent).toContain('1 dia na etapa');
        expect(card(el, 'c3').textContent).toContain('Nota 2');
        expect(card(el, 'c3').textContent).toContain('Motivo: Perfil');
        expect(column(el, 'Triagem').querySelector('.column-empty')).not.toBeNull();
        expect(column(el, 'Nova').querySelector('.column-count').textContent).toBe('1 candidatura');
    });

    it('troca de vaga pelo seletor', async () => {
        const el = await mount();
        const picker = el.shadowRoot.querySelector('lightning-combobox.opening-picker');
        expect(picker.options.length).toBe(2);
        picker.dispatchEvent(new CustomEvent('change', { detail: { value: 'v2' } }));
        await flush();
        expect(getBoard).toHaveBeenLastCalledWith({ openingId: 'v2' });
    });

    it('usa a vaga da pagina e esconde o seletor quando ha recordId', async () => {
        const el = await mount({ recordId: 'v9' });
        expect(getOpenings).not.toHaveBeenCalled();
        expect(getBoard).toHaveBeenCalledWith({ openingId: 'v9' });
        expect(el.shadowRoot.querySelector('lightning-combobox.opening-picker')).toBeNull();
    });

    it('mostra estado vazio sem vagas', async () => {
        getOpenings.mockResolvedValue([]);
        const el = await mount();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('Nenhuma vaga');
        expect(getBoard).not.toHaveBeenCalled();
    });

    it('mostra o erro do servidor ao carregar o funil', async () => {
        getBoard.mockRejectedValue({ body: { message: 'Vaga não encontrada ou sem acesso.' } });
        const el = await mount();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Vaga não encontrada');
        expect(el.shadowRoot.querySelector('section.column')).toBeNull();
    });

    it('move pelo menu Mover para e atualiza o cartao', async () => {
        const updated = { ...board().cards[0], stage: 'Triagem', daysInStage: 0 };
        moveCard.mockResolvedValue(updated);
        const el = await mount();
        const toast = toastListener(el);

        select(el, 'c1', 'Triagem');
        await flush();

        expect(moveCard).toHaveBeenCalledWith({
            applicationId: 'c1',
            toStage: 'Triagem',
            rejectionReason: null,
            score: null
        });
        expect(column(el, 'Triagem').querySelector('li.card').dataset.id).toBe('c1');
        expect(column(el, 'Nova').querySelector('li.card')).toBeNull();
        expect(toast).toHaveBeenCalled();
        expect(toast.mock.calls[0][0].detail.variant).toBe('success');
    });

    it('oferece as etapas permitidas e Dar nota no menu do cartao', async () => {
        const el = await mount();
        const menu = Array.from(el.shadowRoot.querySelectorAll('lightning-button-menu')).find((m) => m.dataset.id === 'c1');
        const labels = Array.from(menu.querySelectorAll('lightning-menu-item')).map((i) => i.label);
        expect(labels).toEqual(['Mover para Triagem', 'Mover para Reprovado', 'Dar nota']);
    });

    it('mostra o erro do servidor ao mover e mantem o cartao na coluna', async () => {
        moveCard.mockRejectedValue({ body: { message: 'Mudança de etapa não permitida: de Nova para Triagem.' } });
        const el = await mount();
        const toast = toastListener(el);

        select(el, 'c1', 'Triagem');
        await flush();

        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Mudança de etapa não permitida');
        expect(column(el, 'Nova').querySelector('li.card').dataset.id).toBe('c1');
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
    });

    it('bloqueia no cliente uma transicao fora da lista sem chamar o servidor', async () => {
        const el = await mount();
        const toast = toastListener(el);
        select(el, 'c1', 'Proposta');
        await flush();
        expect(moveCard).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.error').textContent).toBe('Mudança de etapa não permitida: de Nova para Proposta.');
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
    });

    it('pede o motivo em modal antes de reprovar', async () => {
        moveCard.mockResolvedValue({ ...board().cards[0], stage: 'Reprovado', rejectionReason: 'Perfil' });
        const el = await mount();

        select(el, 'c1', 'Reprovado');
        await flush();
        expect(moveCard).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.modal-title').textContent).toBe('Mover para Reprovado');

        // Sem motivo: erro local, sem chamada.
        el.shadowRoot.querySelector('lightning-button.modal-confirm').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(el.shadowRoot.querySelector('.modal-error').textContent).toBe('Informe o motivo da reprovação.');
        expect(moveCard).not.toHaveBeenCalled();

        el.shadowRoot.querySelector('lightning-combobox.modal-reason').dispatchEvent(new CustomEvent('change', { detail: { value: 'Perfil' } }));
        el.shadowRoot.querySelector('lightning-button.modal-confirm').dispatchEvent(new CustomEvent('click'));
        await flush();

        expect(moveCard).toHaveBeenCalledWith({
            applicationId: 'c1',
            toStage: 'Reprovado',
            rejectionReason: 'Perfil',
            score: null
        });
        expect(el.shadowRoot.querySelector('.modal')).toBeNull();
        expect(column(el, 'Reprovado').querySelectorAll('li.card').length).toBe(2);
    });

    it('pede a nota em modal antes da proposta e valida a faixa', async () => {
        moveCard.mockResolvedValue({ ...board().cards[1], stage: 'Proposta', score: 4 });
        const el = await mount();

        select(el, 'c2', 'Proposta');
        await flush();
        // Entrevista tecnica permite Proposta; a nota ainda nao existe.
        expect(el.shadowRoot.querySelector('lightning-input.modal-score')).not.toBeNull();

        const input = el.shadowRoot.querySelector('lightning-input.modal-score');
        input.dispatchEvent(new CustomEvent('change', { detail: { value: '9' } }));
        el.shadowRoot.querySelector('lightning-button.modal-confirm').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(el.shadowRoot.querySelector('.modal-error').textContent).toBe('Informe uma nota de 0 a 5.');
        expect(moveCard).not.toHaveBeenCalled();

        input.dispatchEvent(new CustomEvent('change', { detail: { value: '4' } }));
        el.shadowRoot.querySelector('lightning-button.modal-confirm').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(moveCard).toHaveBeenCalledWith({
            applicationId: 'c2',
            toStage: 'Proposta',
            rejectionReason: null,
            score: 4
        });
    });

    it('mantem o modal aberto com a mensagem quando o servidor recusa', async () => {
        moveCard.mockRejectedValue({ body: { message: 'Informe o motivo da reprovação.' } });
        const el = await mount();
        select(el, 'c1', 'Reprovado');
        await flush();
        el.shadowRoot.querySelector('lightning-combobox.modal-reason').dispatchEvent(new CustomEvent('change', { detail: { value: 'Outro' } }));
        el.shadowRoot.querySelector('lightning-button.modal-confirm').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(el.shadowRoot.querySelector('.modal')).not.toBeNull();
        expect(el.shadowRoot.querySelector('.modal-error').textContent).toBe('Informe o motivo da reprovação.');
    });

    it('cancela o modal sem mover', async () => {
        const el = await mount();
        select(el, 'c1', 'Reprovado');
        await flush();
        el.shadowRoot.querySelector('lightning-button.modal-cancel').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(el.shadowRoot.querySelector('.modal')).toBeNull();
        expect(moveCard).not.toHaveBeenCalled();
    });

    it('da nota sem mudar de etapa', async () => {
        rateCard.mockResolvedValue({ ...board().cards[0], score: 3 });
        const el = await mount();
        select(el, 'c1', '__rate__');
        await flush();
        expect(el.shadowRoot.querySelector('.modal-title').textContent).toBe('Dar nota');
        el.shadowRoot.querySelector('lightning-input.modal-score').dispatchEvent(new CustomEvent('change', { detail: { value: '3' } }));
        el.shadowRoot.querySelector('lightning-button.modal-confirm').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(rateCard).toHaveBeenCalledWith({ applicationId: 'c1', score: 3 });
        expect(card(el, 'c1').textContent).toContain('Nota 3');
        expect(moveCard).not.toHaveBeenCalled();
    });

    it('move arrastando o cartao para uma coluna permitida', async () => {
        moveCard.mockResolvedValue({ ...board().cards[0], stage: 'Triagem' });
        const el = await mount();
        const dataTransfer = { setData: jest.fn(), getData: jest.fn(() => 'c1'), effectAllowed: '', dropEffect: '' };

        const dragStart = new CustomEvent('dragstart', { bubbles: true });
        dragStart.dataTransfer = dataTransfer;
        card(el, 'c1').dispatchEvent(dragStart);
        await flush();
        expect(dataTransfer.setData).toHaveBeenCalledWith('text/plain', 'c1');

        const over = new CustomEvent('dragover', { bubbles: true, cancelable: true });
        over.dataTransfer = dataTransfer;
        column(el, 'Triagem').dispatchEvent(over);
        expect(over.defaultPrevented).toBe(true);

        const drop = new CustomEvent('drop', { bubbles: true, cancelable: true });
        drop.dataTransfer = dataTransfer;
        column(el, 'Triagem').dispatchEvent(drop);
        await flush();

        expect(moveCard).toHaveBeenCalledWith({
            applicationId: 'c1',
            toStage: 'Triagem',
            rejectionReason: null,
            score: null
        });
    });

    it('nao aceita soltar em coluna fora da transicao e cartao terminal nao arrasta', async () => {
        const el = await mount();
        const dataTransfer = { setData: jest.fn(), getData: jest.fn(() => 'c1') };
        const dragStart = new CustomEvent('dragstart', { bubbles: true });
        dragStart.dataTransfer = dataTransfer;
        card(el, 'c1').dispatchEvent(dragStart);
        await flush();

        const over = new CustomEvent('dragover', { bubbles: true, cancelable: true });
        over.dataTransfer = dataTransfer;
        column(el, 'Proposta').dispatchEvent(over);
        expect(over.defaultPrevented).toBe(false);

        const drop = new CustomEvent('drop', { bubbles: true, cancelable: true });
        drop.dataTransfer = dataTransfer;
        column(el, 'Proposta').dispatchEvent(drop);
        await flush();
        expect(moveCard).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.error')).not.toBeNull();

        expect(card(el, 'c3').draggable).toBe(false);
    });

    it('atualiza o funil pelo botao de atualizar', async () => {
        const el = await mount();
        el.shadowRoot.querySelector('lightning-button-icon.refresh').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(getBoard).toHaveBeenCalledTimes(2);
    });
});
