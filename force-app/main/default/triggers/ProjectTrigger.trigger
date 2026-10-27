trigger ProjectTrigger on Project__c(
  before insert,
  before update,
  after insert,
  after update
) {
  new ProjectTriggerHandler().run();
}
