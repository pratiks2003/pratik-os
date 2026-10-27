/**
 * Public entry point for chatting with Atlas from the site. Guards the
 * org's Agentforce credits: a kill switch and a daily message cap from
 * Portfolio_Setting__mdt, plus input limits. Returns a status instead of
 * throwing so the site can show a friendly fallback.
 */
public with sharing class AtlasChatController {
  @TestVisible
  private static final Integer MAX_MESSAGE_LENGTH = 8000;
  private static final String AGENT_API_NAME = 'Atlas';

  @TestVisible
  private static AgentGateway gateway = new InvocableAgentGateway();
  @TestVisible
  private static Portfolio_Setting__mdt settingsOverride;

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getConfig() {
    Portfolio_Setting__mdt settings = settings();
    return new Map<String, Object>{
      'enabled' => settings.Agent_Enabled__c,
      'maxMessagesPerSession' => Integer.valueOf(
        settings.Max_Messages_Per_Session__c ?? 20
      ),
      'maxMessageLength' => MAX_MESSAGE_LENGTH
    };
  }

  @AuraEnabled
  public static Map<String, String> sendMessage(
    String message,
    String sessionId
  ) {
    Portfolio_Setting__mdt settings = settings();
    String text = message?.trim();
    if (!settings.Agent_Enabled__c) {
      return status(
        'offline',
        'Atlas is offline right now. You can still reach Pratik on LinkedIn.'
      );
    }
    if (String.isBlank(text)) {
      return status('invalid', 'Type a question for Atlas first.');
    }
    if (text.length() > MAX_MESSAGE_LENGTH) {
      return status(
        'invalid',
        'That message is too long. Please keep it under ' +
          MAX_MESSAGE_LENGTH +
          ' characters.'
      );
    }
    Integer cap = Integer.valueOf(settings.Daily_Agent_Cap__c ?? 200);
    if (AtlasUsageMeter.messagesToday() >= cap) {
      return status(
        'limit',
        'Atlas has answered all the questions it can for today. Please reach Pratik on LinkedIn, or come back tomorrow.'
      );
    }

    // Call the agent before any DML: the invocation cannot follow uncommitted work.
    Map<String, String> result;
    try {
      result = gateway.send(AGENT_API_NAME, text, sessionId);
    } catch (Exception e) {
      return status(
        'error',
        'Atlas could not answer just now. Please try again in a moment.'
      );
    }
    AtlasUsageMeter.recordMessage(String.isBlank(sessionId));
    result.put('status', 'ok');
    result.put('reply', extractText(result.get('reply')));
    return result;
  }

  /** The agent returns {"type":"Text","value":"..."}; fall back to the raw text. */
  @TestVisible
  private static String extractText(String reply) {
    if (String.isBlank(reply) || !reply.trim().startsWith('{')) {
      return reply;
    }
    try {
      Object value = ((Map<String, Object>) JSON.deserializeUntyped(reply))
        .get('value');
      return value == null ? reply : String.valueOf(value);
    } catch (Exception e) {
      return reply;
    }
  }

  private static Map<String, String> status(String code, String message) {
    return new Map<String, String>{ 'status' => code, 'reply' => message };
  }

  private static Portfolio_Setting__mdt settings() {
    return settingsOverride ?? Portfolio_Setting__mdt.getInstance('Default');
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
        throw new AgentException(String.valueOf(result.getErrors()));
      }
      return new Map<String, String>{
        'reply' => (String) result.getOutputParameters().get('agentResponse'),
        'sessionId' => (String) result.getOutputParameters().get('sessionId')
      };
    }
  }

  public class AgentException extends Exception {
  }
}
