/**
 * Public entry point for the live demos. Each run counts towards a daily cap
 * in Portfolio_Setting__mdt so the demos cannot be used to drain org limits.
 */
public with sharing class DemoController {
  private static final Set<String> SOURCE_ALLOWLIST = new Set<String>{
    'LimitsArena',
    'ShipmentEventRouter',
    'ShipmentEventHandlers',
    'NebulaPaySync',
    'SeatBookingService'
  };
  private static final Set<String> PAYMENT_SCENARIOS = new Set<String>{
    'healthy',
    'flaky',
    'outage',
    'declined'
  };

  @TestVisible
  private static Portfolio_Setting__mdt settingsOverride;

  @AuraEnabled
  public static LimitsArena.Result runLimitsArena(Integer recordCount) {
    guard();
    LimitsArena.Result result = LimitsArena.run(recordCount);
    recordRun();
    return result;
  }

  @AuraEnabled
  public static List<ShipmentEventRouter.TraceStep> routeShipmentEvents(
    String eventsJson
  ) {
    guard();
    List<ShipmentEventRouter.ShipmentEvent> events;
    try {
      events = (List<ShipmentEventRouter.ShipmentEvent>) JSON.deserialize(
        eventsJson,
        List<ShipmentEventRouter.ShipmentEvent>.class
      );
    } catch (Exception e) {
      throw new AuraHandledException('Those events could not be read.');
    }
    List<ShipmentEventRouter.TraceStep> trace = ShipmentEventRouter.route(
      events
    );
    recordRun();
    return trace;
  }

  @AuraEnabled
  public static NebulaPaySync.SyncResult runPaymentSync(String scenario) {
    guard();
    if (!PAYMENT_SCENARIOS.contains(scenario)) {
      throw new AuraHandledException('Unknown scenario.');
    }
    NebulaPaySync.SyncResult result = NebulaPaySync.sync(
      new NebulaPaySync.SimulatedGateway(scenario)
    );
    recordRun();
    return result;
  }

  @AuraEnabled
  public static Id prepareSeatRace(Boolean useLocking) {
    guard();
    Id seatId = SeatBookingService.prepare(useLocking);
    recordRun();
    return seatId;
  }

  @AuraEnabled
  public static Map<String, Object> bookSeat(Id seatId, String buyer) {
    try {
      return SeatBookingService.book(seatId, buyer);
    } catch (Exception e) {
      throw new AuraHandledException('That booking could not be processed.');
    }
  }

  @AuraEnabled
  public static Map<String, Object> seatRaceResult(Id seatId) {
    try {
      return SeatBookingService.result(seatId);
    } catch (Exception e) {
      throw new AuraHandledException('That race has already finished.');
    }
  }

  /** Returns the live source of a demo class so visitors can read the real code. */
  @AuraEnabled(cacheable=true)
  public static String getSource(String className) {
    if (!SOURCE_ALLOWLIST.contains(className)) {
      throw new AuraHandledException(
        'Source is only available for the demo classes.'
      );
    }
    List<ApexClass> classes = [
      SELECT Body
      FROM ApexClass
      WHERE Name = :className AND NamespacePrefix = NULL
      LIMIT 1
    ];
    return classes.isEmpty() ? '' : classes[0].Body;
  }

  private static void guard() {
    Portfolio_Setting__mdt settings = settingsOverride ??
      Portfolio_Setting__mdt.getInstance('Default');
    Integer cap = Integer.valueOf(settings?.Daily_Demo_Cap__c ?? 1000);
    if (AtlasUsageMeter.demoRunsToday() >= cap) {
      throw new AuraHandledException(
        'The live demos have reached their limit for today. Please come back tomorrow.'
      );
    }
  }

  private static void recordRun() {
    AtlasUsageMeter.increment(
      new Map<Schema.SObjectField, Integer>{
        Site_Metric_Day__c.Demo_Runs__c => 1
      }
    );
  }
}
