import { createElement } from 'lwc';
import MyHrModal from 'c/myHrModal';

function mount(props = {}) {
    const el = createElement('c-my-hr-modal', { is: MyHrModal });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

describe('c-my-hr-modal', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('mostra o titulo e usa o tamanho informado', () => {
        const el = mount({ heading: 'Solicitar férias', size: 'large' });
        expect(el.shadowRoot.querySelector('.modal-title').textContent).toBe('Solicitar férias');
        expect(el.shadowRoot.querySelector('section').className).toContain('slds-modal_large');
        expect(el.shadowRoot.querySelector('section').getAttribute('aria-modal')).toBe('true');
    });

    it('usa o tamanho medio por padrao', () => {
        const el = mount({ heading: 'X' });
        expect(el.shadowRoot.querySelector('section').className).toContain('slds-modal_medium');
    });

    it('dispara close pelo botao, pelo fundo e pela tecla Esc', () => {
        const el = mount({ heading: 'X' });
        const onClose = jest.fn();
        el.addEventListener('close', onClose);
        el.shadowRoot.querySelector('.close').click();
        el.shadowRoot.querySelector('.backdrop').click();
        el.shadowRoot.querySelector('section').dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
        expect(onClose).toHaveBeenCalledTimes(3);
    });

    it('outras teclas nao fecham', () => {
        const el = mount({ heading: 'X' });
        const onClose = jest.fn();
        el.addEventListener('close', onClose);
        el.shadowRoot.querySelector('section').dispatchEvent(new KeyboardEvent('keydown', { key: 'a' }));
        expect(onClose).not.toHaveBeenCalled();
    });
});
