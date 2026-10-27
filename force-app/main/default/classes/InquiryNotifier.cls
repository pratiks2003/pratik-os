/**
 * Emails every Portfolio_Admin user when a new inquiry arrives. Sends to an internal user via
 * setTargetObjectId, which does not count against the org's daily limit
 * for external emails.
 */
public with sharing class InquiryNotifier extends TriggerHandler {
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
    recordStatus(send(emails, emailInquiryIds), records, null);
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
    update updates;
  }
}
