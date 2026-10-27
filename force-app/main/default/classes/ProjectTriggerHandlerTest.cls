@IsTest
private class ProjectTriggerHandlerTest {
  @IsTest
  static void generatesSlugFromTitle() {
    PortfolioTestData.configureCompliance(new List<String>());
    Project__c project = PortfolioTestData.project(
      'Self-Healing Retry Engine (v2)!',
      'Apex',
      false
    );

    insert project;

    Assert.areEqual(
      'self-healing-retry-engine-v2',
      [SELECT Slug__c FROM Project__c WHERE Id = :project.Id].Slug__c
    );
  }

  @IsTest
  static void keepsExplicitSlug() {
    PortfolioTestData.configureCompliance(new List<String>());
    Project__c project = PortfolioTestData.project('Anything', 'Apex', false);
    project.Slug__c = 'custom-slug';

    insert project;

    Assert.areEqual(
      'custom-slug',
      [SELECT Slug__c FROM Project__c WHERE Id = :project.Id].Slug__c
    );
  }

  @IsTest
  static void bypassSkipsHandler() {
    PortfolioTestData.configureCompliance(new List<String>());
    TriggerHandler.bypass(ProjectTriggerHandler.class);

    insert PortfolioTestData.project('Bypassed', 'Apex', false);

    TriggerHandler.clearBypass(ProjectTriggerHandler.class);
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Skill__c],
      'Bypassed handler must not link skills'
    );
    Assert.isNull([SELECT Slug__c FROM Project__c LIMIT 1].Slug__c);
  }
}
