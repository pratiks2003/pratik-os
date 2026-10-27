/**
 * Read-only figures for the behind-the-scenes section: the latest CI
 * snapshots and 30-day usage totals. Runs without sharing because the guest
 * user has no access to these internal objects; it returns aggregates only,
 * never inquiries or personal data.
 */
public without sharing class SiteStatsService {
  public static Stats getStats() {
    Stats stats = new Stats();
    stats.deployments = [
      SELECT
        Name,
        Apex_Classes__c,
        Apex_Triggers__c,
        Lightning_Components__c,
        Custom_Objects__c,
        Apex_Tests__c,
        Apex_Tests_Passed__c,
        Code_Coverage__c,
        Commit_SHA__c,
        Commit_Message__c,
        Commit_URL__c,
        Run_URL__c,
        Deployed_At__c
      FROM Org_Snapshot__c
      ORDER BY Deployed_At__c DESC NULLS LAST
      LIMIT 5
    ];
    AggregateResult usage = [
      SELECT
        SUM(Page_Views__c) views,
        SUM(Agent_Sessions__c) sessions,
        SUM(Agent_Messages__c) messages,
        SUM(Demo_Runs__c) demos
      FROM Site_Metric_Day__c
      WHERE Day__c = LAST_N_DAYS:30
    ];
    stats.pageViews = toInteger(usage.get('views'));
    stats.atlasSessions = toInteger(usage.get('sessions'));
    stats.atlasMessages = toInteger(usage.get('messages'));
    stats.demoRuns = toInteger(usage.get('demos'));
    return stats;
  }

  /** Counts one visit per browser session (the site calls this once). */
  public static void recordVisit() {
    AtlasUsageMeter.increment(
      new Map<Schema.SObjectField, Integer>{
        Site_Metric_Day__c.Page_Views__c => 1
      }
    );
  }

  private static Integer toInteger(Object value) {
    return value == null ? 0 : ((Decimal) value).intValue();
  }

  public class Stats {
    @AuraEnabled
    public List<Org_Snapshot__c> deployments;
    @AuraEnabled
    public Integer pageViews;
    @AuraEnabled
    public Integer atlasSessions;
    @AuraEnabled
    public Integer atlasMessages;
    @AuraEnabled
    public Integer demoRuns;
  }
}
