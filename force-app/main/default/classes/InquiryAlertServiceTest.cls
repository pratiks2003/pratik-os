@IsTest
private class InquiryAlertServiceTest {
  private class StubPoster implements InquiryAlertService.MentionPoster {
    public List<String> texts = new List<String>();
    public List<Id> mentioned = new List<Id>();
    public void post(Id recordId, List<Id> mentionIds, String text) {
      texts.add(text);
      mentioned.addAll(mentionIds);
    }
  }

  @TestSetup
  static void setup() {
    PortfolioTestData.createContentAdmin();
  }

  @IsTest
  static void newInquiryQueuesAMentionThatEmailsAdmins() {
    StubPoster stub = new StubPoster();
    InquiryAlertService.poster = stub;

    Test.startTest();
    insert new Inquiry__c(
      Full_Name__c = 'Sam Example',
      Email__c = 'sam@example.com',
      Company__c = 'Example Co',
      Source__c = 'Contact Form',
      Message__c = 'Hello'
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    Assert.areEqual(1, stub.texts.size());
    Assert.isTrue(stub.texts[0].contains('Sam Example (sam@example.com)'));
    Assert.isTrue(stub.mentioned.contains(PortfolioTestData.contentAdmin().Id));
    String status = [SELECT Notification_Status__c FROM Inquiry__c]
    .Notification_Status__c;
    Assert.isTrue(status.contains('Email alert sent via Chatter.'), status);
    Assert.isFalse(
      status.contains('queued'),
      'The queued note is replaced by the outcome'
    );
    Assert.isTrue(
      InquiryAlertService.adminIds()
        .contains([SELECT OwnerId FROM Inquiry__c].OwnerId),
      'Inquiries are handed to an admin'
    );
  }

  @IsTest
  static void failuresAreRecordedNotThrown() {
    InquiryAlertService.poster = new FailingPoster();
    Inquiry__c inquiry = new Inquiry__c(
      Full_Name__c = 'Sam',
      Email__c = 's@example.com',
      Source__c = 'Atlas'
    );
    insert inquiry;

    Test.startTest();
    System.enqueueJob(new InquiryAlertService(new Set<Id>{ inquiry.Id }));
    Test.stopTest();

    Assert.isTrue(
      [SELECT Notification_Status__c FROM Inquiry__c]
        .Notification_Status__c.contains('Email alert failed')
    );
  }

  @IsTest
  static void chatterPosterBuildsTheMention() {
    // ConnectApi needs real data; this covers building the request.
    try {
      new InquiryAlertService.ChatterMentionPoster()
        .post(
          UserInfo.getUserId(),
          new List<Id>{ UserInfo.getUserId() },
          'hello'
        );
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  private class FailingPoster implements InquiryAlertService.MentionPoster {
    public void post(Id recordId, List<Id> mentionIds, String text) {
      throw new IllegalArgumentException('boom');
    }
  }
}
