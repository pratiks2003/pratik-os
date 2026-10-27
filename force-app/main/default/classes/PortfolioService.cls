/**
 * Assembles everything the site and Atlas need from published records.
 * Skill evidence is computed from published projects only, so an unpublished
 * draft never inflates the skill map.
 */
public with sharing class PortfolioService {
  @TestVisible
  private static PortfolioSelector selector = new PortfolioSelector();

  public static SiteData getSiteData() {
    SiteData data = new SiteData();
    data.profile = selector.getProfile();
    data.highlights = selector.getHighlights();
    data.experiences = selector.getExperiences();
    data.certifications = selector.getCertifications();

    Map<Id, SkillView> skillsById = new Map<Id, SkillView>();
    for (Skill__c skill : selector.getSkills()) {
      skillsById.put(skill.Id, new SkillView(skill));
    }

    data.projects = new List<ProjectView>();
    for (Project__c project : selector.getProjects()) {
      ProjectView view = new ProjectView(project);
      for (Project_Skill__c link : project.Project_Skills__r) {
        SkillView skill = skillsById.get(link.Skill__c);
        if (skill != null) {
          skill.evidenceCount++;
          skill.projectSlugs.add(project.Slug__c);
          view.skills.add(skill.name);
        }
      }
      data.projects.add(view);
    }

    data.skills = new List<SkillView>();
    for (SkillView skill : skillsById.values()) {
      if (skill.evidenceCount > 0) {
        data.skills.add(skill);
      }
    }
    data.generatedAt = System.now();
    return data;
  }

  public class SiteData {
    @AuraEnabled
    public Portfolio_Profile__c profile;
    @AuraEnabled
    public List<Highlight__c> highlights;
    @AuraEnabled
    public List<Experience__c> experiences;
    @AuraEnabled
    public List<ProjectView> projects;
    @AuraEnabled
    public List<SkillView> skills;
    @AuraEnabled
    public List<Certification__c> certifications;
    @AuraEnabled
    public Datetime generatedAt;
  }

  public class ProjectView {
    @AuraEnabled
    public Project__c record;
    @AuraEnabled
    public List<String> skills = new List<String>();

    public ProjectView(Project__c record) {
      this.record = record;
    }
  }

  public class SkillView {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public String proficiency;
    @AuraEnabled
    public Integer evidenceCount = 0;
    @AuraEnabled
    public List<String> projectSlugs = new List<String>();

    public SkillView(Skill__c skill) {
      this.id = skill.Id;
      this.name = skill.Name;
      this.category = skill.Category__c;
      this.proficiency = skill.Proficiency__c;
    }
  }
}
