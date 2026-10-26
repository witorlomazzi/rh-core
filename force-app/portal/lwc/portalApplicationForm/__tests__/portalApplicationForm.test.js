import { createElement } from 'lwc';
import PortalApplicationForm from 'c/portalApplicationForm';
import getFormConfig from '@salesforce/apex/JobPortalController.getFormConfig';
import submitApplication from '@salesforce/apex/JobPortalController.submitApplication';

jest.mock('@salesforce/apex/JobPortalController.getFormConfig', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/JobPortalController.submitApplication', () => ({ default: jest.fn() }), {
    virtual: true
});

async function flush() {
    for (let i = 0; i < 10; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
}

async function mount() {
    getFormConfig.mockResolvedValue({ consentTextVersion: '2026-10', renderedAt: 1790000000000 });
    const el = createElement('c-portal-application-form', { is: PortalApplicationForm });
    el.slug = 'analista-fiscal';
    el.jobTitle = 'Analista Fiscal';
    document.body.appendChild(el);
    await flush();
    return el;
}

function field(el, name) {
    return el.shadowRoot.querySelector(`[data-field="${name}"]`);
}

async function type(el, name, value) {
    const input = field(el, name);
    input.value = value;
    input.dispatchEvent(new CustomEvent('input'));
    await flush();
}

async function accept(el) {
    const box = field(el, 'consent');
    box.checked = true;
    box.dispatchEvent(new CustomEvent('change'));
    await flush();
}

async function submit(el) {
    el.shadowRoot.querySelector('form').dispatchEvent(new CustomEvent('submit'));
    await flush();
}

async function fillValid(el) {
    await type(el, 'name', 'Maria Souza');
    await type(el, 'email', 'maria@example.com');
    await type(el, 'phone', '(11) 91234-5678');
    await type(el, 'city', 'São Paulo');
    await type(el, 'linkedInUrl', 'https://www.linkedin.com/in/maria');
    await type(el, 'message', 'Tenho interesse.');
    await accept(el);
}

describe('c-portal-application-form', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra o titulo da vaga, o termo de privacidade e a versao', async () => {
        const el = await mount();
        expect(el.shadowRoot.querySelector('.heading').textContent).toBe('Candidatar-se: Analista Fiscal');
        expect(el.shadowRoot.querySelector('.privacy-text').textContent).toContain('Lei');
        expect(el.shadowRoot.querySelector('.privacy-version').textContent).toBe('Versão do termo: 2026-10');
        expect(el.shadowRoot.querySelector('legend').textContent).toBe('Termo de privacidade');
    });

    it('liga cada campo ao seu rotulo e a sua mensagem de erro', async () => {
        const el = await mount();
        ['name', 'email', 'phone', 'city', 'linkedInUrl', 'message', 'consent'].forEach((name) => {
            const control = field(el, name);
            expect(control.getAttribute('aria-describedby')).toBeTruthy();
            const label = el.shadowRoot.querySelector(`label[for="${control.id}"]`);
            expect(label).not.toBeNull();
        });
    });

    it('esconde o honeypot de leitores de tela e do teclado', async () => {
        const el = await mount();
        const trap = el.shadowRoot.querySelector('.trap');
        expect(trap.getAttribute('aria-hidden')).toBe('true');
        const input = field(el, 'website');
        expect(input.getAttribute('tabindex')).toBe('-1');
        expect(input.getAttribute('autocomplete')).toBe('off');
    });

    it('valida os campos no navegador, mostra erro ligado ao campo e nao chama o servidor', async () => {
        const el = await mount();
        await type(el, 'name', 'A');
        await type(el, 'email', 'sem-arroba');
        await type(el, 'phone', 'telefone');
        await type(el, 'linkedInUrl', 'ftp://x');
        await submit(el);

        expect(submitApplication).not.toHaveBeenCalled();
        const texts = Array.from(el.shadowRoot.querySelectorAll('.error')).map((e) => e.textContent);
        expect(texts).toEqual(
            expect.arrayContaining([
                'Informe seu nome completo.',
                'Informe um e-mail válido.',
                'Informe um telefone válido, com DDD.',
                'Informe o endereço do LinkedIn começando com https://.',
                'É necessário aceitar o termo de privacidade.'
            ])
        );
        expect(field(el, 'name').getAttribute('aria-invalid')).toBe('true');
        expect(field(el, 'consent').getAttribute('aria-invalid')).toBe('true');
        expect(field(el, 'city').getAttribute('aria-invalid')).toBe('false');
    });

    it('limpa o erro de um campo quando a pessoa volta a digitar', async () => {
        const el = await mount();
        await submit(el);
        expect(field(el, 'email').getAttribute('aria-invalid')).toBe('true');
        await type(el, 'email', 'maria@example.com');
        expect(field(el, 'email').getAttribute('aria-invalid')).toBe('false');
    });

    it('envia os dados e mostra a mensagem de sucesso', async () => {
        submitApplication.mockResolvedValue({
            success: true,
            message: 'Candidatura enviada. Obrigado pelo interesse!'
        });
        const el = await mount();
        await fillValid(el);
        await submit(el);

        expect(submitApplication).toHaveBeenCalledTimes(1);
        expect(submitApplication).toHaveBeenCalledTimes(1);
        expect(JSON.parse(submitApplication.mock.calls[0][0].payload)).toEqual({
            slug: 'analista-fiscal',
            name: 'Maria Souza',
            email: 'maria@example.com',
            phone: '(11) 91234-5678',
            city: 'São Paulo',
            linkedInUrl: 'https://www.linkedin.com/in/maria',
            message: 'Tenho interesse.',
            consent: true,
            website: '',
            renderedAt: '1790000000000'
        });
        const success = el.shadowRoot.querySelector('.success');
        expect(success.getAttribute('role')).toBe('status');
        expect(success.textContent).toContain('Candidatura enviada');
        expect(el.shadowRoot.querySelector('form')).toBeNull();
    });

    it('mostra erro do servidor ligado ao campo e mantem os dados digitados', async () => {
        submitApplication.mockResolvedValue({ success: false, message: 'Informe um e-mail válido.', field: 'email' });
        const el = await mount();
        await fillValid(el);
        await submit(el);

        expect(field(el, 'email').getAttribute('aria-invalid')).toBe('true');
        expect(field(el, 'email').parentElement.querySelector('.error').textContent).toBe('Informe um e-mail válido.');
        expect(field(el, 'name').value).toBe('Maria Souza');
        expect(el.shadowRoot.querySelector('.success')).toBeNull();
    });

    it('mostra erro geral amigavel quando o servidor recusa sem campo ou falha', async () => {
        submitApplication.mockResolvedValueOnce({ success: false, message: 'Limite diário de candidaturas atingido.' });
        const el = await mount();
        await fillValid(el);
        await submit(el);
        let alert = el.shadowRoot.querySelector('.form-error');
        expect(alert.getAttribute('role')).toBe('alert');
        expect(alert.textContent).toBe('Limite diário de candidaturas atingido.');

        submitApplication.mockRejectedValueOnce({ body: { message: 'System.NullPointerException: detalhe' } });
        await submit(el);
        alert = el.shadowRoot.querySelector('.form-error');
        expect(alert.textContent).toBe(
            'Não foi possível enviar sua candidatura agora. Tente novamente em alguns minutos.'
        );
        expect(alert.textContent).not.toContain('NullPointer');
    });

    it('envia o valor do honeypot para o servidor decidir', async () => {
        submitApplication.mockResolvedValue({ success: true, message: 'ok' });
        const el = await mount();
        await fillValid(el);
        await type(el, 'website', 'http://spam.example.com');
        await submit(el);
        expect(JSON.parse(submitApplication.mock.calls[0][0].payload).website).toBe('http://spam.example.com');
    });

    it('nao envia duas vezes enquanto aguarda a resposta', async () => {
        let resolve;
        submitApplication.mockReturnValue(new Promise((r) => (resolve = r)));
        const el = await mount();
        await fillValid(el);
        await submit(el);
        await submit(el);
        expect(submitApplication).toHaveBeenCalledTimes(1);
        expect(el.shadowRoot.querySelector('.submit').disabled).toBe(true);
        expect(el.shadowRoot.querySelector('.submit').textContent.trim()).toBe('Enviando...');
        resolve({ success: true, message: 'ok' });
        await flush();
        expect(el.shadowRoot.querySelector('.success')).not.toBeNull();
    });

    it('avisa quando a configuracao do formulario nao carrega', async () => {
        getFormConfig.mockRejectedValue(new Error('falha'));
        const el = createElement('c-portal-application-form', { is: PortalApplicationForm });
        document.body.appendChild(el);
        await flush();
        expect(el.shadowRoot.querySelector('.form-error').textContent).toContain(
            'Não foi possível preparar o formulário'
        );
    });
});
