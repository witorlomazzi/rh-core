import { createElement } from "lwc";
import PortalJobDetail from "c/portalJobDetail";
import { CurrentPageReference } from "lightning/navigation";
import getJob from "@salesforce/apex/JobPortalController.getJob";

jest.mock("@salesforce/apex/JobPortalController.getJob", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobPortalController.getFormConfig", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobPortalController.submitApplication", () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock("@salesforce/community/basePath", () => ({ __esModule: true, default: "/vagas" }), { virtual: true });

const JOB = {
    title: "Analista Fiscal",
    slug: "analista-fiscal",
    department: "Financeiro",
    location: "São Paulo",
    workModel: "Hibrido",
    employmentType: "CLT",
    description: "<p>Cuida da apuração de impostos.</p>",
    requirements: "<ul><li>Contabilidade</li></ul>",
    openedDate: "2026-10-12"
};

async function flush() {
    for (let i = 0; i < 10; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
}

async function mount(state) {
    const el = createElement("c-portal-job-detail", { is: PortalJobDetail });
    document.body.appendChild(el);
    CurrentPageReference.emit({ type: "comm__namedPage", state });
    await flush();
    return el;
}

describe("c-portal-job-detail", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("le o identificador da URL e mostra a vaga com o formulario de candidatura", async () => {
        getJob.mockResolvedValue(JOB);
        const el = await mount({ vaga: "analista-fiscal" });

        expect(getJob).toHaveBeenCalledWith({ slug: "analista-fiscal" });
        expect(el.shadowRoot.querySelector("h1").textContent).toBe("Analista Fiscal");
        const chips = Array.from(el.shadowRoot.querySelectorAll(".chip")).map((c) => c.textContent);
        expect(chips).toEqual(["Financeiro", "Híbrido", "CLT", "São Paulo"]);
        expect(el.shadowRoot.querySelector(".opened").textContent).toBe("Aberta em 12/10/2026");
        const richTexts = el.shadowRoot.querySelectorAll("lightning-formatted-rich-text");
        expect(richTexts).toHaveLength(2);
        expect(richTexts[0].value).toBe("<p>Cuida da apuração de impostos.</p>");
        const form = el.shadowRoot.querySelector("c-portal-application-form");
        expect(form).not.toBeNull();
        expect(form.slug).toBe("analista-fiscal");
        expect(form.jobTitle).toBe("Analista Fiscal");
        expect(el.shadowRoot.querySelector(".back").getAttribute("href")).toBe("/vagas/");
        expect(el.shadowRoot.querySelector(".notice").textContent).toContain("Projeto demonstrativo");
    });

    it("mostra o carregamento enquanto aguarda o servidor", async () => {
        let resolve;
        getJob.mockReturnValue(new Promise((r) => (resolve = r)));
        const el = await mount({ vaga: "analista-fiscal" });
        expect(el.shadowRoot.querySelector('[role="status"]').textContent).toBe("Carregando vaga...");
        expect(el.shadowRoot.querySelector("c-portal-application-form")).toBeNull();
        resolve(JOB);
        await flush();
        expect(el.shadowRoot.querySelector("h1").textContent).toBe("Analista Fiscal");
    });

    it("mostra vaga nao encontrada quando o servidor nao devolve a vaga", async () => {
        getJob.mockResolvedValue(null);
        const el = await mount({ vaga: "encerrada" });
        expect(el.shadowRoot.querySelector("h1").textContent).toBe("Vaga não encontrada");
        expect(el.shadowRoot.querySelector("c-portal-application-form")).toBeNull();
    });

    it("mostra vaga nao encontrada sem chamar o servidor quando a URL nao traz o parametro", async () => {
        const el = await mount({});
        expect(getJob).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector("h1").textContent).toBe("Vaga não encontrada");
    });

    it("mostra erro amigavel sem detalhe tecnico quando o servidor falha", async () => {
        getJob.mockRejectedValue({ body: { message: "System.QueryException: detalhe interno" } });
        const el = await mount({ vaga: "analista-fiscal" });
        const alert = el.shadowRoot.querySelector('[role="alert"]');
        expect(alert.textContent).toBe("Não foi possível carregar a vaga agora. Tente novamente em alguns minutos.");
        expect(el.shadowRoot.querySelector("c-portal-application-form")).toBeNull();
    });

    it("recarrega quando o parametro da URL muda", async () => {
        getJob
            .mockResolvedValueOnce(JOB)
            .mockResolvedValueOnce({ ...JOB, title: "Analista de Custos", slug: "custos" });
        const el = await mount({ vaga: "analista-fiscal" });
        CurrentPageReference.emit({ type: "comm__namedPage", state: { vaga: "custos" } });
        await flush();
        expect(getJob).toHaveBeenLastCalledWith({ slug: "custos" });
        expect(el.shadowRoot.querySelector("h1").textContent).toBe("Analista de Custos");
    });

    it("omite os blocos de texto vazios", async () => {
        getJob.mockResolvedValue({ ...JOB, description: null, requirements: null, openedDate: null, department: null });
        const el = await mount({ vaga: "analista-fiscal" });
        expect(el.shadowRoot.querySelectorAll("lightning-formatted-rich-text")).toHaveLength(0);
        expect(el.shadowRoot.querySelector(".opened").textContent).toBe("");
        const chips = Array.from(el.shadowRoot.querySelectorAll(".chip")).map((c) => c.textContent);
        expect(chips).toEqual(["Híbrido", "CLT", "São Paulo"]);
    });
});
