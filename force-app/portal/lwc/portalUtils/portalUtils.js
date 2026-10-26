// Funcoes compartilhadas pelos componentes do portal publico de vagas (sem interface propria).

const WORK_MODEL_LABELS = { Presencial: "Presencial", Hibrido: "Híbrido", Remoto: "Remoto" };
const EMPLOYMENT_LABELS = { CLT: "CLT", Estagio: "Estágio", PJ: "PJ" };

export const DEMO_NOTICE =
    "Projeto demonstrativo, com empresa e dados fictícios. Experiências profissionais reais não são publicadas por confidencialidade.";

export function workModelLabel(value) {
    return WORK_MODEL_LABELS[value] || value || "";
}

export function employmentLabel(value) {
    return EMPLOYMENT_LABELS[value] || value || "";
}

/** Converte "2026-10-12" em "12/10/2026" sem passar por fuso horario. */
export function formatDate(value) {
    if (!value || typeof value !== "string") {
        return "";
    }
    const parts = value.split("-");
    if (parts.length !== 3) {
        return "";
    }
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

/** Endereco da pagina de uma vaga: <base do site>/<pagina de detalhe>?vaga=<slug>. */
export function jobHref(basePath, detailPath, slug) {
    const base = (basePath || "").replace(/\/+$/, "");
    const page = (detailPath || "vaga").replace(/^\/+|\/+$/g, "");
    return `${base}/${page}?vaga=${encodeURIComponent(slug)}`;
}

/** Endereco da lista de vagas (pagina inicial do site). */
export function homeHref(basePath) {
    const base = (basePath || "").replace(/\/+$/, "");
    return `${base}/`;
}
