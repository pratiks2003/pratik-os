@IsTest
private class SkillLinkServiceTest {
  @IsTest
  static void createsAndLinksSkillsFromTechStack() {
    PortfolioTestData.configureCompliance(new List<String>());
    Project__c project = PortfolioTestData.project(
      'Engine',
      'Apex, LWC; apex , Platform Events\nGitHub Actions',
      true
    );

    Test.startTest();
    insert project;
    Test.stopTest();

    Map<String, Skill__c> skills = new Map<String, Skill__c>();
    for (Skill__c skill : [SELECT Name, Key__c, Category__c FROM Skill__c]) {
      skills.put(skill.Key__c, skill);
    }
    Assert.areEqual(
      4,
      skills.size(),
      'Duplicate "apex" must collapse into one skill'
    );
    Assert.areEqual('Apex', skills.get('apex').Name, 'First spelling is kept');
    Assert.areEqual('Integration', skills.get('platform events').Category__c);
    Assert.areEqual('LWC', skills.get('lwc').Category__c);
    Assert.areEqual('DevOps', skills.get('github actions').Category__c);
    Assert.areEqual(
      4,
      [SELECT COUNT() FROM Project_Skill__c WHERE Project__c = :project.Id]
    );
  }

  @IsTest
  static void updatingTechStackAddsAndRemovesLinks() {
    PortfolioTestData.configureCompliance(new List<String>());
    Project__c project = PortfolioTestData.project(
      'Engine',
      'Apex, Platform Events',
      true
    );
    insert project;

    Test.startTest();
    project.Tech_Stack__c = 'Apex, Queueable Apex';
    update project;
    Test.stopTest();

    Set<String> linked = new Set<String>();
    for (Project_Skill__c link : [
      SELECT Skill__r.Key__c
      FROM Project_Skill__c
      WHERE Project__c = :project.Id
    ]) {
      linked.add(link.Skill__r.Key__c);
    }
    Assert.areEqual(new Set<String>{ 'apex', 'queueable apex' }, linked);
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Skill__c WHERE Key__c = 'platform events'],
      'Skills are kept'
    );
  }

  @IsTest
  static void reusesExistingSkillsAcrossProjects() {
    PortfolioTestData.configureCompliance(new List<String>());
    insert PortfolioTestData.project('First', 'Apex', true);
    insert PortfolioTestData.project('Second', 'APEX', true);

    Assert.areEqual(1, [SELECT COUNT() FROM Skill__c]);
    Assert.areEqual(2, [SELECT COUNT() FROM Project_Skill__c]);
  }

  @IsTest
  static void bulkInsertStaysWithinLimits() {
    PortfolioTestData.configureCompliance(new List<String>());
    List<Project__c> projects = new List<Project__c>();
    for (Integer i = 0; i < 200; i++) {
      projects.add(
        PortfolioTestData.project('Project ' + i, 'Apex, LWC, Skill ' + i, true)
      );
    }

    Test.startTest();
    insert projects;
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(202, [SELECT COUNT() FROM Skill__c]);
    Assert.areEqual(600, [SELECT COUNT() FROM Project_Skill__c]);
    Assert.isTrue(
      queries < 10,
      'Expected a constant number of queries, got ' + queries
    );
  }

  @IsTest
  static void blankTechStackCreatesNothing() {
    PortfolioTestData.configureCompliance(new List<String>());
    insert PortfolioTestData.project('Empty', ' , ;', true);

    Assert.areEqual(0, [SELECT COUNT() FROM Skill__c]);
  }

  @IsTest
  static void categorizerRecognisesCommonSkills() {
    Assert.areEqual(
      'Apex',
      SkillCategorizer.categorize('database convertlead')
    );
    Assert.areEqual(
      'Architecture',
      SkillCategorizer.categorize('service layer')
    );
    Assert.areEqual(
      'Integration',
      SkillCategorizer.categorize('conflict resolution')
    );
    Assert.areEqual(
      'Platform',
      SkillCategorizer.categorize('custom metadata types')
    );
  }
}
