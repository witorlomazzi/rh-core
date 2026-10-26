/* eslint-disable @lwc/lwc/no-async-operation */
import { createElement } from 'lwc';
import MyHrHome from 'c/myHrHome';
import getContext from '@salesforce/apex/MyHrController.getContext';
import { subscribe, unsubscribe } from 'lightning/messageService';

jest.mock('@salesforce/apex/MyHrController.getContext', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/messageChannel/LeaveChanged__c', () => ({ default: 'LeaveChanged__c' }), { virtual: true });

// Componentes dos outros modulos viram stubs: aqui so se testa a composicao do Meu RH.
jest.mock(
    'c/leaveBalanceCard',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);
jest.mock(
    'c/leaveRequestList',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);
jest.mock(
    'c/leaveRequestForm',
    () => {
        const { LightningElement, registerDecorators } = require('lwc');
        class Stub extends LightningElement {}
        registerDecorators(Stub, { publicProps: { periodId: { config: 0 } } });
        return { __esModule: true, default: Stub };
    },
    { virtual: true }
);
jest.mock(
    'c/coreApprovalInbox',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);
jest.mock(
    'c/onboardingChecklist',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);
jest.mock(
    'c/performanceMyCycle',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);
jest.mock(
    'c/myHrTeamOverview',
    () => {
        const { LightningElement } = require('lwc');
        return { __esModule: true, default: class extends LightningElement {} };
    },
    { virtual: true }
);

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function context(overrides) {
    return {
        linked: true,
        isManager: false,
        isHr: false,
        employeeId: 'e1',
        employeeName: 'Ana Souza',
        initials: 'AS',
        positionName: 'Analista de Vendas',
        departmentName: 'Comercial',
        managerId: 'e0',
        managerName: 'Carlos Lima',
        hireDate: '2024-08-15',
        tenureMonths: 26,
        status: 'Ativo',
        statusLabel: 'Ativo',
        directReports: 0,
        hasOnboardingPlan: false,
        nextLeave: null,
        ...overrides
    };
}

function mount() {
    const el = createElement('c-my-hr-home', { is: MyHrHome });
    document.body.appendChild(el);
    return el;
}

describe('c-my-hr-home', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('colaborador: mostra cabecalho e os cartoes, sem bloco de equipe nem onboarding', async () => {
        getContext.mockResolvedValue(context());
        const el = mount();
        await flush();
        const root = el.shadowRoot;
        expect(root.querySelector('.hero-name').textContent).toBe('Ana Souza');
        expect(root.querySelector('.hero-subtitle').textContent).toBe('Analista de Vendas - Comercial');
        expect(root.querySelector('.manager-text').textContent).toBe('Gestor: Carlos Lima');
        expect(root.querySelector('.tenure-text').textContent).toBe('Tempo de casa: 2 anos e 2 meses');
        expect(root.querySelector('.hire-text').textContent).toBe('Admissão em 15/08/2024');
        expect(root.querySelector('.avatar').textContent).toBe('AS');
        expect(root.querySelector('c-leave-balance-card')).not.toBeNull();
        expect(root.querySelector('c-leave-request-list')).not.toBeNull();
        expect(root.querySelector('c-core-approval-inbox')).not.toBeNull();
        expect(root.querySelector('c-performance-my-cycle')).not.toBeNull();
        expect(root.querySelector('c-onboarding-checklist')).toBeNull();
        expect(root.querySelector('c-my-hr-team-overview')).toBeNull();
        expect(root.querySelector('.next-leave-empty').textContent).toBe('Você não tem férias programadas.');
    });

    it('gestor: mostra o bloco Minha equipe com o componente da equipe', async () => {
        getContext.mockResolvedValue(context({ isManager: true, directReports: 3 }));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.team-section')).not.toBeNull();
        expect(el.shadowRoot.querySelector('c-my-hr-team-overview')).not.toBeNull();
    });

    it('mostra o onboarding so quando existe plano', async () => {
        getContext.mockResolvedValue(context({ hasOnboardingPlan: true, onboardingPlanId: 'p1' }));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('c-onboarding-checklist')).not.toBeNull();
    });

    it('mostra as proximas ferias com intervalo, dias e situacao', async () => {
        getContext.mockResolvedValue(
            context({
                nextLeave: { startDate: '2026-12-01', endDate: '2026-12-14', days: 14, status: 'Aprovado', statusLabel: 'Aprovado' }
            })
        );
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.next-leave-range').textContent).toBe('01/12/2026 a 14/12/2026');
        expect(el.shadowRoot.querySelector('.next-leave-days').textContent).toBe('14 dias');
        expect(el.shadowRoot.querySelector('.next-leave .slds-badge').className).toContain('slds-theme_success');
        expect(el.shadowRoot.querySelector('.next-leave-empty')).toBeNull();
    });

    it('sem colaborador vinculado: estado vazio amigavel e nenhum cartao', async () => {
        getContext.mockResolvedValue({
            linked: false,
            isManager: false,
            isHr: false,
            emptyMessage: 'Seu usuário ainda não está vinculado a um colaborador. Fale com o RH.'
        });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.empty-text').textContent).toBe(
            'Seu usuário ainda não está vinculado a um colaborador. Fale com o RH.'
        );
        expect(el.shadowRoot.querySelector('.hero')).toBeNull();
        expect(el.shadowRoot.querySelector('c-leave-balance-card')).toBeNull();
    });

    it('erro do servidor: mostra o alerta e permite tentar de novo', async () => {
        getContext.mockRejectedValueOnce({ body: { message: 'Falha ao carregar.' } });
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.error h2').textContent).toBe('Falha ao carregar.');
        expect(el.shadowRoot.querySelector('.hero')).toBeNull();

        getContext.mockResolvedValueOnce(context());
        el.shadowRoot.querySelector('.retry').click();
        await flush();
        expect(el.shadowRoot.querySelector('.error')).toBeNull();
        expect(el.shadowRoot.querySelector('.hero-name').textContent).toBe('Ana Souza');
        expect(getContext).toHaveBeenCalledTimes(2);
    });

    it('sem gestor, cargo e departamento usa textos neutros', async () => {
        getContext.mockResolvedValue(context({ managerName: null, positionName: null, departmentName: null }));
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('.manager-text').textContent).toBe('Sem gestor definido');
        expect(el.shadowRoot.querySelector('.hero-subtitle').textContent).toBe('Cargo e departamento não informados');
    });

    it('requestleave do cartao abre o formulario no modal com o periodo e fecha ao enviar', async () => {
        getContext.mockResolvedValue(context());
        const el = mount();
        await flush();
        expect(el.shadowRoot.querySelector('c-my-hr-modal')).toBeNull();

        el.shadowRoot
            .querySelector('c-leave-balance-card')
            .dispatchEvent(new CustomEvent('requestleave', { detail: { periodId: 'p1' }, bubbles: true, composed: true }));
        await flush();
        const form = el.shadowRoot.querySelector('c-leave-request-form');
        expect(form).not.toBeNull();
        expect(form.periodId).toBe('p1');
        expect(el.shadowRoot.querySelector('c-my-hr-modal').heading).toBe('Solicitar férias');

        form.dispatchEvent(new CustomEvent('submitted', { detail: { requestId: 'r1' } }));
        await flush();
        expect(el.shadowRoot.querySelector('c-my-hr-modal')).toBeNull();
        expect(getContext).toHaveBeenCalledTimes(2);
    });

    it('fecha o modal pelo botao de fechar', async () => {
        getContext.mockResolvedValue(context());
        const el = mount();
        await flush();
        el.shadowRoot
            .querySelector('c-leave-balance-card')
            .dispatchEvent(new CustomEvent('requestleave', { detail: { periodId: 'p1' }, bubbles: true, composed: true }));
        await flush();
        el.shadowRoot.querySelector('c-my-hr-modal').dispatchEvent(new CustomEvent('close'));
        await flush();
        expect(el.shadowRoot.querySelector('c-my-hr-modal')).toBeNull();
    });

    it('assina o canal LeaveChanged e recarrega o contexto; cancela a assinatura ao sair', async () => {
        getContext.mockResolvedValue(context());
        subscribe.mockReturnValueOnce({ id: 'subscription' });
        const el = mount();
        await flush();
        expect(subscribe).toHaveBeenCalled();
        const listener = subscribe.mock.calls[0][2];
        listener();
        await flush();
        expect(getContext).toHaveBeenCalledTimes(2);
        document.body.removeChild(el);
        expect(unsubscribe).toHaveBeenCalled();
    });
});
