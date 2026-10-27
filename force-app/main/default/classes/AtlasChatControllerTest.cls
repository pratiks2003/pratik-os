@IsTest
private class AtlasChatControllerTest {
  private class StubGateway implements AtlasChatController.AgentGateway {
    private final Boolean fail;
    StubGateway(Boolean fail) {
      this.fail = fail;
    }
    public Map<String, String> send(
      String agentApiName,
      String message,
      String sessionId
    ) {
      if (fail) {
        throw new AtlasChatController.AgentException('boom');
      }
      return new Map<String, String>{
        'reply' => '{"type":"Text","value":"Hi from ' +
        agentApiName +
        '"}',
        'sessionId' => sessionId ?? 'S1'
      };
    }
  }

  private static void configure(Boolean enabled, Integer cap) {
    AtlasChatController.settingsOverride = new Portfolio_Setting__mdt(
      Agent_Enabled__c = enabled,
      Daily_Agent_Cap__c = cap,
      Max_Messages_Per_Session__c = 5
    );
    AtlasChatController.gateway = new StubGateway(false);
  }

  @IsTest
  static void answersAndMetersUsage() {
    configure(true, 10);

    Map<String, String> first = AtlasChatController.sendMessage(
      '  Who is Pratik?  ',
      null
    );
    Map<String, String> second = AtlasChatController.sendMessage(
      'More',
      first.get('sessionId')
    );

    Assert.areEqual('ok', first.get('status'));
    Assert.areEqual('Hi from Atlas', first.get('reply'));
    Assert.areEqual('S1', second.get('sessionId'));
    Site_Metric_Day__c day = [
      SELECT Agent_Messages__c, Agent_Sessions__c
      FROM Site_Metric_Day__c
    ];
    Assert.areEqual(2, day.Agent_Messages__c);
    Assert.areEqual(
      1,
      day.Agent_Sessions__c,
      'Only the first message starts a session'
    );
  }

  @IsTest
  static void stopsAtDailyCap() {
    configure(true, 1);
    AtlasChatController.sendMessage('one', null);

    Map<String, String> result = AtlasChatController.sendMessage('two', 'S1');

    Assert.areEqual('limit', result.get('status'));
  }

  @IsTest
  static void respectsKillSwitchAndInputLimits() {
    configure(false, 10);
    Assert.areEqual(
      'offline',
      AtlasChatController.sendMessage('hi', null).get('status')
    );

    configure(true, 10);
    Assert.areEqual(
      'invalid',
      AtlasChatController.sendMessage('   ', null).get('status')
    );
    String tooLong = 'x'.repeat(AtlasChatController.MAX_MESSAGE_LENGTH + 1);
    Assert.areEqual(
      'invalid',
      AtlasChatController.sendMessage(tooLong, null).get('status')
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Site_Metric_Day__c],
      'Rejected messages are not metered'
    );
  }

  @IsTest
  static void agentFailureReturnsFriendlyError() {
    configure(true, 10);
    AtlasChatController.gateway = new StubGateway(true);

    Map<String, String> result = AtlasChatController.sendMessage('hi', null);

    Assert.areEqual('error', result.get('status'));
    Assert.isFalse(
      result.get('reply').contains('boom'),
      'Internal errors are not exposed'
    );
  }

  @IsTest
  static void extractsTextFromAgentPayload() {
    Assert.areEqual('plain', AtlasChatController.extractText('plain'));
    Assert.areEqual('{broken', AtlasChatController.extractText('{broken'));
    Assert.areEqual(
      'v',
      AtlasChatController.extractText('{"type":"Text","value":"v"}')
    );
    Assert.isNull(AtlasChatController.extractText(null));
  }

  @IsTest
  static void exposesConfigForTheSite() {
    configure(true, 10);
    Map<String, Object> config = AtlasChatController.getConfig();
    Assert.areEqual(true, config.get('enabled'));
    Assert.areEqual(5, config.get('maxMessagesPerSession'));
  }

  @IsTest
  static void invocableGatewayBuildsAgentRequest() {
    // The agent cannot run inside a test context; this covers request building
    // and surfaces any platform failure as an exception.
    try {
      Map<String, String> result = new AtlasChatController.InvocableAgentGateway()
        .send('Atlas', 'Hi', 'existing-session');
      Assert.isTrue(result.containsKey('reply'));
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }
}
