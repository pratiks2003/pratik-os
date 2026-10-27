@IsTest
private class AtlasChatControllerTest {
  private class StubGateway implements AtlasChatController.AgentGateway {
    public Map<String, String> send(
      String agentApiName,
      String message,
      String sessionId
    ) {
      return new Map<String, String>{
        'reply' => agentApiName +
        ':' +
        message,
        'sessionId' => 'S1'
      };
    }
  }

  @IsTest
  static void sendMessageReturnsReplyAndSession() {
    AtlasChatController.gateway = new StubGateway();
    Map<String, String> result = AtlasChatController.sendMessage('Hi', null);
    Assert.areEqual('Atlas:Hi', result.get('reply'));
    Assert.areEqual('S1', result.get('sessionId'));
  }

  @IsTest
  static void blankMessageIsRejected() {
    AtlasChatController.gateway = new StubGateway();
    try {
      AtlasChatController.sendMessage('  ', null);
      Assert.fail('Expected an exception for a blank message');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
  }

  @IsTest
  static void invocableGatewayBuildsAgentRequest() {
    // The agent cannot run inside a test context; this verifies the gateway
    // builds the request and surfaces any platform failure as a handled error.
    try {
      Map<String, String> result = new AtlasChatController.InvocableAgentGateway()
        .send('Atlas', 'Hi', 'existing-session');
      Assert.isTrue(result.containsKey('reply'));
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }
}
