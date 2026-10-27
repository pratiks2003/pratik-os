trigger HighlightTrigger on Highlight__c(before insert, before update) {
  new PublishableContentHandler().run();
}
