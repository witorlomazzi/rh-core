import { workModelLabel, employmentLabel, formatDate, jobHref, homeHref } from "c/portalUtils";

describe("c-portal-utils", () => {
    it("traduz modelo de trabalho e tipo de contratacao", () => {
        expect(workModelLabel("Hibrido")).toBe("Híbrido");
        expect(workModelLabel("Remoto")).toBe("Remoto");
        expect(workModelLabel("Outro")).toBe("Outro");
        expect(workModelLabel(null)).toBe("");
        expect(employmentLabel("Estagio")).toBe("Estágio");
        expect(employmentLabel("CLT")).toBe("CLT");
        expect(employmentLabel(undefined)).toBe("");
    });

    it("formata a data sem mudar de dia", () => {
        expect(formatDate("2026-10-12")).toBe("12/10/2026");
        expect(formatDate("")).toBe("");
        expect(formatDate(null)).toBe("");
        expect(formatDate("12/10/2026")).toBe("");
        expect(formatDate(20261012)).toBe("");
    });

    it("monta os enderecos da vaga e da lista", () => {
        expect(jobHref("/vagas", "vaga", "analista fiscal")).toBe("/vagas/vaga?vaga=analista%20fiscal");
        expect(jobHref("/vagas/", "/vaga/", "a-b")).toBe("/vagas/vaga?vaga=a-b");
        expect(jobHref("", "", "a")).toBe("/vaga?vaga=a");
        expect(homeHref("/vagas/")).toBe("/vagas/");
        expect(homeHref(undefined)).toBe("/");
    });
});
