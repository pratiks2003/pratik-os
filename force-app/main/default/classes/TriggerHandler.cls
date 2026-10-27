/**
 * Minimal trigger framework. Each object has one trigger that delegates to a
 * handler; handlers override only the events they care about. Handlers can be
 * bypassed by type for bulk data loads and tests.
 */
public virtual class TriggerHandler {
  private static final Set<String> BYPASSED = new Set<String>();

  @TestVisible
  private System.TriggerOperation operation = Trigger.operationType;
  @TestVisible
  private List<SObject> newRecords = Trigger.new;
  @TestVisible
  private Map<Id, SObject> oldMap = Trigger.oldMap;

  public void run() {
    if (BYPASSED.contains(handlerName())) {
      return;
    }
    switch on operation {
      when BEFORE_INSERT {
        beforeInsert(newRecords);
      }
      when BEFORE_UPDATE {
        beforeUpdate(newRecords, oldMap);
      }
      when AFTER_INSERT {
        afterInsert(newRecords);
      }
      when AFTER_UPDATE {
        afterUpdate(newRecords, oldMap);
      }
      when else {
        return;
      }
    }
  }

  public static void bypass(Type handlerType) {
    BYPASSED.add(handlerType.getName());
  }

  public static void clearBypass(Type handlerType) {
    BYPASSED.remove(handlerType.getName());
  }

  protected virtual void beforeInsert(List<SObject> records) {
    return;
  }

  protected virtual void beforeUpdate(
    List<SObject> records,
    Map<Id, SObject> oldRecords
  ) {
    return;
  }

  protected virtual void afterInsert(List<SObject> records) {
    return;
  }

  protected virtual void afterUpdate(
    List<SObject> records,
    Map<Id, SObject> oldRecords
  ) {
    return;
  }

  private String handlerName() {
    return String.valueOf(this).substringBefore(':');
  }
}
