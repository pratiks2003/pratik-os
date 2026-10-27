/** Atlas action: published projects matching a skill, technology or theme. */
public with sharing class AtlasSearchProjects {
  @InvocableMethod(
    label='Search Pratik Projects'
    description='Finds Pratik\'s published projects that match a skill, technology, category or theme. Leave the search term blank to list all projects.'
  )
  public static List<Response> search(List<Request> requests) {
    Response response = new Response();
    response.projects = AtlasKnowledge.searchProjects(
      PortfolioService.getSiteData(),
      requests.isEmpty() ? null : requests[0].searchTerm
    );
    return new List<Response>{ response };
  }

  public class Request {
    @InvocableVariable(
      description='Skill, technology or theme, for example "Apex REST" or "integration".'
    )
    public String searchTerm;
  }

  public class Response {
    @InvocableVariable(
      description='Matching projects, one per line, each with a markdown link to the project on the site.'
    )
    public String projects;
  }
}
