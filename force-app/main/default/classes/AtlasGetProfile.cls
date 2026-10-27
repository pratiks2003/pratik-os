/** Atlas action: everything published about Pratik in one compact summary. */
public with sharing class AtlasGetProfile {
  @InvocableMethod(
    label='Get Pratik Profile'
    description='Returns Pratik Shinde\'s published profile: headline, bio, availability, experience, certifications, highlights and a list of projects.'
  )
  public static List<Response> getProfile(List<Request> requests) {
    Response response = new Response();
    response.profile = AtlasKnowledge.profileSummary(
      PortfolioService.getSiteData()
    );
    return new List<Response>{ response };
  }

  public class Request {
    @InvocableVariable(description='Optional topic the visitor asked about.')
    public String topic;
  }

  public class Response {
    @InvocableVariable(
      description='Published facts about Pratik as plain text.'
    )
    public String profile;
  }
}
