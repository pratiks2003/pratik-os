/**
 * Best-guess category for a newly created skill, based on keywords in its
 * normalised name. Rules are checked in order; the first match wins. The
 * category can always be corrected on the Skill record afterwards.
 */
public inherited sharing class SkillCategorizer {
  private static final List<List<String>> RULES = new List<List<String>>{
    new List<String>{
      'AI',
      'agentforce',
      'agent',
      'einstein',
      'prompt',
      'ai',
      'llm'
    },
    new List<String>{ 'LWC', 'lwc', 'lightning', 'aura', 'navigationmixin' },
    new List<String>{
      'DevOps',
      'github',
      'ci',
      'cd',
      'git',
      'sfdx',
      'cli',
      'devops',
      'deployment',
      'pipeline'
    },
    new List<String>{
      'Architecture',
      'pattern',
      'service layer',
      'error classification',
      'error handling',
      'event routing',
      'strategy',
      'factory',
      'orchestrator',
      'architecture',
      'framework',
      'selector',
      'metadata driven'
    },
    new List<String>{
      'Integration',
      'rest',
      'conflict resolution',
      'api',
      'oauth',
      'named credentials',
      'named credential',
      'external credentials',
      'platform events',
      'platform event',
      'webhook',
      'webhooks',
      'json',
      'callout',
      'callouts',
      'integration',
      'idempotency'
    },
    new List<String>{
      'Automation',
      'flow',
      'flows',
      'validation rules',
      'assignment rules',
      'automation'
    },
    new List<String>{
      'Apex',
      'apex',
      'soql',
      'sosl',
      'trigger',
      'triggers',
      'queueable',
      'batch',
      'schedulable',
      'governor',
      'bulkification',
      'locking',
      'convertlead'
    }
  };

  public static String categorize(String normalizedName) {
    String padded = ' ' + normalizedName + ' ';
    for (List<String> rule : RULES) {
      for (Integer i = 1; i < rule.size(); i++) {
        if (padded.contains(' ' + rule[i] + ' ')) {
          return rule[0];
        }
      }
    }
    return 'Platform';
  }
}
