import { LightningElement, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";
import getJob from "@salesforce/apex/JobPortalController.getJob";
import { workModelLabel, employmentLabel, formatDate, homeHref, DEMO_NOTICE } from "c/portalUtils";

const LOAD_ERROR = "Não foi possível carregar a vaga agora. Tente novamente em alguns minutos.";

export default class PortalJobDetail extends LightningElement {
    demoNotice = DEMO_NOTICE;
    slug = "";
    job = null;
    loading = false;
    error = "";
    notFound = false;
    // Descarta respostas de uma vaga antiga se o parametro mudar durante o carregamento.
    requestId = 0;
    started = false;

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        const fromState = pageRef && pageRef.state && pageRef.state.vaga;
        const slug = (fromState || this.slugFromLocation() || "").trim();
        if (!this.started || slug !== this.slug) {
            this.started = true;
            this.slug = slug;
            this.load();
        }
    }

    slugFromLocation() {
        try {
            return new URLSearchParams(window.location.search).get("vaga");
        } catch (e) {
            return "";
        }
    }

    async load() {
        const current = ++this.requestId;
        this.job = null;
        this.error = "";
        this.notFound = false;
        if (!this.slug) {
            this.notFound = true;
            return;
        }
        this.loading = true;
        try {
            const job = await getJob({ slug: this.slug });
            if (current !== this.requestId) {
                return;
            }
            this.job = job || null;
            this.notFound = !job;
        } catch (e) {
            if (current === this.requestId) {
                // Detalhe tecnico do servidor nunca vai para a tela.
                this.error = LOAD_ERROR;
            }
        } finally {
            if (current === this.requestId) {
                this.loading = false;
            }
        }
    }

    get homeUrl() {
        return homeHref(basePath);
    }

    get hasJob() {
        return Boolean(this.job);
    }

    get title() {
        return this.job ? this.job.title : "";
    }

    get chips() {
        if (!this.job) {
            return [];
        }
        return [
            { key: "department", label: this.job.department, cssClass: "chip chip-area" },
            { key: "workModel", label: workModelLabel(this.job.workModel), cssClass: "chip" },
            { key: "employmentType", label: employmentLabel(this.job.employmentType), cssClass: "chip" },
            { key: "location", label: this.job.location, cssClass: "chip" }
        ].filter((chip) => chip.label);
    }

    get openedText() {
        return this.job && this.job.openedDate ? `Aberta em ${formatDate(this.job.openedDate)}` : "";
    }

    get hasDescription() {
        return Boolean(this.job && this.job.description);
    }

    get hasRequirements() {
        return Boolean(this.job && this.job.requirements);
    }

    get description() {
        return this.job ? this.job.description : "";
    }

    get requirements() {
        return this.job ? this.job.requirements : "";
    }
}
