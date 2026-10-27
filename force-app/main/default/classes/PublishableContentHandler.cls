/**
 * Shared handler for every object whose records can be published to the
 * public site: runs the confidentiality guard before any save.
 */
public virtual class PublishableContentHandler extends TriggerHandler {
  protected virtual override void beforeInsert(List<SObject> records) {
    ComplianceGuard.validate(records);
  }

  protected virtual override void beforeUpdate(
    List<SObject> records,
    Map<Id, SObject> oldRecords
  ) {
    ComplianceGuard.validate(records);
  }
}
