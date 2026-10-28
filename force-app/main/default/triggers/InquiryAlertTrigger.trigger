trigger InquiryAlertTrigger on Inquiry_Alert__e(after insert) {
  // Platform event subscribers run as the Automated Process user; the
  // Chatter post happens in a queueable so it has full API access.
  Set<Id> inquiryIds = new Set<Id>();
  for (Inquiry_Alert__e alert : Trigger.new) {
    inquiryIds.add(alert.Inquiry_Id__c);
  }
  System.enqueueJob(new InquiryAlertService(inquiryIds));
}
