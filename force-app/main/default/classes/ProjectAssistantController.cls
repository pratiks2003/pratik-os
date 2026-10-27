/**
 * Admin-only AI helpers on the Project record page:
 *  - draftFromNotes: turns rough notes into case-study fields with the
 *    Portfolio_Draft_From_Notes prompt template, then vets the draft with
 *    the hashed blocked-term check before it can be applied;
 *  - reviewConfidentiality: the blocked-term check plus an AI review that
 *    flags anything else that could be confidential to a client.
 */
public with sharing class ProjectAssistantController {
  private static final Set<String> DRAFT_FIELDS = new Set<String>{
    'tagline',
    'category',
    'businessImpact',
    'technicalDeepDive',
    'starStory',
    'techStack',
    'metrics'
  };

  @TestVisible
  private static PromptRunner runner = new EinsteinPromptRunner();

  @AuraEnabled
  public static Map<String, Object> draftFromNotes(Id projectId, String notes) {
    if (String.isBlank(notes)) {
      throw new AuraHandledException('Add some notes first.');
    }
    Project__c project = loadProject(projectId);
    Map<String, Object> draft = parseJson(
      runner.run(
        'Portfolio_Draft_From_Notes',
        new Map<String, String>{
          'Input:Title' => project.Name,
          'Input:Notes' => notes.left(20000),
          'Input:Existing_Content' => projectText(project)
        }
      )
    );
    Map<String, Object> cleaned = new Map<String, Object>();
    for (String key : DRAFT_FIELDS) {
      cleaned.put(
        key,
        draft.containsKey(key) ? String.valueOf(draft.get(key) ?? '') : ''
      );
    }
    cleaned.put('starStory', normaliseStar((String) cleaned.get('starStory')));
    cleaned.put(
      'blockedTerms',
      ComplianceGuard.findBlockedTerms(
        new List<String>((List<String>) toStrings(cleaned.values()))
      )
    );
    return cleaned;
  }

  @AuraEnabled
  public static void applyDraft(Id projectId, String draftJson) {
    Map<String, Object> draft = (Map<String, Object>) JSON.deserializeUntyped(
      draftJson
    );
    Project__c project = new Project__c(Id = projectId);
    Map<String, Schema.SObjectField> targets = new Map<String, Schema.SObjectField>{
      'tagline' => Project__c.Tagline__c,
      'businessImpact' => Project__c.Business_Impact__c,
      'technicalDeepDive' => Project__c.Technical_Deep_Dive__c,
      'starStory' => Project__c.STAR_Story__c,
      'techStack' => Project__c.Tech_Stack__c,
      'metrics' => Project__c.Metrics__c
    };
    for (String key : targets.keySet()) {
      String value = (String) draft.get(key);
      if (String.isNotBlank(value)) {
        Schema.DescribeFieldResult field = targets.get(key).getDescribe();
        project.put(targets.get(key), value.left(field.getLength()));
      }
    }
    String category = (String) draft.get('category');
    for (
      Schema.PicklistEntry entry : Project__c.Category__c.getDescribe()
        .getPicklistValues()
    ) {
      if (entry.getValue() == category) {
        project.Category__c = category;
      }
    }
    try {
      update as user project;
    } catch (DmlException e) {
      // The confidentiality guard blocks published records with blocked terms.
      throw new AuraHandledException(e.getDmlMessage(0));
    }
  }

  @AuraEnabled
  public static Map<String, Object> reviewConfidentiality(Id projectId) {
    Project__c project = loadProject(projectId);
    String text = projectText(project);
    Map<String, Object> result = new Map<String, Object>{
      'blockedTerms' => ComplianceGuard.findBlockedTerms(
        new List<String>{ text }
      )
    };
    Map<String, Object> review = parseJson(
      runner.run(
        'Portfolio_Confidentiality_Review',
        new Map<String, String>{ 'Input:Content' => text }
      )
    );
    result.put('verdict', review.get('verdict') ?? 'review');
    result.put('findings', review.get('findings') ?? new List<Object>());
    return result;
  }

  private static Project__c loadProject(Id projectId) {
    return [
      SELECT
        Name,
        Tagline__c,
        Business_Impact__c,
        Technical_Deep_Dive__c,
        STAR_Story__c,
        Tech_Stack__c,
        Metrics__c,
        Architecture_DSL__c
      FROM Project__c
      WHERE Id = :projectId
      WITH USER_MODE
    ];
  }

  private static String projectText(Project__c p) {
    List<String> parts = new List<String>();
    for (
      Object value : new List<Object>{
        p.Name,
        p.Tagline__c,
        p.Business_Impact__c,
        p.Technical_Deep_Dive__c,
        p.STAR_Story__c,
        p.Tech_Stack__c,
        p.Metrics__c,
        p.Architecture_DSL__c
      }
    ) {
      if (value != null) {
        parts.add(String.valueOf(value));
      }
    }
    return String.join(parts, '\n\n');
  }

  /** Puts each STAR part on its own line, whatever the model returned. */
  @TestVisible
  private static String normaliseStar(String star) {
    if (String.isBlank(star)) {
      return star;
    }
    String result = star;
    for (String label : new List<String>{ 'Task:', 'Action:', 'Result:' }) {
      result = result.replace(' ' + label, '\n' + label);
    }
    return result.replaceAll('\\n\\s*\\n', '\n').trim();
  }

  @TestVisible
  private static Map<String, Object> parseJson(String text) {
    String body = text?.trim() ?? '';
    Integer start = body.indexOf('{');
    Integer finish = body.lastIndexOf('}');
    if (start < 0 || finish <= start) {
      throw new AuraHandledException(
        'The AI response could not be read. Please try again.'
      );
    }
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(
        body.substring(start, finish + 1)
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'The AI response could not be read. Please try again.'
      );
    }
  }

  private static List<String> toStrings(List<Object> values) {
    List<String> strings = new List<String>();
    for (Object value : values) {
      strings.add(String.valueOf(value ?? ''));
    }
    return strings;
  }

  public interface PromptRunner {
    String run(String templateName, Map<String, String> inputs);
  }

  public class EinsteinPromptRunner implements PromptRunner {
    public String run(String templateName, Map<String, String> inputs) {
      ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
      input.inputParams = new Map<String, ConnectApi.WrappedValue>();
      for (String key : inputs.keySet()) {
        ConnectApi.WrappedValue value = new ConnectApi.WrappedValue();
        value.value = inputs.get(key) ?? '';
        input.inputParams.put(key, value);
      }
      input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
      input.additionalConfig.applicationName = 'PromptBuilderPreview';
      input.isPreview = false;
      return ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
          templateName,
          input
        )
        .generations[0]
        .text;
    }
  }
}
