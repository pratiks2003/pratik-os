@IsTest
private class DemoEnginesTest {
  private static ShipmentEventRouter.ShipmentEvent event(
    String type,
    Integer version
  ) {
    ShipmentEventRouter.ShipmentEvent e = new ShipmentEventRouter.ShipmentEvent();
    e.type = type;
    e.version = version;
    return e;
  }

  @IsTest
  static void limitsArenaContrastsBulkifiedAndNaiveCode() {
    LimitsArena.Result result = DemoController.runLimitsArena(200);

    Assert.areEqual(200, result.recordCount);
    Assert.areEqual(
      1,
      result.bulkified.queries,
      'Bulkified code uses one query'
    );
    Assert.areEqual(1, result.bulkified.dmlStatements);
    Assert.areEqual(200, result.bulkified.processed);
    Assert.isTrue(
      result.naive.halted,
      'Naive code must stop before the query limit'
    );
    Assert.isTrue(
      result.naive.queries >= 90,
      'Naive code used ' + result.naive.queries
    );
    Assert.areEqual(200, result.naive.queriesNeeded);
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Demo_Order__c],
      'Everything is rolled back'
    );
    Assert.areEqual(
      1,
      [SELECT Demo_Runs__c FROM Site_Metric_Day__c].Demo_Runs__c
    );
  }

  @IsTest
  static void limitsArenaCompletesSmallRunsAndClampsInput() {
    LimitsArena.Result small = LimitsArena.run(10);
    Assert.isFalse(small.naive.halted);
    Assert.areEqual(10, small.naive.queries);
    Assert.areEqual(LimitsArena.MAX_RECORDS, LimitsArena.run(5000).recordCount);
  }

  @IsTest
  static void routerAppliesRejectsAndIgnoresEvents() {
    List<ShipmentEventRouter.TraceStep> trace = DemoController.routeShipmentEvents(
      JSON.serialize(
        new List<ShipmentEventRouter.ShipmentEvent>{
          event('Created', 1),
          event('Packed', 2),
          event('Created', 2),
          event('Delivered', 3),
          event('Teleported', 4),
          event('Shipped', 5),
          event('Delivered', 6)
        }
      )
    );

    List<String> outcomes = new List<String>();
    for (ShipmentEventRouter.TraceStep step : trace) {
      outcomes.add(step.outcome);
    }
    Assert.areEqual(
      new List<String>{
        'applied',
        'applied',
        'stale',
        'rejected',
        'unknown',
        'applied',
        'applied'
      },
      outcomes
    );
    Assert.areEqual('PackedHandler', trace[1].handler);
    Assert.areEqual('Delivered', trace[6].statusAfter);
    Assert.areEqual(6, trace[6].versionAfter);
  }

  @IsTest
  static void routerRejectsUnreadableInput() {
    try {
      DemoController.routeShipmentEvents('not json');
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
  }

  @IsTest
  static void paymentSyncHandlesEveryScenario() {
    Map<String, String> expected = new Map<String, String>{
      'healthy' => 'SYNCED',
      'flaky' => 'SYNCED',
      'outage' => 'RETRY_LATER',
      'declined' => 'NEEDS_HUMAN'
    };
    for (String scenario : expected.keySet()) {
      NebulaPaySync.SyncResult result = DemoController.runPaymentSync(scenario);
      Assert.areEqual(expected.get(scenario), result.outcome, scenario);
    }
    NebulaPaySync.SyncResult flaky = NebulaPaySync.sync(
      new NebulaPaySync.SimulatedGateway('flaky')
    );
    Assert.areEqual(3, flaky.attempts.size());
    Assert.areEqual(200, flaky.attempts[0].backoffMs);
    Assert.areEqual(400, flaky.attempts[1].backoffMs);
    Assert.areEqual(
      1,
      NebulaPaySync.sync(new NebulaPaySync.SimulatedGateway('declined'))
        .attempts.size()
    );
    Assert.areEqual(
      NebulaPaySync.MAX_ATTEMPTS,
      NebulaPaySync.sync(new NebulaPaySync.SimulatedGateway('outage'))
        .attempts.size()
    );
  }

  @IsTest
  static void seatBookingRefusesTheSecondBuyerWhenRunSequentially() {
    SeatBookingService.contentionMs = 0;
    Id seatId = DemoController.prepareSeatRace(true);

    Map<String, Object> ava = DemoController.bookSeat(seatId, 'Ava');
    Map<String, Object> ben = DemoController.bookSeat(seatId, 'Ben');
    Map<String, Object> result = DemoController.seatRaceResult(seatId);

    Assert.isTrue((Boolean) ava.get('booked'));
    Assert.isFalse((Boolean) ben.get('booked'));
    Assert.areEqual(0, ben.get('seatsSeen'));
    Assert.isFalse((Boolean) result.get('overbooked'));
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Demo_Seat__c],
      'Runs clean up after themselves'
    );
  }

  @IsTest
  static void seatResultReportsOverbooking() {
    SeatBookingService.contentionMs = 0;
    Id seatId = SeatBookingService.prepare(false);
    insert new List<Demo_Booking__c>{
      new Demo_Booking__c(
        Seat__c = seatId,
        Buyer__c = 'Ava',
        Seats_Seen__c = 1
      ),
      new Demo_Booking__c(Seat__c = seatId, Buyer__c = 'Ben', Seats_Seen__c = 1)
    };

    Map<String, Object> result = SeatBookingService.result(seatId);

    Assert.isTrue((Boolean) result.get('overbooked'));
    Assert.areEqual(2, ((List<Object>) result.get('bookings')).size());
  }

  @IsTest
  static void seatEndpointsHideErrors() {
    Id seatId = SeatBookingService.prepare(false);
    for (String buyer : new List<String>{ 'Mallory' }) {
      try {
        DemoController.bookSeat(seatId, buyer);
        Assert.fail('Unknown buyers are rejected');
      } catch (AuraHandledException e) {
        Assert.isNotNull(e);
      }
    }
    SeatBookingService.result(seatId);
    try {
      DemoController.seatRaceResult(seatId);
      Assert.fail('A finished race cannot be read twice');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
  }

  @IsTest
  static void sourceIsServedForDemoClassesOnly() {
    Assert.isTrue(
      DemoController.getSource('NebulaPaySync').contains('class NebulaPaySync')
    );
    try {
      DemoController.getSource('AtlasChatController');
      Assert.fail('Only demo classes are exposed');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
  }

  @IsTest
  static void dailyCapStopsDemos() {
    DemoController.settingsOverride = new Portfolio_Setting__mdt(
      Daily_Demo_Cap__c = 1
    );
    DemoController.runPaymentSync('healthy');
    try {
      DemoController.runPaymentSync('healthy');
      Assert.fail('Expected the cap to stop the second run');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
    try {
      DemoController.runPaymentSync('nonsense');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
  }
}
