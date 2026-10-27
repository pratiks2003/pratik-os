/**
 * Alerts every Portfolio_Admin user when a new inquiry arrives, by email and
 * by a Salesforce custom notification (bell icon and mobile push), so a lead
 * is never missed if an inbox filters the email.
 *
 * Runs without sharing because inquiries are created by the site guest user
 * and the Atlas agent user, who cannot see admin assignments; it only reads
 * those and stamps Notification_Status__c. A failed alert never blocks the
 * inquiry. Emails go to internal users via setTargetObjectId, which does not
 * count against the org's daily limit for external emails.
 */
public without sharing class InquiryNotifier extends TriggerHandler {
  @TestVisible
  private static Integer sentCount = 0;

  protected override void afterInsert(List<SObject> records) {
    List<User> recipients = new List<User>();
    for (PermissionSetAssignment assignment : [
      SELECT AssigneeId
      FROM PermissionSetAssignment
      WHERE PermissionSet.Name = 'Portfolio_Admin' AND Assignee.IsActive = TRUE
    ]) {
      recipients.add(new User(Id = assignment.AssigneeId));
    }
    if (recipients.isEmpty()) {
      recordStatus(
        new Map<Id, String>(),
        records,
        'Not sent: no Portfolio_Admin users to notify.'
      );
      return;
    }

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    List<Id> emailInquiryIds = new List<Id>();
    for (Inquiry__c inquiry : [
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
      WHERE Id IN :records
    ]) {
      for (User recipient : recipients) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(recipient.Id);
        email.setSaveAsActivity(false);
        email.setSenderDisplayName('pratik.os');
        email.setSubject(
          'New portfolio inquiry ' +
            inquiry.Name +
            ': ' +
            inquiry.Full_Name__c +
            (String.isBlank(inquiry.Company__c)
              ? ''
              : ' (' + inquiry.Company__c + ')')
        );
        email.setPlainTextBody(
          String.join(
            new List<String>{
              'Source: ' + inquiry.Source__c,
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
              inquiry.Conversation_Summary__c ?? '-'
            },
            '\n'
          )
        );
        emails.add(email);
        emailInquiryIds.add(inquiry.Id);
      }
    }
    Map<Id, String> statuses = send(emails, emailInquiryIds);
    String bell = notifyInApp(records, recipients);
    for (SObject record : records) {
      statuses.put(
        record.Id,
        (statuses.get(record.Id) ?? 'Email not sent.') + ' ' + bell
      );
    }
    recordStatus(statuses, records, null);
  }

  /** Bell and mobile push alert linking straight to each inquiry. */
  private static String notifyInApp(
    List<SObject> records,
    List<User> recipients
  ) {
    List<CustomNotificationType> types = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = 'Portfolio_Inquiry'
      LIMIT 1
    ];
    if (types.isEmpty()) {
      return 'In-app alert not configured.';
    }
    Set<String> recipientIds = new Set<String>();
    for (User recipient : recipients) {
      recipientIds.add(recipient.Id);
    }
    try {
      for (SObject record : records) {
        Inquiry__c inquiry = (Inquiry__c) record;
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(types[0].Id);
        notification.setTargetId(inquiry.Id);
        notification.setTitle(
          'New portfolio inquiry from ' + inquiry.Full_Name__c
        );
        notification.setBody(
          (inquiry.Source__c ?? 'Portfolio') +
            (String.isBlank(inquiry.Company__c)
              ? ''
              : ' · ' + inquiry.Company__c) +
            (String.isBlank(inquiry.Role_Hiring_For__c)
              ? ''
              : ' · ' + inquiry.Role_Hiring_For__c)
        );
        notification.send(recipientIds);
      }
      return 'In-app alert sent.';
    } catch (Exception e) {
      return ('In-app alert failed: ' + e.getMessage()).left(120);
    }
  }

  /** Sends without failing the save, and reports the outcome per inquiry. */
  private static Map<Id, String> send(
    List<Messaging.SingleEmailMessage> emails,
    List<Id> inquiryIds
  ) {
    Map<Id, Integer> delivered = new Map<Id, Integer>();
    Map<Id, String> statuses = new Map<Id, String>();
    try {
      List<Messaging.SendEmailResult> results = Messaging.sendEmail(
        emails,
        false
      );
      for (Integer i = 0; i < results.size(); i++) {
        Id inquiryId = inquiryIds[i];
        if (results[i].isSuccess()) {
          delivered.put(inquiryId, (delivered.get(inquiryId) ?? 0) + 1);
          sentCount++;
        } else if (!statuses.containsKey(inquiryId)) {
          statuses.put(
            inquiryId,
            'Failed: ' + results[i].getErrors()[0].getMessage()
          );
        }
      }
    } catch (Exception e) {
      for (Id inquiryId : inquiryIds) {
        statuses.put(inquiryId, 'Failed: ' + e.getMessage());
      }
    }
    for (Id inquiryId : delivered.keySet()) {
      Integer count = delivered.get(inquiryId);
      statuses.put(
        inquiryId,
        'Emailed ' + count + ' admin' + (count == 1 ? '' : 's') + '.'
      );
    }
    return statuses;
  }

  private static void recordStatus(
    Map<Id, String> statuses,
    List<SObject> records,
    String fallback
  ) {
    List<Inquiry__c> updates = new List<Inquiry__c>();
    for (SObject record : records) {
      String status = statuses.get(record.Id) ?? fallback;
      if (status != null) {
        updates.add(
          new Inquiry__c(
            Id = record.Id,
            Notification_Status__c = status.left(255)
          )
        );
      }
    }
    Database.update(updates, false);
  }
}
