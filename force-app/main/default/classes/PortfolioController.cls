/**
 * Public entry point for the portfolio site. One cacheable call returns
 * everything a page needs.
 */
public with sharing class PortfolioController {
  @AuraEnabled(cacheable=true)
  public static PortfolioService.SiteData getSiteData() {
    try {
      return PortfolioService.getSiteData();
    } catch (Exception e) {
      throw new AuraHandledException(
        'Portfolio data is unavailable right now.'
      );
    }
  }
}
