import { LightningElement, api } from "lwc";
import basePath from "@salesforce/community/basePath";
import getJobs from "@salesforce/apex/JobPortalController.getJobs";
import { workModelLabel, employmentLabel, formatDate, jobHref, DEMO_NOTICE } from "c/portalUtils";

const ALL = "";
const LOAD_ERROR = "Não foi possível carregar as vagas agora. Tente novamente em alguns minutos.";

export default class PortalJobList extends LightningElement {
    /** Nome da pagina de detalhe da vaga no site (rota sem barras). */
    @api detailPath = "vaga";

    demoNotice = DEMO_NOTICE;
    jobs = [];
    loading = true;
    error = "";
    workModel = ALL;
    department = ALL;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = "";
        try {
            const rows = await getJobs();
            this.jobs = Array.isArray(rows) ? rows : [];
        } catch (e) {
            // Detalhe tecnico do servidor nunca vai para a tela.
            this.jobs = [];
            this.error = LOAD_ERROR;
        } finally {
            this.loading = false;
        }
    }

    get cards() {
        return this.filtered.map((job) => ({
            key: job.slug,
            title: job.title,
            href: jobHref(basePath, this.detailPath, job.slug),
            department: job.department,
            location: job.location,
            workModel: workModelLabel(job.workModel),
            employmentType: employmentLabel(job.employmentType),
            openedText: job.openedDate ? `Aberta em ${formatDate(job.openedDate)}` : ""
        }));
    }

    get filtered() {
        return this.jobs.filter(
            (job) =>
                (this.workModel === ALL || job.workModel === this.workModel) &&
                (this.department === ALL || job.department === this.department)
        );
    }

    get workModelOptions() {
        const values = [...new Set(this.jobs.map((j) => j.workModel).filter(Boolean))];
        return this.buildOptions(
            values.map((v) => ({ value: v, label: workModelLabel(v) })),
            this.workModel,
            "Todos os modelos"
        );
    }

    get departmentOptions() {
        const values = [...new Set(this.jobs.map((j) => j.department).filter(Boolean))].sort((a, b) =>
            a.localeCompare(b, "pt-BR")
        );
        return this.buildOptions(
            values.map((v) => ({ value: v, label: v })),
            this.department,
            "Todas as áreas"
        );
    }

    buildOptions(items, selected, allLabel) {
        return [{ value: ALL, label: allLabel }, ...items].map((item) => ({
            ...item,
            selected: item.value === selected
        }));
    }

    get hasFilters() {
        return this.jobs.length > 0;
    }

    get hasCards() {
        return this.cards.length > 0;
    }

    get showEmpty() {
        return !this.loading && !this.error && this.cards.length === 0;
    }

    get emptyMessage() {
        return this.jobs.length === 0
            ? "No momento não há vagas abertas. Volte em breve."
            : "Nenhuma vaga encontrada com esses filtros.";
    }

    get showClear() {
        return this.workModel !== ALL || this.department !== ALL;
    }

    get countText() {
        if (this.loading || this.error) {
            return "";
        }
        const n = this.cards.length;
        return n === 1 ? "1 vaga encontrada" : `${n} vagas encontradas`;
    }

    handleWorkModel(event) {
        this.workModel = event.target.value;
    }

    handleDepartment(event) {
        this.department = event.target.value;
    }

    handleClear() {
        this.workModel = ALL;
        this.department = ALL;
    }
}
