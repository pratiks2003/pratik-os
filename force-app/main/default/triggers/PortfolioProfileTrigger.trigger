trigger PortfolioProfileTrigger on Portfolio_Profile__c(
  before insert,
  before update
) {
  new PublishableContentHandler().run();
}
