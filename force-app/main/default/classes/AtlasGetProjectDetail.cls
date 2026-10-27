/** Atlas action: full case study for one project, including its STAR story. */
public with sharing class AtlasGetProjectDetail {
  @InvocableMethod(
    label='Get Pratik Project Detail'
    description='Returns the full case study for one of Pratik\'s projects: business impact, technical deep dive, architecture, tech stack, metrics and STAR interview story.'
  )
  public static List<Response> getDetail(List<Request> requests) {
    PortfolioService.SiteData data = PortfolioService.getSiteData();
    PortfolioService.ProjectView project = AtlasKnowledge.findProject(
      data,
      requests.isEmpty() ? null : requests[0].projectName
    );
    Response response = new Response();
    response.found = project != null;
    response.detail = project == null
      ? 'No published project matches that name. Published projects:\n' +
        AtlasKnowledge.searchProjects(data, null)
      : AtlasKnowledge.projectDetail(project);
    return new List<Response>{ response };
  }

  public class Request {
    @InvocableVariable(
      required=true
      description='Project title, part of the title, or slug.'
    )
    public String projectName;
  }

  public class Response {
    @InvocableVariable(
      description='True when a matching published project was found.'
    )
    public Boolean found;
    @InvocableVariable(
      description='The project case study as plain text, including a markdown link to it on the site.'
    )
    public String detail;
  }
}
