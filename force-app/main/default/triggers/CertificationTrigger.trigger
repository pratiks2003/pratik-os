trigger CertificationTrigger on Certification__c(before insert, before update) {
  new PublishableContentHandler().run();
}
