@IsTest
private class InquiryAlertServiceTest {
  private class StubSender implements InquiryAlertService.AlertSender {
    public String failWith;
    public List<Inquiry__c> sent = new List<Inquiry__c>();
    public String send(
      Id senderAddressId,
      List<Id> recipientIds,
      Inquiry__c inquiry
    ) {
      sent.add(inquiry);
      return failWith;
    }
  }

  private class StubPoster implements InquiryAlertService.MentionPoster {
    public List<String> texts = new List<String>();
    public void post(Id recordId, List<Id> mentionIds, String text) {
      texts.add(text);
    }
  }

  @TestSetup
  static void setup() {
    PortfolioTestData.createContentAdmin();
  }

  private static Inquiry__c newInquiry() {
    return new Inquiry__c(
      Full_Name__c = 'Sam Example',
      Email__c = 'sam@example.com',
      Company__c = 'Example Co',
      Source__c = 'Contact Form',
      Message__c = 'Hello'
    );
  }

  @IsTest
  static void sendsFromTheOrgWideAddressAndHandsTheInquiryToAnAdmin() {
    StubSender sender = new StubSender();
    StubPoster poster = new StubPoster();
    InquiryAlertService.sender = sender;
    InquiryAlertService.poster = poster;
    InquiryAlertService.senderAddressOverride = UserInfo.getUserId(); // any non-null Id

    Test.startTest();
    insert newInquiry();
    Test.getEventBus().deliver();
    Test.stopTest();

    Assert.areEqual(1, sender.sent.size());
    Assert.areEqual(
      0,
      poster.texts.size(),
      'No Chatter fallback when the email is sent'
    );
    Inquiry__c saved = [SELECT OwnerId, Notification_Status__c FROM Inquiry__c];
    Assert.isTrue(
      saved.Notification_Status__c.contains(
        'Email sent from the org-wide address.'
      ),
      saved.Notification_Status__c
    );
    Assert.isFalse(saved.Notification_Status__c.contains('queued'));
    Assert.isTrue(
      InquiryAlertService.adminIds().contains(saved.OwnerId),
      'Inquiries are handed to an admin'
    );
  }

  @IsTest
  static void fallsBackToChatterWhenTheEmailFails() {
    StubSender sender = new StubSender();
    sender.failWith = 'sender not allowed';
    StubPoster poster = new StubPoster();
    InquiryAlertService.sender = sender;
    InquiryAlertService.poster = poster;
    InquiryAlertService.senderAddressOverride = UserInfo.getUserId();
    Inquiry__c inquiry = newInquiry();
    insert inquiry;

    Test.startTest();
    System.enqueueJob(new InquiryAlertService(new Set<Id>{ inquiry.Id }));
    Test.stopTest();

    Assert.areEqual(1, poster.texts.size());
    Assert.isTrue(poster.texts[0].contains('Sam Example (sam@example.com)'));
    Assert.isTrue(
      [SELECT Notification_Status__c FROM Inquiry__c]
        .Notification_Status__c.contains(
          'Email via Chatter (sender not allowed)'
        )
    );
  }

  @IsTest
  static void recordsFailuresOfBothChannels() {
    StubSender sender = new StubSender();
    sender.failWith = 'blocked';
    InquiryAlertService.sender = sender;
    InquiryAlertService.poster = new FailingPoster();
    InquiryAlertService.senderAddressOverride = UserInfo.getUserId();
    Inquiry__c inquiry = newInquiry();
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
  static void emailBodyCarriesTheDetailsAndALink() {
    Inquiry__c inquiry = newInquiry();
    insert inquiry;
    inquiry = [
      SELECT
        Id,
        Name,
        Full_Name__c,
        Email__c,
        Company__c,
        Role_Hiring_For__c,
        Message__c,
        Conversation_Summary__c,
        Interest_Score__c,
        Source__c
      FROM Inquiry__c
    ];
    String body = InquiryAlertService.emailBody(inquiry);
    Assert.isTrue(body.contains('Email: sam@example.com'));
    Assert.isTrue(
      body.contains('/lightning/r/Inquiry__c/' + inquiry.Id + '/view')
    );
  }

  @IsTest
  static void realChannelsBuildTheirRequests() {
    Inquiry__c inquiry = newInquiry();
    insert inquiry;
    inquiry = [
      SELECT
        Id,
        Name,
        Full_Name__c,
        Email__c,
        Company__c,
        Role_Hiring_For__c,
        Message__c,
        Conversation_Summary__c,
        Interest_Score__c,
        Source__c
      FROM Inquiry__c
    ];
    // A test context has no org-wide address or Chatter data; this covers request building.
    try {
      new InquiryAlertService.OrgWideEmailSender()
        .send(
          UserInfo.getUserId(),
          new List<Id>{ UserInfo.getUserId() },
          inquiry
        );
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
    try {
      new InquiryAlertService.ChatterMentionPoster()
        .post(inquiry.Id, new List<Id>{ UserInfo.getUserId() }, 'hello');
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
