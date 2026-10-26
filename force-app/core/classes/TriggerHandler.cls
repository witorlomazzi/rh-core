/**
 * Base simples para handlers de trigger. Cada trigger chama new XTriggerHandler().run().
 * O bypass estatico permite desligar um handler pelo nome dentro da transacao
 * (usado pelos servicos que atualizam campos mantidos por Apex e pelos testes).
 */
public virtual class TriggerHandler {
    private static Set<String> bypassedHandlers = new Set<String>();

    @TestVisible
    private System.TriggerOperation operationOverride;

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    public void run() {
        if (isBypassed(getHandlerName())) {
            return;
        }
        System.TriggerOperation op = operationOverride != null ? operationOverride : Trigger.operationType;
        switch on op {
            when BEFORE_INSERT {
                beforeInsert();
            }
            when AFTER_INSERT {
                afterInsert();
            }
            when BEFORE_UPDATE {
                beforeUpdate();
            }
            when AFTER_UPDATE {
                afterUpdate();
            }
            when BEFORE_DELETE {
                beforeDelete();
            }
            when AFTER_DELETE {
                afterDelete();
            }
            when AFTER_UNDELETE {
                afterUndelete();
            }
        }
    }

    @TestVisible
    protected String getHandlerName() {
        return String.valueOf(this).substringBefore(':');
    }

    protected virtual void beforeInsert() {
    }
    protected virtual void afterInsert() {
    }
    protected virtual void beforeUpdate() {
    }
    protected virtual void afterUpdate() {
    }
    protected virtual void beforeDelete() {
    }
    protected virtual void afterDelete() {
    }
    protected virtual void afterUndelete() {
    }
}
