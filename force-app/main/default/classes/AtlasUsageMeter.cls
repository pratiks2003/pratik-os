/**
 * Daily usage counters for the public site, one Site_Metric_Day__c row per
 * day. Runs without sharing because the guest user must update a shared
 * counter it cannot otherwise see; it only ever touches today's row.
 */
public without sharing class AtlasUsageMeter {
  public static Integer messagesToday() {
    Site_Metric_Day__c row = today();
    return row == null ? 0 : Integer.valueOf(row.Agent_Messages__c ?? 0);
  }

  /** Records one agent message; a new conversation also counts as a session. */
  public static void recordMessage(Boolean newSession) {
    increment(
      new Map<Schema.SObjectField, Integer>{
        Site_Metric_Day__c.Agent_Messages__c => 1,
        Site_Metric_Day__c.Agent_Sessions__c => newSession ? 1 : 0
      }
    );
  }

  public static void increment(Map<Schema.SObjectField, Integer> deltas) {
    Site_Metric_Day__c row = today(true);
    if (row == null) {
      row = new Site_Metric_Day__c(
        Name = todayKey(),
        Day__c = Date.today(),
        Day_Key__c = todayKey()
      );
    }
    for (Schema.SObjectField field : deltas.keySet()) {
      Decimal current = (Decimal) row.get(field) ?? 0;
      row.put(field, current + deltas.get(field));
    }
    try {
      upsert row Day_Key__c;
    } catch (DmlException e) {
      // Another request created today's row first; apply the deltas to it once.
      if (e.getDmlType(0) != StatusCode.DUPLICATE_VALUE || row.Id != null) {
        throw e;
      }
      increment(deltas);
    }
  }

  private static Site_Metric_Day__c today() {
    return today(false);
  }

  private static Site_Metric_Day__c today(Boolean lockRow) {
    String key = todayKey();
    List<Site_Metric_Day__c> rows = lockRow
      ? [
          SELECT
            Id,
            Day_Key__c,
            Agent_Messages__c,
            Agent_Sessions__c,
            JD_Matches__c,
            Demo_Runs__c,
            Page_Views__c
          FROM Site_Metric_Day__c
          WHERE Day_Key__c = :key
          LIMIT 1
          FOR UPDATE
        ]
      : [
          SELECT
            Id,
            Day_Key__c,
            Agent_Messages__c,
            Agent_Sessions__c,
            JD_Matches__c,
            Demo_Runs__c,
            Page_Views__c
          FROM Site_Metric_Day__c
          WHERE Day_Key__c = :key
          LIMIT 1
        ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static String todayKey() {
    return String.valueOf(Date.today());
  }
}
