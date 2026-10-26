import { LightningElement } from 'lwc';
import getMonth from '@salesforce/apex/LeaveTeamCalendarController.getMonth';
import { errorMessage, monthLabel, WEEKDAY_INITIALS, WEEKDAY_NAMES } from 'c/leaveUtils';

const STATUS_LABEL = {
    Aprovado: 'Aprovado',
    Pendente: 'Pendente',
    Em_Gozo: 'Em gozo',
    Concluido: 'Concluído'
};

export const LEGEND = [
    { key: 'Aprovado', label: 'Aprovado', swatch: 'swatch swatch-Aprovado' },
    { key: 'Pendente', label: 'Pendente', swatch: 'swatch swatch-Pendente' },
    { key: 'Em_Gozo', label: 'Em gozo', swatch: 'swatch swatch-Em_Gozo' },
    { key: 'Concluido', label: 'Concluído', swatch: 'swatch swatch-Concluido' },
    { key: 'holiday', label: 'Feriado', swatch: 'swatch swatch-holiday' },
    { key: 'rest', label: 'Descanso semanal', swatch: 'swatch swatch-rest' }
];

function todayIso() {
    const d = new Date();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${month}-${day}`;
}

export default class LeaveTeamCalendar extends LightningElement {
    year;
    month;
    view = { days: [], rows: [] };
    loading = true;
    error;
    legend = LEGEND;

    connectedCallback() {
        const now = new Date();
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.view = await getMonth({ year: this.year, month: this.month });
        } catch (e) {
            this.error = errorMessage(e);
            this.view = { days: [], rows: [] };
        } finally {
            this.loading = false;
        }
    }

    // ------------------------------------------------------------------------------------------ dados da tela

    get monthTitle() {
        return monthLabel(this.year, this.month);
    }

    get dayHeaders() {
        const today = todayIso();
        return (this.view.days || []).map((d) => ({
            ...d,
            initial: WEEKDAY_INITIALS[d.weekday],
            title: this.dayTitle(d),
            className: this.dayClass('day-head', d, d.isoDate === today) + (d.onLeaveCount >= 2 ? ' has-overlap' : '')
        }));
    }

    dayTitle(d) {
        const base = `${d.day} de ${monthLabel(this.year, this.month)}, ${WEEKDAY_NAMES[d.weekday]}`;
        const extra = [];
        if (d.isHoliday) {
            extra.push(d.holidayName || 'Feriado');
        }
        if (d.onLeaveCount > 0) {
            extra.push(`${d.onLeaveCount} em férias`);
        }
        return extra.length ? `${base}. ${extra.join('. ')}` : base;
    }

    dayClass(prefix, d, isToday) {
        let cls = prefix;
        if (d.isRestDay) {
            cls += ' is-rest';
        }
        if (d.isHoliday) {
            cls += ' is-holiday';
        }
        if (isToday) {
            cls += ' is-today';
        }
        return cls;
    }

    get rowViews() {
        const days = this.view.days || [];
        const today = todayIso();
        return (this.view.rows || []).map((row) => ({
            ...row,
            cells: row.cells.map((cell, index) => {
                const day = days[index] || {};
                const status = cell.status || '';
                return {
                    key: `${row.employeeId}-${cell.day}`,
                    status,
                    label: STATUS_LABEL[status] || '',
                    title: status ? `${row.name}: ${STATUS_LABEL[status]}${cell.requestName ? ` (${cell.requestName})` : ''}` : '',
                    className:
                        this.dayClass('cell', day, day.isoDate === today) + (status ? ` cell-${status} has-leave` : '')
                };
            })
        }));
    }

    get hasRows() {
        return !this.loading && !this.error && (this.view.rows || []).length > 0;
    }

    get showEmpty() {
        return !this.loading && !this.error && (this.view.rows || []).length === 0;
    }

    get emptyText() {
        return this.view.emptyMessage || 'Nenhuma pessoa na equipe para exibir.';
    }

    get overlapDays() {
        return (this.view.days || []).filter((d) => d.onLeaveCount >= 2).length;
    }

    get overlapText() {
        if (this.overlapDays === 0) {
            return 'Nenhum dia com duas ou mais pessoas de férias.';
        }
        return this.overlapDays === 1
            ? '1 dia com duas ou mais pessoas de férias.'
            : `${this.overlapDays} dias com duas ou mais pessoas de férias.`;
    }

    // ------------------------------------------------------------------------------------------ navegacao

    handlePrevious() {
        this.move(-1);
    }

    handleNext() {
        this.move(1);
    }

    handleToday() {
        const now = new Date();
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.load();
    }

    move(step) {
        let month = this.month + step;
        let year = this.year;
        if (month < 1) {
            month = 12;
            year -= 1;
        } else if (month > 12) {
            month = 1;
            year += 1;
        }
        this.year = year;
        this.month = month;
        this.load();
    }
}
