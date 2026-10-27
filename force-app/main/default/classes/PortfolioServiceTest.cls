@IsTest
private class PortfolioServiceTest {
  @TestSetup
  static void setup() {
    PortfolioTestData.createContentAdmin();
    PortfolioTestData.insertSiteContent();
  }

  @IsTest
  static void returnsOnlyPublishedContent() {
    PortfolioService.SiteData data;
    System.runAs(PortfolioTestData.contentAdmin()) {
      data = PortfolioController.getSiteData();
    }

    Assert.areEqual('Test Person', data.profile.Name);
    Assert.areEqual(1, data.highlights.size());
    Assert.areEqual(1, data.projects.size());
    Assert.areEqual('Public project', data.projects[0].record.Name);
    Assert.areEqual(1, data.certifications.size());
    Assert.areEqual(1, data.experiences.size());
    Assert.isNotNull(data.generatedAt);
  }

  @IsTest
  static void skillEvidenceCountsPublishedProjectsOnly() {
    PortfolioService.SiteData data;
    System.runAs(PortfolioTestData.contentAdmin()) {
      data = PortfolioService.getSiteData();
    }

    Map<String, PortfolioService.SkillView> byName = new Map<String, PortfolioService.SkillView>();
    for (PortfolioService.SkillView skill : data.skills) {
      byName.put(skill.name, skill);
    }
    Assert.areEqual(
      new Set<String>{ 'Apex', 'LWC' },
      byName.keySet(),
      'Draft-only skills are hidden'
    );
    Assert.areEqual(1, byName.get('Apex').evidenceCount);
    Assert.areEqual(
      new List<String>{ 'public-project' },
      byName.get('Apex').projectSlugs
    );
    Assert.areEqual(2, data.projects[0].skills.size());
  }

  @IsTest
  static void userWithoutAccessGetsHandledError() {
    User noAccess = new User(Id = UserInfo.getUserId());
    PortfolioService.selector = null;
    System.runAs(noAccess) {
      try {
        PortfolioController.getSiteData();
        Assert.fail('Expected AuraHandledException');
      } catch (AuraHandledException e) {
        Assert.isNotNull(e);
      }
    }
  }
}
