/** Public entry points for site-wide features: stats, visits and the contact form. */
public with sharing class SiteController {
  @AuraEnabled(cacheable=true)
  public static SiteStatsService.Stats getStats() {
    return SiteStatsService.getStats();
  }

  @AuraEnabled
  public static void recordVisit() {
    SiteStatsService.recordVisit();
  }

  @AuraEnabled
  public static Map<String, String> submitContactForm(String formJson) {
    ContactFormService.Submission form;
    try {
      form = (ContactFormService.Submission) JSON.deserialize(
        formJson,
        ContactFormService.Submission.class
      );
    } catch (Exception e) {
      return new Map<String, String>{
        'status' => 'invalid',
        'message' => 'The form could not be read.'
      };
    }
    try {
      return ContactFormService.submit(form);
    } catch (Exception e) {
      return new Map<String, String>{
        'status' => 'error',
        'message' => 'Something went wrong. Please reach Pratik on LinkedIn instead.'
      };
    }
  }
}
