trigger InquiryTrigger on Inquiry__c(after insert) {
  new InquiryNotifier().run();
}
