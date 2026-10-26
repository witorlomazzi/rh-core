/**
 * Excecao de regra de negocio do modulo de desempenho e conversao para AuraHandledException nos controllers.
 */
public with sharing class ReviewErrors {
    public class ReviewException extends Exception {
    }

    /** Mensagem amigavel: regra de negocio e validacao de trigger voltam como estao; o resto ganha um prefixo. */
    public static AuraHandledException toAura(Exception e) {
        if (e instanceof AuraHandledException) {
            return (AuraHandledException) e;
        }
        String message;
        if (e instanceof ReviewException) {
            message = e.getMessage();
        } else if (e instanceof DmlException && ((DmlException) e).getNumDml() > 0) {
            message = ((DmlException) e).getDmlMessage(0);
        } else {
            message = 'Não foi possível concluir a operação. ' + e.getMessage();
        }
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
