import { errorMessage, formatDate, formatRange, monthLabel, plural, percent, badgeClass } from 'c/leaveUtils';

describe('c/leaveUtils', () => {
    it('extrai a mensagem de erro do Apex, de Error ou usa o padrao', () => {
        expect(errorMessage({ body: { message: 'Sem acesso' } })).toBe('Sem acesso');
        expect(errorMessage(new Error('Falhou'))).toBe('Falhou');
        expect(errorMessage(undefined)).toBe('Erro desconhecido.');
    });

    it('formata datas yyyy-MM-dd sem mudar de dia', () => {
        expect(formatDate('2026-03-09')).toBe('09/03/2026');
        expect(formatDate(null)).toBe('');
        expect(formatRange('2026-03-09', '2027-03-08')).toBe('09/03/2026 a 08/03/2027');
    });

    it('monta o rotulo do mes em portugues', () => {
        expect(monthLabel(2026, 3)).toBe('março de 2026');
        expect(monthLabel(2026, 12)).toBe('dezembro de 2026');
    });

    it('trata plural e percentual', () => {
        expect(plural(1, 'dia', 'dias')).toBe('1 dia');
        expect(plural(5, 'dia', 'dias')).toBe('5 dias');
        expect(percent(15, 30)).toBe(50);
        expect(percent(40, 30)).toBe(100);
        expect(percent(5, 0)).toBe(0);
        expect(percent(-5, 30)).toBe(0);
    });

    it('escolhe a classe do badge pela situacao', () => {
        expect(badgeClass('Aprovado')).toContain('slds-theme_success');
        expect(badgeClass('Perdido')).toContain('slds-theme_error');
        expect(badgeClass('Desconhecido')).toBe('slds-badge');
    });
});
