/**
 * Funcoes compartilhadas do Meu RH. Datas chegam do Apex como yyyy-MM-dd e sao tratadas sem fuso.
 */
export function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

/** yyyy-MM-dd para dd/MM/yyyy. Valor vazio devolve texto vazio. */
export function formatDate(iso) {
    if (!iso) {
        return '';
    }
    const [year, month, day] = String(iso).split('-');
    return `${day}/${month}/${year}`;
}

export function formatRange(startIso, endIso) {
    return `${formatDate(startIso)} a ${formatDate(endIso)}`;
}

export function plural(count, singular, pluralForm) {
    return `${count} ${count === 1 ? singular : pluralForm}`;
}

/** Tempo de casa em texto a partir de meses completos. */
export function tenureLabel(months) {
    if (months === null || months === undefined) {
        return '';
    }
    if (months < 1) {
        return 'menos de 1 mês';
    }
    const years = Math.floor(months / 12);
    const rest = months % 12;
    const yearText = plural(years, 'ano', 'anos');
    const monthText = plural(rest, 'mês', 'meses');
    if (years === 0) {
        return monthText;
    }
    return rest === 0 ? yearText : `${yearText} e ${monthText}`;
}

const BADGES = {
    Pendente: 'slds-badge slds-theme_warning',
    Aprovado: 'slds-badge slds-theme_success',
    Em_Gozo: 'slds-badge slds-theme_info',
    Ativo: 'slds-badge slds-theme_success',
    Ferias: 'slds-badge slds-theme_info',
    Afastado: 'slds-badge slds-theme_warning',
    Pre_Admissao: 'slds-badge',
    Desligado: 'slds-badge slds-badge_lightest',
    Liberada: 'slds-badge slds-theme_success',
    Calibrada: 'slds-badge slds-theme_info',
    Enviada: 'slds-badge slds-theme_info',
    Em_Andamento: 'slds-badge slds-theme_warning'
};

export function badgeClass(status) {
    return BADGES[status] || 'slds-badge';
}
