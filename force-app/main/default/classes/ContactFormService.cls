/**
 * Saves contact form submissions as inquiries. Bots are filtered by a hidden
 * honeypot field, a minimum time to fill the form and a daily cap, so no
 * third-party CAPTCHA is needed. Runs without sharing because the guest user
 * cannot create records directly; it only ever inserts Inquiry__c.
 */
public without sharing class ContactFormService {
  public static final Integer MIN_FILL_MS = 3000;
  private static final Pattern EMAIL_FORMAT = Pattern.compile(
    '^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$'
  );

  @TestVisible
  private static Portfolio_Setting__mdt settingsOverride;

  public static Map<String, String> submit(Submission form) {
    if (
      String.isNotBlank(form.website) ||
      form.elapsedMs == null ||
      form.elapsedMs < MIN_FILL_MS
    ) {
      // Looks automated. Answer as if it worked so bots learn nothing.
      return result('ok', 'Thanks! Pratik will be in touch.');
    }
    String name = form.fullName?.trim();
    String email = form.email?.trim();
    if (
      String.isBlank(name) ||
      String.isBlank(email) ||
      !EMAIL_FORMAT.matcher(email).matches()
    ) {
      return result(
        'invalid',
        'Please add your name and a valid email address.'
      );
    }
    if (String.isBlank(form.message?.trim())) {
      return result('invalid', 'Please add a short message for Pratik.');
    }
    Portfolio_Setting__mdt settings = settingsOverride ??
      Portfolio_Setting__mdt.getInstance('Default');
    Integer cap = Integer.valueOf(settings?.Daily_Form_Cap__c ?? 30);
    Integer today = [
      SELECT COUNT()
      FROM Inquiry__c
      WHERE Source__c = 'Contact Form' AND CreatedDate = TODAY
    ];
    if (today >= cap) {
      return result(
        'limit',
        'The form is taking a break today. Please reach Pratik on LinkedIn instead.'
      );
    }

    Inquiry__c inquiry = new Inquiry__c(
      Full_Name__c = name.left(120),
      Email__c = email.left(80),
      Company__c = form.company?.trim()?.left(120),
      Role_Hiring_For__c = form.role?.trim()?.left(120),
      Message__c = form.message.trim().left(5000),
      Source__c = 'Contact Form',
      Status__c = 'New'
    );
    insert inquiry;
    String reference = [SELECT Name FROM Inquiry__c WHERE Id = :inquiry.Id]
    .Name;
    return new Map<String, String>{
      'status' => 'ok',
      'reference' => reference,
      'message' => 'Thanks, ' +
      name.split(' ')[0] +
      '! Pratik will reply to ' +
      email +
      '. Reference ' +
      reference +
      '.'
    };
  }

  private static Map<String, String> result(String status, String message) {
    return new Map<String, String>{ 'status' => status, 'message' => message };
  }

  public class Submission {
    @AuraEnabled
    public String fullName { get; set; }
    @AuraEnabled
    public String email { get; set; }
    @AuraEnabled
    public String company { get; set; }
    @AuraEnabled
    public String role { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public String website { get; set; }
    @AuraEnabled
    public Long elapsedMs { get; set; }
  }
}
