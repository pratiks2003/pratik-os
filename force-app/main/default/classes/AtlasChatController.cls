/**
 * M0 spike: lets the public site talk to the Atlas agent through the
 * generateAiAgentResponse invocable action. M3 adds the credit guard,
 * rate limiting and input validation.
 */
public with sharing class AtlasChatController {
  @TestVisible
  private static AgentGateway gateway = new InvocableAgentGateway();

  @AuraEnabled
  public static Map<String, String> sendMessage(
    String message,
    String sessionId
  ) {
    if (String.isBlank(message)) {
      throw new AuraHandledException('Message is required.');
    }
    return gateway.send('Atlas', message.left(2000), sessionId);
  }

  public interface AgentGateway {
    Map<String, String> send(
      String agentApiName,
      String message,
      String sessionId
    );
  }

  public class InvocableAgentGateway implements AgentGateway {
    public Map<String, String> send(
      String agentApiName,
      String message,
      String sessionId
    ) {
      Invocable.Action action = Invocable.Action.createCustomAction(
        'generateAiAgentResponse',
        agentApiName
      );
      action.setInvocationParameter('userMessage', message);
      if (String.isNotBlank(sessionId)) {
        action.setInvocationParameter('sessionId', sessionId);
      }
      Invocable.Action.Result result = action.invoke()[0];
      if (!result.isSuccess()) {
        throw new AuraHandledException('Atlas is unavailable right now.');
      }
      return new Map<String, String>{
        'reply' => (String) result.getOutputParameters().get('agentResponse'),
        'sessionId' => (String) result.getOutputParameters().get('sessionId')
      };
    }
  }
}
