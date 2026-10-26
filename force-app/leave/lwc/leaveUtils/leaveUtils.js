/**
 * Funcoes compartilhadas dos componentes de ferias: mensagem de erro, datas em pt-BR e rotulos.
 * As datas chegam do Apex como texto yyyy-MM-dd e sao tratadas sem fuso para nao mudar de dia.
 */
export const MONTH_NAMES = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro'
];

export const WEEKDAY_INITIALS = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
export const WEEKDAY_NAMES = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];

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

export function monthLabel(year, month) {
    return `${MONTH_NAMES[month - 1]} de ${year}`;
}

export function plural(count, singular, pluralForm) {
    return `${count} ${count === 1 ? singular : pluralForm}`;
}

/** Percentual inteiro entre 0 e 100. */
export function percent(part, total) {
    if (!total || total <= 0) {
        return 0;
    }
    return Math.max(0, Math.min(100, Math.round((part / total) * 100)));
}

/** Classes de badge SLDS por situacao do periodo aquisitivo ou da solicitacao. */
export const STATUS_BADGE = {
    Em_Aquisicao: 'slds-badge',
    Disponivel: 'slds-badge slds-theme_success',
    Prazo_Proximo: 'slds-badge slds-theme_warning',
    Concluido: 'slds-badge slds-badge_lightest',
    Perdido: 'slds-badge slds-theme_error',
    Rascunho: 'slds-badge',
    Pendente: 'slds-badge slds-theme_warning',
    Aprovado: 'slds-badge slds-theme_success',
    Rejeitado: 'slds-badge slds-theme_error',
    Cancelado: 'slds-badge slds-badge_lightest',
    Em_Gozo: 'slds-badge slds-theme_info'
};

export function badgeClass(status) {
    return STATUS_BADGE[status] || 'slds-badge';
}
