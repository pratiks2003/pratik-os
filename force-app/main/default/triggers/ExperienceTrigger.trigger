trigger ExperienceTrigger on Experience__c(before insert, before update) {
  new PublishableContentHandler().run();
}
