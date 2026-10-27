/**
 * All portfolio queries. Runs in user mode, so the guest user's object
 * permissions, field-level security and sharing rules (published records
 * only) are enforced by the platform, not by convention.
 */
public with sharing class PortfolioSelector {
  public Portfolio_Profile__c getProfile() {
    List<Portfolio_Profile__c> profiles = [
      SELECT
        Id,
        Name,
        Headline__c,
        Tagline__c,
        Bio__c,
        Location__c,
        Availability__c,
        Open_To_Roles__c,
        LinkedIn_URL__c,
        GitHub_URL__c,
        Trailhead_URL__c,
        Photo_URL__c
      FROM Portfolio_Profile__c
      WHERE Published__c = TRUE
      WITH USER_MODE
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    return profiles.isEmpty() ? null : profiles[0];
  }

  public List<Highlight__c> getHighlights() {
    return [
      SELECT Id, Name, Value__c, Suffix__c
      FROM Highlight__c
      WHERE Published__c = TRUE
      WITH USER_MODE
      ORDER BY Display_Order__c ASC NULLS LAST, Name
    ];
  }

  public List<Experience__c> getExperiences() {
    return [
      SELECT
        Id,
        Name,
        Company__c,
        Company_URL__c,
        Engagement__c,
        Location__c,
        Start_Date__c,
        End_Date__c,
        Is_Current__c,
        Summary__c
      FROM Experience__c
      WHERE Published__c = TRUE
      WITH USER_MODE
      ORDER BY Display_Order__c ASC NULLS LAST, Start_Date__c DESC
    ];
  }

  public List<Project__c> getProjects() {
    return [
      SELECT
        Id,
        Name,
        Slug__c,
        Tagline__c,
        Category__c,
        Project_Type__c,
        Experience__c,
        Business_Impact__c,
        Technical_Deep_Dive__c,
        STAR_Story__c,
        Metrics__c,
        Architecture_DSL__c,
        Repo_URL__c,
        Featured__c,
        (
          SELECT
            Skill__c,
            Skill__r.Name,
            Skill__r.Key__c,
            Skill__r.Category__c,
            Skill__r.Published__c
          FROM Project_Skills__r
        )
      FROM Project__c
      WHERE Published__c = TRUE
      WITH USER_MODE
      ORDER BY Featured__c DESC, Display_Order__c ASC NULLS LAST, Name
    ];
  }

  public List<Skill__c> getSkills() {
    return [
      SELECT Id, Name, Key__c, Category__c, Proficiency__c
      FROM Skill__c
      WHERE Published__c = TRUE
      WITH USER_MODE
      ORDER BY Display_Order__c ASC NULLS LAST, Name
    ];
  }

  public List<Certification__c> getCertifications() {
    return [
      SELECT Id, Name, Issuer__c, Issued_Date__c, Credential_URL__c
      FROM Certification__c
      WHERE Published__c = TRUE
      WITH USER_MODE
      ORDER BY Display_Order__c ASC NULLS LAST, Issued_Date__c DESC
    ];
  }
}
