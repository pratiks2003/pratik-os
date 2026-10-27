/**
 * Project__c handler: generates slugs, enforces the confidentiality guard and
 * keeps skills linked to the project's Tech Stack.
 */
public with sharing class ProjectTriggerHandler extends PublishableContentHandler {
  protected override void beforeInsert(List<SObject> records) {
    assignSlugs((List<Project__c>) records);
    super.beforeInsert(records);
  }

  protected override void beforeUpdate(
    List<SObject> records,
    Map<Id, SObject> oldRecords
  ) {
    assignSlugs((List<Project__c>) records);
    super.beforeUpdate(records, oldRecords);
  }

  protected override void afterInsert(List<SObject> records) {
    SkillLinkService.sync((List<Project__c>) records);
  }

  protected override void afterUpdate(
    List<SObject> records,
    Map<Id, SObject> oldRecords
  ) {
    List<Project__c> changed = new List<Project__c>();
    for (Project__c project : (List<Project__c>) records) {
      Project__c previous = (Project__c) oldRecords.get(project.Id);
      if (project.Tech_Stack__c != previous.Tech_Stack__c) {
        changed.add(project);
      }
    }
    if (!changed.isEmpty()) {
      SkillLinkService.sync(changed);
    }
  }

  @TestVisible
  private static String slugify(String title) {
    return TextFingerprint.normalize(title)
      .replace(' ', '-')
      .left(80)
      .removeEnd('-');
  }

  private static void assignSlugs(List<Project__c> projects) {
    for (Project__c project : projects) {
      if (String.isBlank(project.Slug__c)) {
        project.Slug__c = slugify(project.Name);
      }
    }
  }
}
