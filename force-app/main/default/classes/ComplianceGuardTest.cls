@IsTest
private class ComplianceGuardTest {
  @IsTest
  static void blocksPublishedRecordContainingTerm() {
    PortfolioTestData.configureCompliance(new List<String>{ 'Acme Secret' });
    Project__c project = PortfolioTestData.project(
      'Event engine',
      'Apex',
      true
    );
    project.Technical_Deep_Dive__c = 'Built for the ACME-secret onboarding team.';

    Database.SaveResult result = Database.insert(project, false);

    Assert.isFalse(result.isSuccess());
    Assert.isTrue(result.getErrors()[0].getMessage().contains('acme secret'));
  }

  @IsTest
  static void allowsUnpublishedDraftThenBlocksPublishing() {
    PortfolioTestData.configureCompliance(new List<String>{ 'acmesys' });
    Project__c project = PortfolioTestData.project(
      'Sync with AcmeSys',
      'Apex',
      false
    );
    insert project;

    project.Published__c = true;
    Database.SaveResult result = Database.update(project, false);

    Assert.isFalse(
      result.isSuccess(),
      'Publishing a draft with a blocked term must fail'
    );
  }

  @IsTest
  static void matchesWholeWordsOnly() {
    PortfolioTestData.configureCompliance(new List<String>{ 'tms' });
    Project__c project = PortfolioTestData.project(
      'Processed 10k items',
      'Apex',
      true
    );

    insert project;

    Assert.isNotNull(
      project.Id,
      '"items" must not match the blocked term "tms"'
    );
  }

  @IsTest
  static void checksEveryPublishableObject() {
    PortfolioTestData.configureCompliance(new List<String>{ 'acmesys' });

    Database.SaveResult result = Database.insert(
      new Experience__c(
        Name = 'Developer',
        Summary__c = 'Owned the AcmeSys sync.',
        Published__c = true
      ),
      false
    );

    Assert.isFalse(result.isSuccess());
  }

  @IsTest
  static void failsClosedWithoutKey() {
    ComplianceGuard.keyOverride = null;
    ComplianceGuard.termsOverride = new List<Blocked_Term__mdt>();

    Database.SaveResult result = Database.insert(
      PortfolioTestData.project('Anything', 'Apex', true),
      false
    );

    Assert.isFalse(result.isSuccess());
    Assert.isTrue(
      result.getErrors()[0].getMessage().contains('compliance key')
    );
  }

  @IsTest
  static void keyedHashMatchesNodeScript() {
    // Same vector is asserted in scripts/compliance/add-blocked-term.test.mjs
    Assert.areEqual(
      'db42b6119dad0a2f6f9499abbebd04c80e1717523af05fec9d032e97a9407b9c',
      TextFingerprint.keyedHash('acme secret', 'k')
    );
    Assert.areEqual(
      'acme secret',
      TextFingerprint.normalize('  ACME-Secret!! ')
    );
  }
}
