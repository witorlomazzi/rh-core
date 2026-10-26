/* eslint-disable @lwc/lwc/no-async-operation */
import { createElement } from 'lwc';
import PerformanceCycleAdmin from 'c/performanceCycleAdmin';
import getCycles from '@salesforce/apex/PerformanceReviewController.getCycles';
import getOverview from '@salesforce/apex/ReviewCycleController.getOverview';
import createCycle from '@salesforce/apex/ReviewCycleController.createCycle';
import launch from '@salesforce/apex/ReviewCycleController.launch';
import advance from '@salesforce/apex/ReviewCycleController.advance';
import release from '@salesforce/apex/ReviewCycleController.release';
import getCalibration from '@salesforce/apex/ReviewCycleController.getCalibration';
import calibrate from '@salesforce/apex/ReviewCycleController.calibrate';

jest.mock('@salesforce/apex/PerformanceReviewController.getCycles', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ReviewCycleController.getOverview', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ReviewCycleController.createCycle', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ReviewCycleController.launch', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ReviewCycleController.advance', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ReviewCycleController.release', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ReviewCycleController.getCalibration', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ReviewCycleController.calibrate', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const TOAST = 'lightning__showtoast';

const CYCLES = [
    { id: 'c1', name: 'Ciclo 2026', status: 'Planejado' },
    { id: 'c0', name: 'Ciclo 2025', status: 'Concluido' }
];

function overview(status, extra) {
    return {
        cycle: { id: 'c1', name: 'Ciclo 2026', status, scaleMax: 5 },
        eligibleEmployees: 12,
        selfTotal: 12,
        selfSubmitted: 7,
        reviewTotal: 12,
        withoutReviewer: 1,
        reviewsByStatus: [
            { status: 'Pendente', total: 6 },
            { status: 'Em_Andamento', total: 2 },
            { status: 'Enviada', total: 3 },
            { status: 'Calibrada', total: 1 },
            { status: 'Liberada', total: 0 }
        ],
        ...extra
    };
}

const CAL_ROWS = [
    { reviewId: 'r1', employeeName: 'Bruno Lima', status: 'Enviada', managerRating: 5, calibratedRating: null, finalRating: null, canCalibrate: true },
    { reviewId: 'r2', employeeName: 'Carla Souza', status: 'Calibrada', managerRating: 4, calibratedRating: 3, finalRating: null, canCalibrate: true }
];

function mount() {
    const el = createElement('c-performance-cycle-admin', { is: PerformanceCycleAdmin });
    document.body.appendChild(el);
    return el;
}

describe('c-performance-cycle-admin', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra a situacao do ciclo e as contagens por situacao', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Autoavaliacao'));
        const el = mount();
        await flush();
        expect(getOverview).toHaveBeenCalledWith({ cycleId: 'c1' });
        expect(el.shadowRoot.querySelector('.cycle-status').textContent).toBe('Autoavaliação');
        expect(el.shadowRoot.querySelector('.self-count').textContent).toBe('7 de 12');
        const counts = el.shadowRoot.querySelectorAll('.status-count');
        expect(counts.length).toBe(5);
        expect(counts[0].querySelector('.count-label').textContent).toBe('Pendente');
        expect(counts[0].querySelector('.count-total').textContent).toBe('6');
        expect(counts[1].querySelector('.count-label').textContent).toBe('Em andamento');
        expect(el.shadowRoot.querySelector('.without-reviewer').textContent).toContain('1 avaliação');
        expect(el.shadowRoot.querySelector('.next-action').label).toBe('Avançar para a avaliação do gestor');
        expect(getCalibration).not.toHaveBeenCalled();
    });

    it('lanca o ciclo planejado depois de confirmar', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValueOnce(overview('Planejado')).mockResolvedValueOnce(overview('Autoavaliacao'));
        launch.mockResolvedValue({ reviewsCreated: 12, selfAssessmentsCreated: 12, async: false });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        expect(el.shadowRoot.querySelector('.next-action').label).toBe('Lançar ciclo');
        el.shadowRoot.querySelector('.next-action').click();
        await flush();
        expect(launch).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.confirm-text').textContent).toContain('Lançar o ciclo');
        el.shadowRoot.querySelector('.confirm').click();
        await flush();
        expect(launch).toHaveBeenCalledWith({ cycleId: 'c1' });
        expect(toast.mock.calls[0][0].detail.message).toContain('12 avaliações criadas');
        expect(el.shadowRoot.querySelector('.cycle-status').textContent).toBe('Autoavaliação');
    });

    it('cancelar a confirmacao nao executa nada', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Planejado'));
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.next-action').click();
        await flush();
        el.shadowRoot.querySelector('.cancel-confirm').click();
        await flush();
        expect(launch).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.confirm-box')).toBeNull();
    });

    it('avanca a fase sem pedir confirmacao e abre a calibracao', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValueOnce(overview('Avaliacao_Gestor')).mockResolvedValueOnce(overview('Calibracao'));
        advance.mockResolvedValue('Calibracao');
        getCalibration.mockResolvedValue(CAL_ROWS);
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.next-action').click();
        await flush();
        expect(advance).toHaveBeenCalledWith({ cycleId: 'c1' });
        expect(getCalibration).toHaveBeenCalledWith({ cycleId: 'c1' });
        expect(el.shadowRoot.querySelectorAll('.calibration-row').length).toBe(2);
        expect(el.shadowRoot.querySelector('.next-action').label).toBe('Liberar resultados');
    });

    it('calibra a nota de uma avaliacao', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Calibracao'));
        getCalibration.mockResolvedValue(CAL_ROWS);
        calibrate.mockResolvedValue();
        const el = mount();
        await flush();
        const rows = el.shadowRoot.querySelectorAll('.calibration-row');
        expect(rows[0].querySelector('.row-calibrate').disabled).toBe(true);
        rows[0].querySelector('.row-select').dispatchEvent(new CustomEvent('change', { detail: { value: '4' } }));
        await flush();
        const updated = el.shadowRoot.querySelectorAll('.calibration-row')[0];
        expect(updated.querySelector('.row-calibrate').disabled).toBe(false);
        updated.querySelector('.row-calibrate').click();
        await flush();
        expect(calibrate).toHaveBeenCalledWith({ reviewId: 'r1', rating: 4 });
    });

    it('libera os resultados depois de confirmar', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValueOnce(overview('Calibracao')).mockResolvedValueOnce(overview('Concluido'));
        getCalibration.mockResolvedValue(CAL_ROWS.map((r) => ({ ...r, canCalibrate: false, finalRating: 3 })));
        release.mockResolvedValue({ released: 4, notReleased: 2 });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        el.shadowRoot.querySelector('.next-action').click();
        await flush();
        expect(el.shadowRoot.querySelector('.confirm-text').textContent).toContain('Liberar os resultados');
        el.shadowRoot.querySelector('.confirm').click();
        await flush();
        expect(release).toHaveBeenCalledWith({ cycleId: 'c1' });
        expect(toast.mock.calls[0][0].detail.message).toContain('4 avaliações liberadas');
        expect(toast.mock.calls[0][0].detail.message).toContain('2 ficaram sem liberação');
        expect(el.shadowRoot.querySelector('.next-action')).toBeNull();
        expect(el.shadowRoot.querySelector('.row-final').textContent).toBe('3');
    });

    it('mostra o erro do servidor ao avancar', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Autoavaliacao'));
        advance.mockRejectedValue({ body: { message: 'Apenas o RH pode executar esta ação.' } });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        el.shadowRoot.querySelector('.next-action').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.variant).toBe('error');
        expect(toast.mock.calls[0][0].detail.message).toContain('RH');
    });

    it('avisa quando o lancamento vai para lote', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Planejado'));
        launch.mockResolvedValue({ async: true });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        el.shadowRoot.querySelector('.next-action').click();
        await flush();
        el.shadowRoot.querySelector('.confirm').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.message).toContain('lote');
    });

    it('troca de ciclo e recarrega o painel', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Planejado'));
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.cycle-picker').dispatchEvent(new CustomEvent('change', { detail: { value: 'c0' } }));
        await flush();
        expect(getOverview).toHaveBeenLastCalledWith({ cycleId: 'c0' });
    });

    it('cria um novo ciclo e seleciona', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Planejado'));
        createCycle.mockResolvedValue('c9');
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.toggle-create').click();
        await flush();
        el.shadowRoot.querySelector('.new-name').dispatchEvent(new CustomEvent('change', { detail: { value: 'Ciclo 2027' } }));
        await flush();
        el.shadowRoot.querySelector('.create').click();
        await flush();
        expect(createCycle).toHaveBeenCalledWith({
            name: 'Ciclo 2027',
            startDate: null,
            endDate: null,
            selfDue: null,
            managerDue: null,
            scaleMax: 5
        });
        expect(getOverview).toHaveBeenLastCalledWith({ cycleId: 'c9' });
        expect(el.shadowRoot.querySelector('.create-form')).toBeNull();
    });

    it('mostra erro ao criar ciclo invalido', async () => {
        getCycles.mockResolvedValue(CYCLES);
        getOverview.mockResolvedValue(overview('Planejado'));
        createCycle.mockRejectedValue({ body: { message: 'A nota máxima deve estar entre 2 e 9.' } });
        const el = mount();
        const toast = jest.fn();
        el.addEventListener(TOAST, toast);
        await flush();
        el.shadowRoot.querySelector('.toggle-create').click();
        await flush();
        el.shadowRoot.querySelector('.create').click();
        await flush();
        expect(toast.mock.calls[0][0].detail.message).toContain('entre 2 e 9');
    });

    it('sem ciclos mostra orientacao e erro de carga aparece', async () => {
        getCycles.mockResolvedValueOnce([]);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.no-cycles')).not.toBeNull();

        getCycles.mockRejectedValueOnce(new Error('Falha'));
        const el2 = mount();
        await flush();
        expect(el2.shadowRoot.querySelector('.error').textContent).toContain('Falha');
    });
});
