@IsTest
public class PortfolioTestData {
  public static final String TEST_KEY = 'test-compliance-key';

  /** Configures the guard with a test key and the given plain-text blocked terms. */
  public static void configureCompliance(List<String> blockedTerms) {
    List<Blocked_Term__mdt> terms = new List<Blocked_Term__mdt>();
    for (String term : blockedTerms) {
      String normalized = TextFingerprint.normalize(term);
      terms.add(
        new Blocked_Term__mdt(
          Term_Hash__c = TextFingerprint.keyedHash(normalized, TEST_KEY),
          Token_Count__c = normalized.split(' ').size(),
          Is_Active__c = true
        )
      );
    }
    ComplianceGuard.keyOverride = TEST_KEY;
    ComplianceGuard.termsOverride = terms;
  }

  public static Project__c project(
    String title,
    String techStack,
    Boolean published
  ) {
    return new Project__c(
      Name = title,
      Tagline__c = title + ' tagline',
      Tech_Stack__c = techStack,
      Business_Impact__c = 'Reduced manual work.',
      Published__c = published
    );
  }

  /** A user with the Portfolio_Admin permission set, for user-mode queries. */
  public static User createContentAdmin() {
    User admin = new User(
      Alias = 'padm',
      Email = 'portfolio.admin@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Portfolio Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'Europe/London',
      Username = 'portfolio.admin.' + Crypto.getRandomInteger() + '@example.com'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert admin;
      insert new PermissionSetAssignment(
        AssigneeId = admin.Id,
        PermissionSetId = [
          SELECT Id
          FROM PermissionSet
          WHERE Name = 'Portfolio_Admin'
        ]
        .Id
      );
    }
    return admin;
  }

  public static User contentAdmin() {
    return [
      SELECT Id
      FROM User
      WHERE Email = 'portfolio.admin@example.com'
      LIMIT 1
    ];
  }

  /** Published and draft records used by the service and guest access tests. */
  public static void insertSiteContent() {
    configureCompliance(new List<String>());
    insert new Portfolio_Profile__c(
      Name = 'Test Person',
      Headline__c = 'Developer',
      Published__c = true
    );
    insert new List<Highlight__c>{
      new Highlight__c(
        Name = 'Items delivered',
        Value__c = 500,
        Suffix__c = '+',
        Published__c = true
      ),
      new Highlight__c(Name = 'Hidden', Value__c = 1, Published__c = false)
    };
    insert new Certification__c(
      Name = 'Platform Developer II',
      Issuer__c = 'Salesforce',
      Published__c = true
    );
    insert new Experience__c(
      Name = 'Developer',
      Company__c = 'Example Co',
      Published__c = true
    );
    insert new List<Project__c>{
      project('Public project', 'Apex, LWC', true),
      project('Draft project', 'Apex, Secret Skill', false)
    };
  }
}
