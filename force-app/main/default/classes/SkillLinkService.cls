/**
 * The "one record" engine. Turns a project's comma-separated Tech_Stack__c
 * into Skill__c records and Project_Skill__c links, creating skills on first
 * use and removing links that are no longer listed. Bulk-safe: a fixed number
 * of queries and DML statements regardless of how many projects are saved.
 */
public with sharing class SkillLinkService {
  public static void sync(List<Project__c> projects) {
    Map<Id, Map<String, String>> wantedByProject = new Map<Id, Map<String, String>>();
    Map<String, String> allSkills = new Map<String, String>();
    for (Project__c project : projects) {
      Map<String, String> parsed = parse(project.Tech_Stack__c);
      wantedByProject.put(project.Id, parsed);
      for (String key : parsed.keySet()) {
        if (!allSkills.containsKey(key)) {
          allSkills.put(key, parsed.get(key));
        }
      }
    }

    Map<String, Id> skillIds = ensureSkills(allSkills);

    Set<String> existingKeys = new Set<String>();
    List<Project_Skill__c> toDelete = new List<Project_Skill__c>();
    for (Project_Skill__c link : [
      SELECT Id, Key__c, Project__c, Skill__r.Key__c
      FROM Project_Skill__c
      WHERE Project__c IN :wantedByProject.keySet()
    ]) {
      if (
        wantedByProject.get(link.Project__c).containsKey(link.Skill__r.Key__c)
      ) {
        existingKeys.add(link.Key__c);
      } else {
        toDelete.add(link);
      }
    }

    List<Project_Skill__c> toInsert = new List<Project_Skill__c>();
    for (Id projectId : wantedByProject.keySet()) {
      for (String skillKey : wantedByProject.get(projectId).keySet()) {
        String linkKey = projectId + ':' + skillKey;
        if (!existingKeys.contains(linkKey)) {
          toInsert.add(
            new Project_Skill__c(
              Project__c = projectId,
              Skill__c = skillIds.get(skillKey),
              Key__c = linkKey
            )
          );
        }
      }
    }

    delete toDelete;
    insert toInsert;
  }

  /** Returns normalised key -> display name, keeping the first spelling used. */
  public static Map<String, String> parse(String techStack) {
    Map<String, String> skills = new Map<String, String>();
    if (String.isBlank(techStack)) {
      return skills;
    }
    for (String raw : techStack.split('[,;\\n]')) {
      String name = raw.trim();
      String key = TextFingerprint.normalize(name).left(100);
      if (String.isNotBlank(key) && !skills.containsKey(key)) {
        skills.put(key, name.left(80));
      }
    }
    return skills;
  }

  private static Map<String, Id> ensureSkills(Map<String, String> namesByKey) {
    Map<String, Id> ids = new Map<String, Id>();
    if (namesByKey.isEmpty()) {
      return ids;
    }
    for (Skill__c skill : [
      SELECT Id, Key__c
      FROM Skill__c
      WHERE Key__c IN :namesByKey.keySet()
    ]) {
      ids.put(skill.Key__c.toLowerCase(), skill.Id);
    }

    List<Skill__c> created = new List<Skill__c>();
    for (String key : namesByKey.keySet()) {
      if (!ids.containsKey(key)) {
        created.add(
          new Skill__c(
            Name = namesByKey.get(key),
            Key__c = key,
            Category__c = SkillCategorizer.categorize(key),
            Published__c = true
          )
        );
      }
    }
    insert created;
    for (Skill__c skill : created) {
      ids.put(skill.Key__c, skill.Id);
    }
    return ids;
  }
}
