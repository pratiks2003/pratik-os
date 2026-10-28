/**
 * Sends inquiry email alerts as posts on each admin's Chatter profile.
 * Called from the Inquiry_Alert__e subscriber, which runs as the Automated
 * Process user. Because that user is not the admin, Salesforce emails each
 * admin the post from its own DKIM-signed domain, which Gmail accepts.
 */
public without sharing class InquiryAlertService implements Queueable {
  @TestVisible
  private static MentionPoster poster = new ChatterMentionPoster();

  private final Set<Id> inquiryIds;

  public InquiryAlertService(Set<Id> inquiryIds) {
    this.inquiryIds = inquiryIds;
  }

  public void execute(QueueableContext context) {
    List<Id> admins = adminIds();
    List<Inquiry__c> updates = new List<Inquiry__c>();
    for (Inquiry__c inquiry : [
      SELECT
        Id,
        Name,
        Full_Name__c,
        Email__c,
        Company__c,
        Role_Hiring_For__c,
        Message__c,
        Source__c,
        Notification_Status__c
      FROM Inquiry__c
      WHERE Id IN :inquiryIds
    ]) {
      String outcome;
      try {
        if (admins.isEmpty()) {
          outcome = 'Email alert skipped: no Portfolio_Admin users.';
        } else {
          poster.post(inquiry.Id, admins, postText(inquiry));
          outcome = 'Email alert sent via Chatter.';
        }
      } catch (Exception e) {
        outcome = ('Email alert failed: ' + e.getMessage()).left(120);
      }
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

  public interface MentionPoster {
    void post(Id recordId, List<Id> mentionIds, String text);
  }

  /**
   * Posts on each admin's Chatter profile with plain DML (the Automated
   * Process user cannot use the Connect API). Salesforce emails "posted on
   * your profile" notifications from its own DKIM-signed domain.
   */
  public class ChatterMentionPoster implements MentionPoster {
    public void post(Id recordId, List<Id> mentionIds, String text) {
      String link =
        Url.getOrgDomainUrl().toExternalForm() +
        '/lightning/r/Inquiry__c/' +
        recordId +
        '/view';
      List<FeedItem> posts = new List<FeedItem>();
      for (Id adminId : mentionIds) {
        posts.add(
          new FeedItem(
            ParentId = adminId,
            Body = text.trim().left(9000),
            LinkUrl = link,
            Title = 'Open the inquiry'
          )
        );
      }
      insert posts;
    }
  }
}
