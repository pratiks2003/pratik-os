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
      return;
    }

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    for (Inquiry__c inquiry : [
      SELECT
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
      }
    }
    if (!emails.isEmpty()) {
      Messaging.sendEmail(emails, false);
      sentCount += emails.size();
    }
  }
}
