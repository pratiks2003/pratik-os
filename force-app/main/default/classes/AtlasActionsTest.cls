@IsTest
private class AtlasActionsTest {
  @TestSetup
  static void setup() {
    PortfolioTestData.createContentAdmin();
    PortfolioTestData.insertSiteContent();
  }

  @IsTest
  static void profileSummarisesPublishedFactsOnly() {
    String profile;
    System.runAs(PortfolioTestData.contentAdmin()) {
      profile = AtlasGetProfile.getProfile(
          new List<AtlasGetProfile.Request>{ new AtlasGetProfile.Request() }
        )[0]
        .profile;
    }
    Assert.isTrue(profile.contains('Name: Test Person'));
    Assert.isTrue(profile.contains('"Public project"'));
    Assert.isTrue(profile.contains('Platform Developer II'));
    Assert.isFalse(
      profile.contains('Draft project'),
      'Drafts must never reach Atlas'
    );
  }

  @IsTest
  static void searchFindsBySkillAndFallsBackToAll() {
    AtlasSearchProjects.Request bySkill = new AtlasSearchProjects.Request();
    bySkill.searchTerm = 'lwc';
    AtlasSearchProjects.Request noMatch = new AtlasSearchProjects.Request();
    noMatch.searchTerm = 'quantum';
    List<AtlasSearchProjects.Response> results;
    System.runAs(PortfolioTestData.contentAdmin()) {
      results = new List<AtlasSearchProjects.Response>{
        AtlasSearchProjects.search(
          new List<AtlasSearchProjects.Request>{ bySkill }
        )[0],
        AtlasSearchProjects.search(
          new List<AtlasSearchProjects.Request>{ noMatch }
        )[0]
      };
    }
    Assert.isTrue(results[0].projects.contains('Public project'));
    Assert.isTrue(
      results[1].projects.startsWith('No published project matches')
    );
    Assert.isTrue(results[1].projects.contains('Public project'));
  }

  @IsTest
  static void projectDetailMatchesByPartialTitle() {
    AtlasGetProjectDetail.Request found = new AtlasGetProjectDetail.Request();
    found.projectName = 'public';
    AtlasGetProjectDetail.Request missing = new AtlasGetProjectDetail.Request();
    missing.projectName = 'draft project';
    List<AtlasGetProjectDetail.Response> results;
    System.runAs(PortfolioTestData.contentAdmin()) {
      results = new List<AtlasGetProjectDetail.Response>{
        AtlasGetProjectDetail.getDetail(
          new List<AtlasGetProjectDetail.Request>{ found }
        )[0],
        AtlasGetProjectDetail.getDetail(
          new List<AtlasGetProjectDetail.Request>{ missing }
        )[0]
      };
    }
    Assert.isTrue(results[0].found);
    Assert.isTrue(
      results[0].detail.contains('Business impact: Reduced manual work.')
    );
    Assert.isFalse(results[1].found, 'Unpublished projects are not found');
  }

  @IsTest
  static void jobMatchListsEvidencedSkills() {
    AtlasMatchJobDescription.Request request = new AtlasMatchJobDescription.Request();
    request.jobDescription = 'We need an Apex developer with Lightning Web Components (LWC) experience.';
    String evidence;
    System.runAs(PortfolioTestData.contentAdmin()) {
      evidence = AtlasMatchJobDescription.match(
          new List<AtlasMatchJobDescription.Request>{ request }
        )[0]
        .evidence;
    }
    String matched = evidence.substringBefore('Pratik\'s full skill catalogue');
    Assert.isTrue(matched.contains('Apex (Apex) proven in "Public project"'));
    Assert.isTrue(matched.contains('LWC'));
    Assert.isFalse(matched.contains('Secret Skill'));
  }

  @IsTest
  static void createInquiryValidatesAndNotifiesAdmins() {
    AtlasCreateInquiry.Request invalid = new AtlasCreateInquiry.Request();
    invalid.fullName = 'Sam Recruiter';
    invalid.email = 'not-an-email';
    AtlasCreateInquiry.Request valid = new AtlasCreateInquiry.Request();
    valid.fullName = 'Sam Recruiter';
    valid.email = 'sam@example.com';
    valid.company = 'Example Co';
    valid.roleHiringFor = 'Salesforce Developer';
    valid.interestScore = 42;

    List<AtlasCreateInquiry.Response> results;
    System.runAs(PortfolioTestData.contentAdmin()) {
      Test.startTest();
      results = AtlasCreateInquiry.create(
        new List<AtlasCreateInquiry.Request>{ invalid, valid }
      );
      Test.stopTest();
    }

    Assert.isFalse(results[0].success);
    Assert.isTrue(results[1].success);
    Assert.isTrue(results[1].reference.startsWith('INQ-'));
    Inquiry__c saved = [
      SELECT Source__c, Interest_Score__c, Status__c
      FROM Inquiry__c
    ];
    Assert.areEqual('Atlas', saved.Source__c);
    Assert.areEqual(10, saved.Interest_Score__c, 'Score is clamped to 1-10');
    Assert.areEqual('New', saved.Status__c);
    Assert.isTrue(
      InquiryNotifier.sentCount > 0,
      'Portfolio admins are emailed'
    );
    Assert.isTrue(
      [SELECT Notification_Status__c FROM Inquiry__c]
        .Notification_Status__c.contains('Emailed'),
      'The outcome of the alert is recorded on the inquiry'
    );
  }

  @IsTest
  static void specialisedSkillsCountAsEvidenceForBroadOnes() {
    PortfolioTestData.configureCompliance(new List<String>());
    insert PortfolioTestData.project('Async engine', 'Queueable Apex', true);
    AtlasMatchJobDescription.Request request = new AtlasMatchJobDescription.Request();
    request.jobDescription = 'Strong Apex required.';
    String evidence;
    System.runAs(PortfolioTestData.contentAdmin()) {
      evidence = AtlasMatchJobDescription.match(
          new List<AtlasMatchJobDescription.Request>{ request }
        )[0]
        .evidence;
    }
    String matched = evidence.substringBefore('Pratik\'s full skill catalogue');
    Assert.isTrue(matched.contains('Queueable Apex'), matched);
    Assert.isFalse(matched.contains('LWC'), 'Unrelated skills are not matched');
  }
}
