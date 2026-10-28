/**
 * Emails inquiry alerts to every Portfolio_Admin user. Runs from the
 * Inquiry_Alert__e subscriber as the Automated Process user, so Atlas and
 * contact-form inquiries take exactly the same path.
 *
 * Alerts are sent from the verified org-wide email address named in
 * Portfolio_Setting__mdt.Alert_Sender_Name__c, with Reply-To set to the
 * visitor. If that address is missing or a send fails, the alert falls back
 * to a post on each admin's Chatter profile, which Salesforce emails itself.
 */
public without sharing class InquiryAlertService implements Queueable {
  @TestVisible
  private static AlertSender sender = new OrgWideEmailSender();
  @TestVisible
  private static MentionPoster poster = new ChatterMentionPoster();
  @TestVisible
  private static Id senderAddressOverride;

  private final Set<Id> inquiryIds;

  public InquiryAlertService(Set<Id> inquiryIds) {
    this.inquiryIds = inquiryIds;
  }

  public void execute(QueueableContext context) {
    List<Id> admins = adminIds();
    Id senderAddressId = senderAddressId();
    List<Inquiry__c> updates = new List<Inquiry__c>();
    for (Inquiry__c inquiry : [
      SELECT
        Id,
        OwnerId,
        Name,
        Full_Name__c,
        Email__c,
        Company__c,
        Role_Hiring_For__c,
        Message__c,
        Conversation_Summary__c,
        Interest_Score__c,
        Source__c,
        Notification_Status__c
      FROM Inquiry__c
      WHERE Id IN :inquiryIds
    ]) {
      String outcome = admins.isEmpty()
        ? 'Email alert skipped: no Portfolio_Admin users.'
        : alert(inquiry, admins, senderAddressId);
      String status = (inquiry.Notification_Status__c ?? '')
        .replace('Email alert queued.', '')
        .trim();
      Inquiry__c changed = new Inquiry__c(
        Id = inquiry.Id,
        Notification_Status__c = (status + ' ' + outcome).trim().left(255)
      );
      // Inquiries are created by the guest or Atlas agent user; hand them to an
      // admin so they appear in the admin's own views.
      if (!admins.isEmpty()) {
        changed.OwnerId = admins[0];
      }
      updates.add(changed);
    }
    Database.update(updates, false);
  }

  private static String alert(
    Inquiry__c inquiry,
    List<Id> admins,
    Id senderAddressId
  ) {
    String emailProblem = senderAddressId == null
      ? 'org-wide sender not found'
      : null;
    if (senderAddressId != null) {
      try {
        emailProblem = sender.send(senderAddressId, admins, inquiry);
        if (emailProblem == null) {
          return 'Email sent from the org-wide address.';
        }
      } catch (Exception e) {
        emailProblem = e.getMessage();
      }
    }
    try {
      poster.post(inquiry.Id, admins, postText(inquiry));
      return ('Email via Chatter (' + emailProblem + ').').left(160);
    } catch (Exception e) {
      return ('Email alert failed: ' +
        emailProblem +
        '; Chatter: ' +
        e.getMessage())
        .left(160);
    }
  }

  private static Id senderAddressId() {
    if (senderAddressOverride != null) {
      return senderAddressOverride;
    }
    String name = Portfolio_Setting__mdt.getInstance('Default')
      ?.Alert_Sender_Name__c;
    if (String.isBlank(name)) {
      return null;
    }
    List<OrgWideEmailAddress> addresses = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE DisplayName = :name AND IsVerified = TRUE
      LIMIT 1
    ];
    return addresses.isEmpty() ? null : addresses[0].Id;
  }

  public static List<Id> adminIds() {
    List<Id> ids = new List<Id>();
    for (PermissionSetAssignment assignment : [
      SELECT AssigneeId
      FROM PermissionSetAssignment
      WHERE PermissionSet.Name = 'Portfolio_Admin' AND Assignee.IsActive = TRUE
    ]) {
      ids.add(assignment.AssigneeId);
    }
    return ids;
  }

  public static String headline(Inquiry__c inquiry) {
    return (inquiry.Source__c ?? 'Portfolio') +
      (String.isBlank(inquiry.Company__c) ? '' : ' · ' + inquiry.Company__c) +
      (String.isBlank(inquiry.Role_Hiring_For__c)
        ? ''
        : ' · ' + inquiry.Role_Hiring_For__c);
  }

  @TestVisible
  private static String postText(Inquiry__c inquiry) {
    return ' New portfolio inquiry ' +
      inquiry.Name +
      ' from ' +
      inquiry.Full_Name__c +
      ' (' +
      inquiry.Email__c +
      ').\n' +
      headline(inquiry) +
      (String.isBlank(inquiry.Message__c)
        ? ''
        : '\n\n' + inquiry.Message__c.left(2000));
  }

  @TestVisible
  private static String emailBody(Inquiry__c inquiry) {
    return String.join(
      new List<String>{
        'New portfolio inquiry ' + inquiry.Name,
        '',
        'Source: ' + (inquiry.Source__c ?? '-'),
        'Name: ' + inquiry.Full_Name__c,
        'Email: ' + inquiry.Email__c,
        'Company: ' + (inquiry.Company__c ?? '-'),
        'Role: ' + (inquiry.Role_Hiring_For__c ?? '-'),
        'Interest score: ' +
        (inquiry.Interest_Score__c == null
          ? '-'
          : String.valueOf(inquiry.Interest_Score__c)),
        '',
        'Message:',
        inquiry.Message__c ?? '-',
        '',
        'Conversation summary:',
        inquiry.Conversation_Summary__c ?? '-',
        '',
        'Open in Salesforce: ' + recordLink(inquiry.Id),
        '',
        'Reply to this email to answer ' +
        inquiry.Full_Name__c +
        ' directly.'
      },
      '\n'
    );
  }

  private static String recordLink(Id recordId) {
    return Url.getOrgDomainUrl().toExternalForm() +
      '/lightning/r/Inquiry__c/' +
      recordId +
      '/view';
  }

  public interface AlertSender {
    /** Returns null on success, or the reason the email was not sent. */
    String send(Id senderAddressId, List<Id> recipientIds, Inquiry__c inquiry);
  }

  public class OrgWideEmailSender implements AlertSender {
    public String send(
      Id senderAddressId,
      List<Id> recipientIds,
      Inquiry__c inquiry
    ) {
      List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
      for (Id recipientId : recipientIds) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setOrgWideEmailAddressId(senderAddressId);
        email.setTargetObjectId(recipientId);
        email.setSaveAsActivity(false);
        if (String.isNotBlank(inquiry.Email__c)) {
          email.setReplyTo(inquiry.Email__c);
        }
        email.setSubject(
          'New portfolio inquiry ' +
            inquiry.Name +
            ': ' +
            inquiry.Full_Name__c +
            (String.isBlank(inquiry.Company__c)
              ? ''
              : ' (' + inquiry.Company__c + ')')
        );
        email.setPlainTextBody(emailBody(inquiry));
        emails.add(email);
      }
      for (
        Messaging.SendEmailResult result : Messaging.sendEmail(emails, false)
      ) {
        if (!result.isSuccess()) {
          return result.getErrors()[0].getMessage();
        }
      }
      return null;
    }
  }

  public interface MentionPoster {
    void post(Id recordId, List<Id> mentionIds, String text);
  }

  /**
   * Fallback: posts on each admin's Chatter profile with plain DML (the
   * Automated Process user cannot use the Connect API). Salesforce emails
   * "posted on your profile" notifications from its own domain.
   */
  public class ChatterMentionPoster implements MentionPoster {
    public void post(Id recordId, List<Id> mentionIds, String text) {
      List<FeedItem> posts = new List<FeedItem>();
      for (Id adminId : mentionIds) {
        posts.add(
          new FeedItem(
            ParentId = adminId,
            Body = text.trim().left(9000),
            LinkUrl = recordLink(recordId),
            Title = 'Open the inquiry'
          )
        );
      }
      insert posts;
    }
  }
}
