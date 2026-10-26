/* eslint-disable @lwc/lwc/no-async-operation */
import { createElement } from 'lwc';
import MyHrTeamOverview from 'c/myHrTeamOverview';
import getTeamOverview from '@salesforce/apex/MyHrController.getTeamOverview';

jest.mock('@salesforce/apex/MyHrController.getTeamOverview', () => ({ default: jest.fn() }), { virtual: true });
jest.mock(
    'c/promotionRequestForm',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);
jest.mock(
    'c/leaveTeamCalendar',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

const OVERVIEW = {
    isManager: true,
    alertCount: 2,
    members: [
        {
            employeeId: 'e1',
            name: 'Ana Souza',
            initials: 'AS',
            positionName: 'Analista',
            status: 'Ativo',
            statusLabel: 'Ativo',
            balanceDays: 20,
            hasOpenPeriod: true,
            nextLeave: { startDate: '2026-12-01', endDate: '2026-12-14', days: 14, status: 'Aprovado', statusLabel: 'Aprovado' },
            concessionDeadline: '2026-12-20',
            daysToDeadline: 30,
            deadlineAlert: true,
            deadlineOverdue: false
        },
        {
            employeeId: 'e2',
            name: 'Bruno Lima',
            initials: 'BL',
            positionName: 'Analista',
            status: 'Ferias',
            statusLabel: 'De férias',
            balanceDays: 5,
            hasOpenPeriod: true,
            nextLeave: null,
            concessionDeadline: '2026-10-01',
            daysToDeadline: -25,
            deadlineAlert: true,
            deadlineOverdue: true
        },
        {
            employeeId: 'e3',
            name: 'Carla Dias',
            initials: 'CD',
            positionName: null,
            status: 'Ativo',
            statusLabel: 'Ativo',
            balanceDays: 0,
            hasOpenPeriod: false,
            nextLeave: null,
            concessionDeadline: null,
            daysToDeadline: null,
            deadlineAlert: false,
            deadlineOverdue: false
        }
    ]
};

function mount() {
    const el = createElement('c-my-hr-team-overview', { is: MyHrTeamOverview });
    document.body.appendChild(el);
    return el;
}

describe('c-my-hr-team-overview', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista a equipe com situacao, saldo e proximas ferias', async () => {
        getTeamOverview.mockResolvedValue(OVERVIEW);
        const el = mount();
        await flush();
        const rows = el.shadowRoot.querySelectorAll('tr.member');
        expect(rows.length).toBe(3);
        expect(rows[0].querySelector('.member-name').textContent).toBe('Ana Souza');
        expect(rows[0].querySelector('.member-position').textContent).toBe('Analista');
        expect(rows[0].querySelector('.balance').textContent).toBe('20 dias');
        expect(rows[0].querySelector('.next-range').textContent).toBe('01/12/2026 a 14/12/2026');
        expect(rows[1].querySelector('.slds-badge').textContent).toBe('De férias');
        expect(rows[1].querySelector('.no-leave').textContent).toBe('Sem férias programadas');
        expect(rows[2].querySelector('.balance').textContent).toBe('Sem período disponível');
        expect(el.shadowRoot.querySelector('.summary').textContent).toBe('3 pessoas na equipe direta');
    });

    it('destaca o alerta de prazo concessivo proximo e vencido', async () => {
        getTeamOverview.mockResolvedValue(OVERVIEW);
        const el = mount();
        await flush();
        const rows = el.shadowRoot.querySelectorAll('tr.member');
        const near = rows[0].querySelector('.deadline');
        expect(near.textContent).toBe('20/12/2026 (30 dias)');
        expect(near.className).toContain('slds-theme_warning');
        const overdue = rows[1].querySelector('.deadline');
        expect(overdue.textContent).toBe('Vencido em 01/10/2026');
        expect(overdue.className).toContain('slds-theme_error');
        expect(rows[2].querySelector('.deadline')).toBeNull();
        expect(el.shadowRoot.querySelector('.alert-summary h2').textContent).toBe(
            '2 pessoas com prazo concessivo próximo ou vencido'
        );
    });

    it('sem alertas nao mostra o resumo de alerta', async () => {
        getTeamOverview.mockResolvedValue({ ...OVERVIEW, alertCount: 0 });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.alert-summary')).toBeNull();
    });

    it('equipe vazia mostra a mensagem do servidor', async () => {
        getTeamOverview.mockResolvedValue({
            isManager: false,
            alertCount: 0,
            members: [],
            emptyMessage: 'Você não tem pessoas na sua equipe direta.'
        });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty-text').textContent).toBe('Você não tem pessoas na sua equipe direta.');
        expect(el.shadowRoot.querySelector('table')).toBeNull();
    });

    it('erro do servidor mostra o alerta', async () => {
        getTeamOverview.mockRejectedValue({ body: { message: 'Sem acesso.' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error h2').textContent).toBe('Sem acesso.');
        expect(el.shadowRoot.querySelector('table')).toBeNull();
    });

    it('atalho de promocao abre e fecha o formulario no modal', async () => {
        getTeamOverview.mockResolvedValue(OVERVIEW);
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.promotion-shortcut').click();
        await flush();
        const modal = el.shadowRoot.querySelector('c-my-hr-modal');
        expect(modal.heading).toBe('Solicitar promoção');
        expect(el.shadowRoot.querySelector('c-promotion-request-form')).not.toBeNull();
        modal.dispatchEvent(new CustomEvent('close'));
        await flush();
        expect(el.shadowRoot.querySelector('c-my-hr-modal')).toBeNull();
    });

    it('atalho do calendario abre o calendario da equipe no modal', async () => {
        getTeamOverview.mockResolvedValue(OVERVIEW);
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.calendar-shortcut').click();
        await flush();
        expect(el.shadowRoot.querySelector('c-my-hr-modal').heading).toBe('Calendário de férias da equipe');
        expect(el.shadowRoot.querySelector('c-leave-team-calendar')).not.toBeNull();
    });

    it('o botao atualizar consulta de novo', async () => {
        getTeamOverview.mockResolvedValue(OVERVIEW);
        const el = mount();
        await flush();
        el.shadowRoot.querySelector('.refresh').click();
        await flush();
        expect(getTeamOverview).toHaveBeenCalledTimes(2);
    });

    it('usa singular quando ha uma pessoa na equipe', async () => {
        getTeamOverview.mockResolvedValue({ ...OVERVIEW, alertCount: 1, members: [OVERVIEW.members[0]] });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.summary').textContent).toBe('1 pessoa na equipe direta');
        expect(el.shadowRoot.querySelector('.alert-summary h2').textContent).toBe(
            '1 pessoa com prazo concessivo próximo ou vencido'
        );
    });
});
