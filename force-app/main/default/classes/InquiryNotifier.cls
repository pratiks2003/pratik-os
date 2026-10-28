/**
 * Alerts every Portfolio_Admin user when a new inquiry arrives:
 *  - a custom notification (bell icon and mobile push), sent straight away;
 *  - an Inquiry_Alert__e event, whose subscriber posts on each admin's
 *    Chatter profile. Salesforce emails that post from its own DKIM-signed
 *    domain, which Gmail accepts. (A direct Apex email would carry the
 *    sending user's gmail.com address without Google's DKIM signature, and
 *    Gmail blocks it with 550-5.7.30.)
 *
 * Runs without sharing because inquiries are created by the site guest user
 * and the Atlas agent user, who cannot see admin assignments; it only reads
 * those and stamps Notification_Status__c. A failed alert never blocks the
 * inquiry.
 */
public without sharing class InquiryNotifier extends TriggerHandler {
  @TestVisible
  private static Integer publishedCount = 0;

  protected override void afterInsert(List<SObject> records) {
    List<Id> recipientIds = InquiryAlertService.adminIds();
    String bell = recipientIds.isEmpty()
      ? 'No Portfolio_Admin users to notify.'
      : notifyInApp(records, recipientIds);
    String email = publishAlerts(records);

    List<Inquiry__c> updates = new List<Inquiry__c>();
    for (SObject record : records) {
      updates.add(
        new Inquiry__c(
          Id = record.Id,
          Notification_Status__c = (bell + ' ' + email).left(255)
        )
      );
    }
    Database.update(updates, false);
  }

  private static String publishAlerts(List<SObject> records) {
    List<Inquiry_Alert__e> events = new List<Inquiry_Alert__e>();
    for (SObject record : records) {
      events.add(new Inquiry_Alert__e(Inquiry_Id__c = record.Id));
    }
    for (Database.SaveResult result : EventBus.publish(events)) {
      if (!result.isSuccess()) {
        return 'Email alert not queued: ' + result.getErrors()[0].getMessage();
      }
    }
    publishedCount += events.size();
    return 'Email alert queued.';
  }

  /** Bell and mobile push alert linking straight to each inquiry. */
  private static String notifyInApp(
    List<SObject> records,
    List<Id> recipientIds
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
    Set<String> recipients = new Set<String>();
    for (Id recipientId : recipientIds) {
      recipients.add(recipientId);
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
        notification.setBody(InquiryAlertService.headline(inquiry));
        notification.send(recipients);
      }
      return 'In-app alert sent.';
    } catch (Exception e) {
      return ('In-app alert failed: ' + e.getMessage()).left(120);
    }
  }
}
