import { errorMessage, formatDate, formatRange, plural, tenureLabel, badgeClass } from 'c/myHrUtils';

describe('myHrUtils', () => {
    it('errorMessage prefere a mensagem do servidor', () => {
        expect(errorMessage({ body: { message: 'x' } })).toBe('x');
        expect(errorMessage({ message: 'y' })).toBe('y');
        expect(errorMessage(undefined)).toBe('Erro desconhecido.');
    });

    it('formata datas yyyy-MM-dd em pt-BR', () => {
        expect(formatDate('2026-10-26')).toBe('26/10/2026');
        expect(formatDate(null)).toBe('');
        expect(formatRange('2026-12-01', '2026-12-14')).toBe('01/12/2026 a 14/12/2026');
    });

    it('plural escolhe singular e plural', () => {
        expect(plural(1, 'dia', 'dias')).toBe('1 dia');
        expect(plural(0, 'dia', 'dias')).toBe('0 dias');
        expect(plural(2, 'dia', 'dias')).toBe('2 dias');
    });

    it('tenureLabel escreve anos e meses', () => {
        expect(tenureLabel(0)).toBe('menos de 1 mês');
        expect(tenureLabel(1)).toBe('1 mês');
        expect(tenureLabel(11)).toBe('11 meses');
        expect(tenureLabel(12)).toBe('1 ano');
        expect(tenureLabel(13)).toBe('1 ano e 1 mês');
        expect(tenureLabel(26)).toBe('2 anos e 2 meses');
        expect(tenureLabel(24)).toBe('2 anos');
        expect(tenureLabel(null)).toBe('');
        expect(tenureLabel(undefined)).toBe('');
    });

    it('badgeClass devolve a classe da situacao ou a padrao', () => {
        expect(badgeClass('Aprovado')).toContain('slds-theme_success');
        expect(badgeClass('Pendente')).toContain('slds-theme_warning');
        expect(badgeClass('Desconhecido')).toBe('slds-badge');
    });
});
