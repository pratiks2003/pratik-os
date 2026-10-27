/**
 * Turns published portfolio records into compact, factual text for Atlas.
 * Everything Atlas says about Pratik comes from here, so the agent can only
 * repeat what is published on the site.
 */
public with sharing class AtlasKnowledge {
  private static final Set<String> MATCH_STOP_WORDS = new Set<String>{
    'project',
    'projects',
    'the',
    'and',
    'for',
    'with',
    'pratik',
    'about'
  };

  private static final Map<String, List<String>> SKILL_SYNONYMS = new Map<String, List<String>>{
    'lightning web components' => new List<String>{ 'lwc' },
    'apex rest' => new List<String>{ 'rest api', 'rest apis', 'restful' },
    'ci cd' => new List<String>{ 'cicd', 'continuous integration', 'devops' },
    'github actions' => new List<String>{ 'github' },
    'platform events' => new List<String>{ 'event driven', 'event bus' },
    'oauth 2 0' => new List<String>{ 'oauth' },
    'flows' => new List<String>{
      'flow',
      'flow builder',
      'record triggered flows'
    },
    'agentforce' => new List<String>{
      'einstein',
      'ai agents',
      'genai',
      'generative ai'
    },
    'batch apex' => new List<String>{ 'asynchronous apex', 'async apex' },
    'queueable apex' => new List<String>{ 'asynchronous apex', 'async apex' }
  };

  public static String profileSummary(PortfolioService.SiteData data) {
    List<String> lines = new List<String>();
    Portfolio_Profile__c p = data.profile;
    if (p != null) {
      lines.add('Name: ' + p.Name);
      lines.add('Headline: ' + p.Headline__c);
      lines.add('Tagline: ' + p.Tagline__c);
      lines.add('Bio: ' + p.Bio__c);
      lines.add('Availability: ' + p.Availability__c);
      lines.add('Location: ' + p.Location__c);
      lines.add('Open to roles: ' + p.Open_To_Roles__c);
      lines.add('LinkedIn: ' + p.LinkedIn_URL__c);
      lines.add('GitHub: ' + p.GitHub_URL__c);
      lines.add('Trailhead: ' + p.Trailhead_URL__c);
    }
    lines.add('Experience:');
    for (Experience__c e : data.experiences) {
      lines.add(
        '- ' +
          e.Name +
          ' at ' +
          e.Company__c +
          (String.isBlank(e.Engagement__c)
            ? ''
            : ' (' + e.Engagement__c + ')') +
          ', ' +
          formatPeriod(e) +
          '. ' +
          e.Summary__c
      );
    }
    lines.add('Certifications:');
    for (Certification__c c : data.certifications) {
      lines.add(
        '- ' +
          c.Name +
          ' (' +
          c.Issuer__c +
          ')' +
          (c.Issued_Date__c == null
            ? ''
            : ', issued ' + c.Issued_Date__c.format())
      );
    }
    lines.add('Highlights:');
    for (Highlight__c h : data.highlights) {
      lines.add(
        '- ' +
          (h.Value__c == null ? '' : h.Value__c.format()) +
          (h.Suffix__c ?? '') +
          ' ' +
          h.Name
      );
    }
    lines.add('Projects (use get_project_detail for depth):');
    for (PortfolioService.ProjectView project : data.projects) {
      lines.add('- ' + projectLine(project));
    }
    return String.join(lines, '\n');
  }

  public static String searchProjects(
    PortfolioService.SiteData data,
    String searchTerm
  ) {
    List<String> terms = TextFingerprint.tokens(searchTerm);
    List<String> lines = new List<String>();
    for (PortfolioService.ProjectView project : data.projects) {
      if (terms.isEmpty() || matchesAny(searchableText(project), terms)) {
        lines.add('- ' + projectLine(project));
      }
    }
    return lines.isEmpty()
      ? 'No published project matches "' +
        searchTerm +
        '". Published projects:\n' +
        searchProjects(data, null)
      : String.join(lines, '\n');
  }

  public static PortfolioService.ProjectView findProject(
    PortfolioService.SiteData data,
    String nameOrSlug
  ) {
    String wanted = TextFingerprint.normalize(nameOrSlug);
    if (String.isBlank(wanted)) {
      return null;
    }
    PortfolioService.ProjectView best;
    Integer bestScore = 0;
    for (PortfolioService.ProjectView project : data.projects) {
      String slug = TextFingerprint.normalize(project.record.Slug__c);
      String title = TextFingerprint.normalize(project.record.Name);
      if (wanted == slug || wanted == title) {
        return project;
      }
      Integer score = 0;
      for (String token : wanted.split(' ')) {
        if (
          token.length() > 2 &&
          !MATCH_STOP_WORDS.contains(token) &&
          (' ' + title + ' ' + slug + ' ').contains(' ' + token)
        ) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = project;
      }
    }
    return best;
  }

  public static String projectDetail(PortfolioService.ProjectView project) {
    Project__c r = project.record;
    List<String> lines = new List<String>{
      'Title: ' + r.Name,
      'Site link: #project/' + r.Slug__c,
      'Category: ' +
      r.Category__c +
      ' (' +
      r.Project_Type__c +
      ')',
      'Tagline: ' + r.Tagline__c,
      'Metrics: ' + (r.Metrics__c ?? ''),
      'Tech stack: ' + String.join(project.skills, ', '),
      'Business impact: ' + (r.Business_Impact__c ?? ''),
      'Technical deep dive:\n' + (r.Technical_Deep_Dive__c ?? '')
    };
    if (String.isNotBlank(r.STAR_Story__c)) {
      lines.add('STAR story:\n' + r.STAR_Story__c);
    }
    if (String.isNotBlank(r.Repo_URL__c)) {
      lines.add('Source code: ' + r.Repo_URL__c);
    }
    return String.join(lines, '\n');
  }

  /** Skills named in a job description, each with the projects that prove it. */
  public static String matchJob(
    PortfolioService.SiteData data,
    String jobDescription
  ) {
    String jd = ' ' + TextFingerprint.normalize(jobDescription) + ' ';
    Map<String, String> projectTitles = new Map<String, String>();
    for (PortfolioService.ProjectView project : data.projects) {
      projectTitles.put(project.record.Slug__c, project.record.Name);
    }

    // Broad skills the JD names directly, e.g. "apex". A specialised skill
    // such as "Queueable Apex" then counts as evidence for it.
    Set<String> namedBroadSkills = new Set<String>();
    for (PortfolioService.SkillView skill : data.skills) {
      String key = TextFingerprint.normalize(skill.name);
      if (!key.contains(' ') && mentions(jd, key)) {
        namedBroadSkills.add(key);
      }
    }

    List<String> matched = new List<String>();
    List<String> catalogue = new List<String>();
    for (PortfolioService.SkillView skill : data.skills) {
      String key = TextFingerprint.normalize(skill.name);
      Boolean namedInJd = mentions(jd, key);
      for (String token : key.split(' ')) {
        namedInJd =
          namedInJd || (key.contains(' ') && namedBroadSkills.contains(token));
      }
      List<String> evidence = new List<String>();
      for (String slug : skill.projectSlugs) {
        evidence.add('"' + projectTitles.get(slug) + '"');
      }
      String entry =
        skill.name +
        ' (' +
        skill.category +
        ') proven in ' +
        String.join(evidence, ', ');
      catalogue.add('- ' + entry);
      if (namedInJd) {
        matched.add('- ' + entry);
      }
    }

    return 'Skills named in the job description that Pratik has proven:\n' +
      (matched.isEmpty()
        ? '- none matched by name'
        : String.join(matched, '\n')) +
      '\n\nPratik\'s full skill catalogue (use it to judge requirements phrased differently):\n' +
      String.join(catalogue, '\n') +
      '\n\nProfile:\n' +
      profileSummary(data);
  }

  public static String projectLink(Project__c record) {
    return '"' + record.Name + '"';
  }

  private static String projectLine(PortfolioService.ProjectView project) {
    Project__c r = project.record;
    return projectLink(r) +
      ' | ' +
      r.Category__c +
      ' | ' +
      r.Tagline__c +
      ' | skills: ' +
      String.join(project.skills, ', ') +
      (String.isBlank(r.Metrics__c) ? '' : ' | ' + r.Metrics__c);
  }

  private static String searchableText(PortfolioService.ProjectView project) {
    Project__c r = project.record;
    return ' ' +
      TextFingerprint.normalize(
        String.join(
          new List<String>{
            r.Name,
            r.Tagline__c,
            r.Category__c,
            r.Business_Impact__c,
            r.Technical_Deep_Dive__c,
            String.join(project.skills, ' ')
          },
          ' '
        )
      ) +
      ' ';
  }

  private static Boolean matchesAny(String text, List<String> terms) {
    for (String term : terms) {
      if (term.length() > 2 && text.contains(' ' + term)) {
        return true;
      }
    }
    return false;
  }

  private static Boolean mentions(String paddedJd, String skillKey) {
    if (paddedJd.contains(' ' + skillKey + ' ')) {
      return true;
    }
    for (String synonym : SKILL_SYNONYMS.get(skillKey) ?? new List<String>()) {
      if (paddedJd.contains(' ' + synonym + ' ')) {
        return true;
      }
    }
    return false;
  }

  private static String formatPeriod(Experience__c e) {
    String start = e.Start_Date__c == null
      ? ''
      : e.Start_Date__c.year() +
        '-' +
        String.valueOf(e.Start_Date__c.month()).leftPad(2, '0');
    String finish = e.Is_Current__c
      ? 'present'
      : (e.End_Date__c == null
          ? ''
          : e.End_Date__c.year() +
            '-' +
            String.valueOf(e.End_Date__c.month()).leftPad(2, '0'));
    return String.isBlank(start) ? finish : start + ' to ' + finish;
  }
}
