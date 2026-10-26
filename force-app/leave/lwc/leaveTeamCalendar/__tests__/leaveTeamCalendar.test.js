import { createElement } from 'lwc';
import LeaveTeamCalendar from 'c/leaveTeamCalendar';
import getMonth from '@salesforce/apex/LeaveTeamCalendarController.getMonth';

jest.mock('@salesforce/apex/LeaveTeamCalendarController.getMonth', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function buildMonth(year, month) {
    const total = new Date(year, month, 0).getDate();
    const days = [];
    for (let d = 1; d <= total; d++) {
        const weekday = new Date(year, month - 1, d).getDay();
        const pad = (n) => String(n).padStart(2, '0');
        days.push({
            day: d,
            isoDate: `${year}-${pad(month)}-${pad(d)}`,
            weekday,
            isRestDay: weekday === 0,
            isHoliday: d === 12,
            holidayName: d === 12 ? 'Feriado teste' : null,
            onLeaveCount: d === 5 || d === 6 ? 2 : d === 4 ? 1 : 0
        });
    }
    const cell = (d, status, requestName) => ({ day: d, status, requestName });
    const mkCells = (statusByDay) =>
        days.map((x) => cell(x.day, statusByDay[x.day] || '', statusByDay[x.day] ? 'FE-000001' : null));
    return {
        year,
        month,
        days,
        rows: [
            { employeeId: 'e1', name: 'Ana Souza', positionName: 'Analista', cells: mkCells({ 4: 'Aprovado', 5: 'Aprovado', 6: 'Em_Gozo' }) },
            { employeeId: 'e2', name: 'Bruno Lima', positionName: null, cells: mkCells({ 5: 'Pendente', 6: 'Concluido' }) }
        ]
    };
}

function mount() {
    const el = createElement('c-leave-team-calendar', { is: LeaveTeamCalendar });
    document.body.appendChild(el);
    return el;
}

describe('c-leave-team-calendar', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('carrega o mes atual e desenha a grade com pessoas e dias', async () => {
        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth() + 1;
        getMonth.mockResolvedValue(buildMonth(year, month));
        const el = mount();
        await flush();
        expect(getMonth).toHaveBeenCalledWith({ year, month });
        const total = new Date(year, month, 0).getDate();
        expect(el.shadowRoot.querySelectorAll('thead th.day-head').length).toBe(total);
        const rows = el.shadowRoot.querySelectorAll('tbody tr');
        expect(rows.length).toBe(2);
        expect(rows[0].querySelector('.person-name').textContent).toBe('Ana Souza');
        expect(rows[0].querySelector('.person-position').textContent).toBe('Analista');
        expect(rows[1].querySelector('.person-position')).toBeNull();
        expect(rows[0].querySelectorAll('td').length).toBe(total);
    });

    it('colore as celulas pela situacao e traz texto para leitor de tela', async () => {
        getMonth.mockResolvedValue(buildMonth(2026, 10));
        const el = mount();
        await flush();
        const cells = el.shadowRoot.querySelectorAll('tbody tr')[0].querySelectorAll('td');
        expect(cells[3].className).toContain('cell-Aprovado');
        expect(cells[3].querySelector('.slds-assistive-text').textContent).toBe('Aprovado');
        expect(cells[3].title).toBe('Ana Souza: Aprovado (FE-000001)');
        expect(cells[5].className).toContain('cell-Em_Gozo');
        expect(cells[0].className).not.toContain('has-leave');
        expect(cells[0].querySelector('.slds-assistive-text')).toBeNull();
        const second = el.shadowRoot.querySelectorAll('tbody tr')[1].querySelectorAll('td');
        expect(second[4].className).toContain('cell-Pendente');
        expect(second[5].className).toContain('cell-Concluido');
    });

    it('destaca feriado, descanso semanal e dias com varias pessoas de ferias', async () => {
        getMonth.mockResolvedValue(buildMonth(2026, 10));
        const el = mount();
        await flush();
        const heads = el.shadowRoot.querySelectorAll('thead th.day-head');
        // 04/10/2026 e domingo
        expect(heads[3].className).toContain('is-rest');
        expect(heads[11].className).toContain('is-holiday');
        expect(heads[11].title).toContain('Feriado teste');
        expect(heads[4].className).toContain('has-overlap');
        expect(heads[4].title).toContain('2 em férias');
        expect(heads[3].className).not.toContain('has-overlap');
        expect(el.shadowRoot.querySelector('.overlap').textContent).toBe('2 dias com duas ou mais pessoas de férias.');
    });

    it('mostra a legenda completa', async () => {
        getMonth.mockResolvedValue(buildMonth(2026, 10));
        const el = mount();
        await flush();
        const items = el.shadowRoot.querySelectorAll('.legend-item');
        expect(items.length).toBe(6);
        expect(items[4].textContent).toContain('Feriado');
        expect(items[5].textContent).toContain('Descanso semanal');
    });

    it('navega entre meses e vira o ano', async () => {
        getMonth.mockImplementation(({ year, month }) => Promise.resolve(buildMonth(year, month)));
        const el = mount();
        await flush();
        const now = new Date();
        let year = now.getFullYear();
        let month = now.getMonth() + 1;

        el.shadowRoot.querySelector('lightning-button-icon.next').click();
        await flush();
        month += 1;
        if (month > 12) {
            month = 1;
            year += 1;
        }
        expect(getMonth).toHaveBeenLastCalledWith({ year, month });

        el.shadowRoot.querySelector('lightning-button-icon.previous').click();
        await flush();
        el.shadowRoot.querySelector('lightning-button-icon.previous').click();
        await flush();
        month -= 2;
        if (month < 1) {
            month += 12;
            year -= 1;
        }
        expect(getMonth).toHaveBeenLastCalledWith({ year, month });

        el.shadowRoot.querySelector('lightning-button.today').click();
        await flush();
        expect(getMonth).toHaveBeenLastCalledWith({ year: now.getFullYear(), month: now.getMonth() + 1 });
    });

    it('vira de janeiro para dezembro do ano anterior e de dezembro para janeiro', async () => {
        const realDate = Date;
        const fixed = new realDate(2026, 0, 15);
        global.Date = class extends realDate {
            constructor(...args) {
                if (args.length === 0) {
                    super(fixed.getTime());
                } else {
                    super(...args);
                }
            }
        };
        try {
            getMonth.mockImplementation(({ year, month }) => Promise.resolve(buildMonth(year, month)));
            const el = mount();
            await flush();
            expect(getMonth).toHaveBeenLastCalledWith({ year: 2026, month: 1 });
            el.shadowRoot.querySelector('lightning-button-icon.previous').click();
            await flush();
            expect(getMonth).toHaveBeenLastCalledWith({ year: 2025, month: 12 });
            el.shadowRoot.querySelector('lightning-button-icon.next').click();
            await flush();
            expect(getMonth).toHaveBeenLastCalledWith({ year: 2026, month: 1 });
            expect(el.shadowRoot.querySelector('.month-title').textContent).toBe('janeiro de 2026');
        } finally {
            global.Date = realDate;
        }
    });

    it('mostra a mensagem do servidor quando nao ha equipe', async () => {
        getMonth.mockResolvedValue({ days: [], rows: [], emptyMessage: 'Você não tem equipe direta para exibir no calendário.' });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('equipe direta');
        expect(el.shadowRoot.querySelector('table')).toBeNull();
    });

    it('mostra texto padrao no estado vazio e erro ao carregar', async () => {
        getMonth.mockResolvedValueOnce({ days: [], rows: [] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty').textContent).toContain('Nenhuma pessoa na equipe');

        getMonth.mockRejectedValueOnce({ body: { message: 'Informe um mês válido.' } });
        el.shadowRoot.querySelector('lightning-button-icon.next').click();
        await flush();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('mês válido');
        expect(el.shadowRoot.querySelector('.empty')).toBeNull();
    });

    it('informa quando nao ha sobreposicao', async () => {
        const month = buildMonth(2026, 10);
        month.days.forEach((d) => {
            d.onLeaveCount = 0;
        });
        getMonth.mockResolvedValue(month);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.overlap').textContent).toBe('Nenhum dia com duas ou mais pessoas de férias.');
    });

    it('usa singular com um unico dia de sobreposicao', async () => {
        const month = buildMonth(2026, 10);
        month.days.forEach((d) => {
            d.onLeaveCount = d.day === 5 ? 2 : 0;
        });
        getMonth.mockResolvedValue(month);
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.overlap').textContent).toBe('1 dia com duas ou mais pessoas de férias.');
    });
});
