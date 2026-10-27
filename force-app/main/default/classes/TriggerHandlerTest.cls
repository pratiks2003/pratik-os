@IsTest
private class TriggerHandlerTest {
  @IsTest
  static void baseHandlerIgnoresEveryEvent() {
    TriggerHandler handler = new TriggerHandler();
    handler.newRecords = new List<SObject>();
    handler.oldMap = new Map<Id, SObject>();

    for (
      System.TriggerOperation operation : new List<System.TriggerOperation>{
        System.TriggerOperation.BEFORE_INSERT,
        System.TriggerOperation.BEFORE_UPDATE,
        System.TriggerOperation.AFTER_INSERT,
        System.TriggerOperation.AFTER_UPDATE,
        System.TriggerOperation.AFTER_DELETE
      }
    ) {
      handler.operation = operation;
      handler.run();
    }

    Assert.areEqual(0, Limits.getDmlStatements(), 'Base handler does no work');
  }
}
