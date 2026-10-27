/**
 * Blocks publishing any record that contains a confidential term.
 *
 * Blocked_Term__mdt stores terms only as HMAC-SHA256 hashes keyed by a secret
 * in the protected Compliance_Settings__c setting, so the public repository
 * never reveals what is blocked. Record text is split into word n-grams, each
 * n-gram is hashed with the same key, and any match blocks the save.
 * Unpublished drafts are never blocked. Fails closed when no key is set.
 */
public with sharing class ComplianceGuard {
  private static final Set<Schema.DisplayType> TEXT_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.STRING,
    Schema.DisplayType.TEXTAREA,
    Schema.DisplayType.URL
  };

  @TestVisible
  private static String keyOverride;
  @TestVisible
  private static List<Blocked_Term__mdt> termsOverride;

  public static void validate(List<SObject> records) {
    List<SObject> published = new List<SObject>();
    for (SObject record : records) {
      if (record.get('Published__c') == true) {
        published.add(record);
      }
    }
    if (published.isEmpty()) {
      return;
    }

    TermMatcher matcher = loadMatcher();
    if (matcher == null) {
      for (SObject record : published) {
        record.addError(
          'Publishing is blocked because the compliance key is not configured. Run scripts/compliance/set-key.sh.'
        );
      }
      return;
    }
    if (matcher.isEmpty()) {
      return;
    }

    List<String> fieldNames = textFieldsOf(published[0].getSObjectType());
    for (SObject record : published) {
      for (String fieldName : fieldNames) {
        String hit = matcher.findMatch((String) record.get(fieldName));
        if (hit != null) {
          record.addError(
            fieldName,
            'Contains a blocked confidential term ("' +
              hit +
              '"). Remove it before publishing.'
          );
          break;
        }
      }
    }
  }

  private static List<String> textFieldsOf(Schema.SObjectType objectType) {
    List<String> names = new List<String>();
    for (
      Schema.SObjectField field : objectType.getDescribe()
        .fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult describe = field.getDescribe();
      if (describe.isCustom() || describe.isNameField()) {
        if (TEXT_TYPES.contains(describe.getType())) {
          names.add(describe.getName());
        }
      }
    }
    return names;
  }

  private static TermMatcher loadMatcher() {
    String key = keyOverride ??
      Compliance_Settings__c.getOrgDefaults()?.Term_Key__c;
    if (String.isBlank(key)) {
      return null;
    }
    List<Blocked_Term__mdt> terms = termsOverride ??
      Blocked_Term__mdt.getAll().values();
    return new TermMatcher(key, terms);
  }

  private class TermMatcher {
    private final String key;
    private final Set<String> hashes = new Set<String>();
    private Integer maxTokens = 1;

    private TermMatcher(String key, List<Blocked_Term__mdt> terms) {
      this.key = key;
      for (Blocked_Term__mdt term : terms) {
        if (term.Is_Active__c && String.isNotBlank(term.Term_Hash__c)) {
          hashes.add(term.Term_Hash__c.toLowerCase());
          maxTokens = Math.max(
            maxTokens,
            term.Token_Count__c == null ? 1 : term.Token_Count__c.intValue()
          );
        }
      }
    }

    private Boolean isEmpty() {
      return hashes.isEmpty();
    }

    private String findMatch(String text) {
      List<String> tokens = TextFingerprint.tokens(text);
      Set<String> seen = new Set<String>();
      for (Integer start = 0; start < tokens.size(); start++) {
        String gram = '';
        for (
          Integer length = 1;
          length <= maxTokens &&
          start + length <= tokens.size();
          length++
        ) {
          gram = length == 1
            ? tokens[start]
            : gram + ' ' + tokens[start + length - 1];
          if (
            seen.add(gram) &&
            hashes.contains(TextFingerprint.keyedHash(gram, key))
          ) {
            return gram;
          }
        }
      }
      return null;
    }
  }
}
