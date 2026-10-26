/**
 * Acesso ao registro Default de HR_Setting__mdt. Os testes podem injetar valores por testOverride.
 */
public with sharing class HrSettings {
    @TestVisible
    private static HR_Setting__mdt testOverride;

    public class HrSettingsException extends Exception {
    }

    public static HR_Setting__mdt get() {
        if (testOverride != null) {
            return testOverride;
        }
        HR_Setting__mdt setting = HR_Setting__mdt.getInstance('Default');
        if (setting == null) {
            throw new HrSettingsException('Configuração de RH padrão (HR_Setting__mdt.Default) não encontrada.');
        }
        return setting;
    }

    /** Dias de descanso semanal como numeros: 0 = domingo ... 6 = sabado. */
    public static Set<Integer> restDaysOfWeek() {
        Map<String, Integer> codes = new Map<String, Integer>{
            'SUN' => 0,
            'MON' => 1,
            'TUE' => 2,
            'WED' => 3,
            'THU' => 4,
            'FRI' => 5,
            'SAT' => 6
        };
        Set<Integer> result = new Set<Integer>();
        String raw = get().Weekly_Rest_Days__c;
        if (String.isBlank(raw)) {
            return result;
        }
        for (String part : raw.split(';')) {
            Integer code = codes.get(part.trim().toUpperCase());
            if (code != null) {
                result.add(code);
            }
        }
        return result;
    }
}
