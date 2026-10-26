import { createElement } from 'lwc';
import PerformanceTeamReviews from 'c/performanceTeamReviews';
import getCycles from '@salesforce/apex/PerformanceReviewController.getCycles';
import getTeam from '@salesforce/apex/PerformanceReviewController.getTeam';

jest.mock('@salesforce/apex/PerformanceReviewController.getCycles', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PerformanceReviewController.getTeam', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/PerformanceReviewController.getReviewForm', () => ({ default: jest.fn().mockResolvedValue(null) }), { virtual: true });
jest.mock('@salesforce/apex/PerformanceReviewController.saveReview', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

const CYCLES = [
    { id: 'c1', name: 'Ciclo 2026', status: 'Autoavaliacao' },
    { id: 'c2', name: 'Ciclo 2025', status: 'Avaliacao_Gestor' }
];

function team(rows) {
    return { cycle: CYCLES[1], rows };
}

const ROWS = [
    {
        reviewId: 'r1',
        employeeId: 'e1',
        employeeName: 'Bruno Lima',
        positionName: 'Analista',
        hasSelfAssessment: true,
        selfSubmitted: true,
        reviewStatus: 'Pendente',
        isReviewer: true,
        canEdit: true
    },
    {
        reviewId: 'r2',
        employeeId: 'e2',
        employeeName: 'Carla Souza',
        positionName: 'Analista',
        hasSelfAssessment: true,
        selfSubmitted: false,
        reviewStatus: 'Enviada',
        isReviewer: false,
        canEdit: false
    }
];

function mount() {
    const el = createElement('c-performance-team-reviews', { is: PerformanceTeamReviews });
    document.body.appendChild(el);
    return el;
}

describe('c-performance-team-reviews', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('escolhe o ciclo na fase do gestor e lista a equipe com as situacoes', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getTeam.mockResolvedValue(team(ROWS));
        const el = mount();
        await flush();
        expect(getTeam).toHaveBeenCalledWith({ cycleId: 'c2' });
        const rows = el.shadowRoot.querySelectorAll('.team-row');
        expect(rows.length).toBe(2);
        expect(rows[0].querySelector('.employee-name').textContent).toBe('Bruno Lima');
        expect(rows[0].querySelector('.relation').textContent).toBe('Equipe direta');
        expect(rows[0].querySelector('.self-status').textContent).toBe('Enviada');
        expect(rows[0].querySelector('.review-status').textContent).toBe('Pendente');
        expect(rows[0].querySelector('.open-review').label).toBe('Avaliar');
        expect(rows[1].querySelector('.relation').textContent).toBe('Equipe indireta');
        expect(rows[1].querySelector('.self-status').textContent).toBe('Pendente');
        expect(rows[1].querySelector('.open-review').label).toBe('Abrir');
    });

    it('troca de ciclo e recarrega a equipe', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getTeam.mockResolvedValue(team(ROWS));
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.cycle-picker').dispatchEvent(new CustomEvent('change', { detail: { value: 'c1' } }));
        await flush();
        expect(getTeam).toHaveBeenLastCalledWith({ cycleId: 'c1' });
    });

    it('abre o formulario da avaliacao e volta para a lista', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getTeam.mockResolvedValue(team(ROWS));
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.open-review').click();
        await flush();
        const form = el.shadowRoot.querySelector('c-performance-review-form');
        expect(form).not.toBeNull();
        expect(form.reviewId).toBe('r1');
        expect(el.shadowRoot.querySelector('.team-row')).toBeNull();
        form.dispatchEvent(new CustomEvent('close'));
        await flush();
        expect(el.shadowRoot.querySelector('c-performance-review-form')).toBeNull();
        expect(getTeam).toHaveBeenCalledTimes(2);
    });

    it('mostra estado vazio', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getTeam.mockResolvedValue(team([]));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
    });

    it('avisa quando nao ha ciclos', async () => {
        getCycles.mockResolvedValue([]);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.no-cycles')).not.toBeNull();
        expect(getTeam).not.toHaveBeenCalled();
    });

    it('mostra erro do servidor e atualiza pelo botao', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getTeam.mockRejectedValueOnce({ body: { message: 'Sem acesso' } }).mockResolvedValueOnce(team(ROWS));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Sem acesso');
        el.shadowRoot.querySelector('.refresh').click();
        await flush();
        expect(el.shadowRoot.querySelectorAll('.team-row').length).toBe(2);
    });

    it('mostra erro ao carregar os ciclos', async () => {
        getCycles.mockRejectedValue(new Error('Falha'));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('Falha');
    });
});
