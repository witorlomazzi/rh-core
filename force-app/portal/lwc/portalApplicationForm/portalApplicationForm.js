import { LightningElement, api } from "lwc";
import getFormConfig from "@salesforce/apex/JobPortalController.getFormConfig";
import submitApplication from "@salesforce/apex/JobPortalController.submitApplication";

const GENERIC_ERROR = "Não foi possível enviar sua candidatura agora. Tente novamente em alguns minutos.";
const MAX = { name: 120, email: 80, phone: 25, city: 80, linkedInUrl: 255, message: 2000 };
const EMAIL_FORMAT = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const PHONE_FORMAT = /^[0-9+()\-\s.]{8,25}$/;
const URL_FORMAT = /^https?:\/\/\S+$/i;
// Ordem de foco quando ha mais de um erro: a mesma ordem visual do formulario.
const FIELD_ORDER = ["name", "email", "phone", "city", "linkedInUrl", "message", "consent"];

export default class PortalApplicationForm extends LightningElement {
    /** Identificador publico da vaga (Public_Slug__c). */
    @api slug;
    /** Titulo da vaga, so para o texto do formulario. */
    @api jobTitle;

    values = { name: "", email: "", phone: "", city: "", linkedInUrl: "", message: "", website: "" };
    consent = false;
    errors = {};
    formError = "";
    consentTextVersion = "";
    renderedAt = null;
    submitting = false;
    submitted = false;
    successMessage = "";

    connectedCallback() {
        this.loadConfig();
    }

    async loadConfig() {
        try {
            const config = await getFormConfig();
            this.consentTextVersion = config.consentTextVersion || "";
            this.renderedAt = config.renderedAt;
        } catch (e) {
            this.formError = "Não foi possível preparar o formulário. Recarregue a página e tente de novo.";
        }
    }

    get heading() {
        return this.jobTitle ? `Candidatar-se: ${this.jobTitle}` : "Candidatar-se";
    }

    get versionText() {
        return this.consentTextVersion ? `Versão do termo: ${this.consentTextVersion}` : "";
    }

    get submitLabel() {
        return this.submitting ? "Enviando..." : "Enviar candidatura";
    }

    get messageCount() {
        return `${this.values.message.length} de ${MAX.message} caracteres`;
    }

    get hasFormError() {
        return Boolean(this.formError);
    }

    get nameError() {
        return this.errors.name || "";
    }

    get emailError() {
        return this.errors.email || "";
    }

    get phoneError() {
        return this.errors.phone || "";
    }

    get cityError() {
        return this.errors.city || "";
    }

    get linkedInUrlError() {
        return this.errors.linkedInUrl || "";
    }

    get messageError() {
        return this.errors.message || "";
    }

    get consentError() {
        return this.errors.consent || "";
    }

    get nameInvalid() {
        return this.errors.name ? "true" : "false";
    }

    get emailInvalid() {
        return this.errors.email ? "true" : "false";
    }

    get phoneInvalid() {
        return this.errors.phone ? "true" : "false";
    }

    get cityInvalid() {
        return this.errors.city ? "true" : "false";
    }

    get linkedInUrlInvalid() {
        return this.errors.linkedInUrl ? "true" : "false";
    }

    get messageInvalid() {
        return this.errors.message ? "true" : "false";
    }

    get consentInvalid() {
        return this.errors.consent ? "true" : "false";
    }

    handleInput(event) {
        const field = event.target.dataset.field;
        this.values = { ...this.values, [field]: event.target.value };
        if (this.errors[field]) {
            this.errors = { ...this.errors, [field]: "" };
        }
    }

    handleConsent(event) {
        this.consent = event.target.checked;
        if (this.errors.consent) {
            this.errors = { ...this.errors, consent: "" };
        }
    }

    /** Mesmas regras do servidor (JobPortalService.submit), para avisar antes de enviar. O servidor decide. */
    validate() {
        const v = this.values;
        const errors = {};
        const name = v.name.trim();
        if (name.length < 2) {
            errors.name = "Informe seu nome completo.";
        } else if (name.length > MAX.name) {
            errors.name = `O nome pode ter no máximo ${MAX.name} caracteres.`;
        }
        const email = v.email.trim();
        if (!email || email.length > MAX.email || !EMAIL_FORMAT.test(email)) {
            errors.email = "Informe um e-mail válido.";
        }
        const phone = v.phone.trim();
        if (phone && !PHONE_FORMAT.test(phone)) {
            errors.phone = "Informe um telefone válido, com DDD.";
        }
        if (v.city.trim().length > MAX.city) {
            errors.city = `A cidade pode ter no máximo ${MAX.city} caracteres.`;
        }
        const linkedIn = v.linkedInUrl.trim();
        if (linkedIn && (linkedIn.length > MAX.linkedInUrl || !URL_FORMAT.test(linkedIn))) {
            errors.linkedInUrl = "Informe o endereço do LinkedIn começando com https://.";
        }
        if (v.message.length > MAX.message) {
            errors.message = `A mensagem pode ter no máximo ${MAX.message} caracteres.`;
        }
        if (!this.consent) {
            errors.consent = "É necessário aceitar o termo de privacidade.";
        }
        return errors;
    }

    focusField(field) {
        const target = this.template.querySelector(`[data-field="${field}"]`);
        if (target) {
            target.focus();
        }
    }

    focusFirstError(errors) {
        const first = FIELD_ORDER.find((field) => errors[field]);
        if (first) {
            // Aguarda o DOM refletir aria-invalid antes de mover o foco.
            Promise.resolve().then(() => this.focusField(first));
        }
    }

    async handleSubmit(event) {
        event.preventDefault();
        if (this.submitting) {
            return;
        }
        this.formError = "";
        const errors = this.validate();
        this.errors = errors;
        if (Object.keys(errors).some((field) => errors[field])) {
            this.focusFirstError(errors);
            return;
        }
        this.submitting = true;
        try {
            const result = await submitApplication({ input: this.buildInput() });
            if (result && result.success) {
                this.successMessage = result.message;
                this.submitted = true;
                return;
            }
            this.showServerError(result);
        } catch (e) {
            this.formError = GENERIC_ERROR;
        } finally {
            this.submitting = false;
        }
    }

    buildInput() {
        const v = this.values;
        return {
            slug: this.slug,
            name: v.name.trim(),
            email: v.email.trim(),
            phone: v.phone.trim(),
            city: v.city.trim(),
            linkedInUrl: v.linkedInUrl.trim(),
            message: v.message,
            consent: this.consent,
            website: v.website,
            // Texto: o runtime do site nao entrega numero grande a campo numerico do Apex.
            renderedAt: this.renderedAt == null ? null : String(this.renderedAt)
        };
    }

    showServerError(result) {
        const message = (result && result.message) || GENERIC_ERROR;
        const field = result && result.field;
        if (field && FIELD_ORDER.includes(field)) {
            this.errors = { ...this.errors, [field]: message };
            this.focusFirstError(this.errors);
        } else {
            this.formError = message;
        }
    }
}
