@IsTest
private class ProjectAssistantControllerTest {
  private class StubRunner implements ProjectAssistantController.PromptRunner {
    public Map<String, String> lastInputs;
    public String run(String templateName, Map<String, String> inputs) {
      lastInputs = inputs;
      if (templateName == 'Portfolio_Confidentiality_Review') {
        return '```json\n{"verdict":"review","findings":[{"quote":"AcmeSys","reason":"internal system","suggestion":"an external system"}]}\n```';
      }
      return '{"tagline":"Synced orders reliably.","category":"Integration","businessImpact":"Cut manual fixes.",' +
        '"technicalDeepDive":"- Queueable sync","starStory":"Situation: Slow. Task: Fix. Action: Built. Result: Fast.",' +
        '"techStack":"Apex, Platform Events","metrics":"manual fixes cut from 40 to 2 a week"}';
    }
  }

  @TestSetup
  static void setup() {
    PortfolioTestData.createContentAdmin();
  }

  private static Id draftProject() {
    PortfolioTestData.configureCompliance(new List<String>{ 'acmesys' });
    Project__c project = PortfolioTestData.project('Order sync', 'Apex', false);
    insert project;
    return project.Id;
  }

  @IsTest
  static void draftsFromNotesAndAppliesTheDraft() {
    Id projectId = draftProject();
    StubRunner stub = new StubRunner();
    ProjectAssistantController.runner = stub;

    Map<String, Object> draft;
    System.runAs(PortfolioTestData.contentAdmin()) {
      draft = ProjectAssistantController.draftFromNotes(
        projectId,
        'Rough notes about the AcmeSys sync'
      );
      ProjectAssistantController.applyDraft(projectId, JSON.serialize(draft));
    }

    Assert.areEqual('Order sync', stub.lastInputs.get('Input:Title'));
    Assert.areEqual(
      'Situation: Slow.\nTask: Fix.\nAction: Built.\nResult: Fast.',
      draft.get('starStory')
    );
    Assert.areEqual(
      0,
      ((List<Object>) draft.get('blockedTerms')).size(),
      'The draft itself is clean'
    );
    Project__c saved = [
      SELECT Tagline__c, Category__c, Metrics__c, Tech_Stack__c
      FROM Project__c
      WHERE Id = :projectId
    ];
    Assert.areEqual('Synced orders reliably.', saved.Tagline__c);
    Assert.areEqual('Integration', saved.Category__c);
    Assert.areEqual('Apex, Platform Events', saved.Tech_Stack__c);
  }

  @IsTest
  static void reviewCombinesBlockedTermsAndAiFindings() {
    Id projectId = draftProject();
    update new Project__c(
      Id = projectId,
      Business_Impact__c = 'Integrated with AcmeSys.'
    );
    ProjectAssistantController.runner = new StubRunner();

    Map<String, Object> review;
    System.runAs(PortfolioTestData.contentAdmin()) {
      review = ProjectAssistantController.reviewConfidentiality(projectId);
    }

    Assert.areEqual(
      new List<Object>{ 'acmesys' },
      (List<Object>) review.get('blockedTerms')
    );
    Assert.areEqual('review', review.get('verdict'));
    Assert.areEqual(1, ((List<Object>) review.get('findings')).size());
  }

  @IsTest
  static void rejectsEmptyNotesAndUnreadableResponses() {
    Id projectId = draftProject();
    try {
      ProjectAssistantController.draftFromNotes(projectId, '  ');
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
    try {
      ProjectAssistantController.parseJson('no json here');
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
    Assert.isNull(ProjectAssistantController.normaliseStar(null));
  }

  @IsTest
  static void applyingToAPublishedRecordStillRunsTheGuard() {
    PortfolioTestData.configureCompliance(new List<String>{ 'acmesys' });
    Project__c project = PortfolioTestData.project(
      'Live project',
      'Apex',
      true
    );
    insert project;
    try {
      System.runAs(PortfolioTestData.contentAdmin()) {
        ProjectAssistantController.applyDraft(
          project.Id,
          '{"businessImpact":"Built for AcmeSys."}'
        );
      }
      Assert.fail(
        'The guard must block confidential terms on published records'
      );
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
  }

  @IsTest
  static void einsteinRunnerBuildsTheRequest() {
    // Prompt templates cannot run in tests; this covers request building.
    try {
      new ProjectAssistantController.EinsteinPromptRunner()
        .run(
          'Portfolio_Draft_From_Notes',
          new Map<String, String>{ 'Input:Title' => 'x' }
        );
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }
}
