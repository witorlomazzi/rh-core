/* eslint-disable @lwc/lwc/no-async-operation */
import { createElement } from 'lwc';
import MyHrLeave from 'c/myHrLeave';

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

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('c-my-hr-leave', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('compoe saldo, formulario e historico', () => {
        const el = createElement('c-my-hr-leave', { is: MyHrLeave });
        document.body.appendChild(el);
        expect(el.shadowRoot.querySelector('c-leave-balance-card')).not.toBeNull();
        expect(el.shadowRoot.querySelector('c-leave-request-form')).not.toBeNull();
        expect(el.shadowRoot.querySelector('c-leave-request-list')).not.toBeNull();
    });

    it('repassa o periodo do evento requestleave ao formulario', async () => {
        const el = createElement('c-my-hr-leave', { is: MyHrLeave });
        document.body.appendChild(el);
        el.shadowRoot
            .querySelector('c-leave-balance-card')
            .dispatchEvent(new CustomEvent('requestleave', { detail: { periodId: 'p9' }, bubbles: true, composed: true }));
        await flush();
        expect(el.shadowRoot.querySelector('c-leave-request-form').periodId).toBe('p9');
    });
});
