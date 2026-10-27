@IsTest
private class SiteControllerTest {
  private static String form(
    String name,
    String email,
    String message,
    String website,
    Long elapsedMs
  ) {
    return JSON.serialize(
      new Map<String, Object>{
        'fullName' => name,
        'email' => email,
        'company' => 'Example Co',
        'role' => 'Developer',
        'message' => message,
        'website' => website,
        'elapsedMs' => elapsedMs
      }
    );
  }

  @IsTest
  static void validSubmissionCreatesInquiry() {
    Map<String, String> result = SiteController.submitContactForm(
      form('Sam Example', 'sam@example.com', 'Hello Pratik', '', 8000)
    );

    Assert.areEqual('ok', result.get('status'));
    Assert.isTrue(result.get('reference').startsWith('INQ-'));
    Inquiry__c saved = [
      SELECT Source__c, Company__c, Status__c
      FROM Inquiry__c
    ];
    Assert.areEqual('Contact Form', saved.Source__c);
    Assert.areEqual('Example Co', saved.Company__c);
  }

  @IsTest
  static void botsAreSilentlyIgnored() {
    Assert.areEqual(
      'ok',
      SiteController.submitContactForm(
          form('Bot', 'b@example.com', 'spam', 'http://spam', 8000)
        )
        .get('status')
    );
    Assert.areEqual(
      'ok',
      SiteController.submitContactForm(
          form('Fast', 'f@example.com', 'spam', '', 200)
        )
        .get('status')
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Inquiry__c],
      'Honeypot and speed checks drop bots'
    );
  }

  @IsTest
  static void invalidInputIsRejected() {
    Assert.areEqual(
      'invalid',
      SiteController.submitContactForm(
          form('', 'x@example.com', 'hi', '', 8000)
        )
        .get('status')
    );
    Assert.areEqual(
      'invalid',
      SiteController.submitContactForm(form('Sam', 'nope', 'hi', '', 8000))
        .get('status')
    );
    Assert.areEqual(
      'invalid',
      SiteController.submitContactForm(
          form('Sam', 's@example.com', ' ', '', 8000)
        )
        .get('status')
    );
    Assert.areEqual(
      'invalid',
      SiteController.submitContactForm('{broken').get('status')
    );
  }

  @IsTest
  static void dailyCapStopsTheForm() {
    ContactFormService.settingsOverride = new Portfolio_Setting__mdt(
      Daily_Form_Cap__c = 1
    );
    SiteController.submitContactForm(
      form('One', 'one@example.com', 'hi', '', 8000)
    );
    Assert.areEqual(
      'limit',
      SiteController.submitContactForm(
          form('Two', 'two@example.com', 'hi', '', 8000)
        )
        .get('status')
    );
  }

  @IsTest
  static void statsAggregateUsageAndSnapshots() {
    SiteController.recordVisit();
    SiteController.recordVisit();
    AtlasUsageMeter.recordMessage(true);
    insert new Org_Snapshot__c(
      Name = 'abc1234',
      Apex_Classes__c = 40,
      Code_Coverage__c = 91.5,
      Deployed_At__c = System.now()
    );

    SiteStatsService.Stats stats = SiteController.getStats();

    Assert.areEqual(2, stats.pageViews);
    Assert.areEqual(1, stats.atlasSessions);
    Assert.areEqual(1, stats.atlasMessages);
    Assert.areEqual(0, stats.demoRuns);
    Assert.areEqual(1, stats.deployments.size());
    Assert.areEqual(91.5, stats.deployments[0].Code_Coverage__c);
  }
}
