/**
 * M0 spike: proves a guest user on the LWR site can call cacheable Apex.
 * Will be replaced by PortfolioController in M1.
 */
public with sharing class PortfolioPingController {
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> ping() {
    return new Map<String, Object>{
      'userType' => UserInfo.getUserType(),
      'serverTime' => System.now(),
      'apiVersion' => '64.0'
    };
  }
}
