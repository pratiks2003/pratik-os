/** Atlas action: evidence for matching a job description to Pratik's work. */
public with sharing class AtlasMatchJobDescription {
  @InvocableMethod(
    label='Match Job Description'
    description='Compares a job description with Pratik\'s published skills and projects. Returns matched skills with the projects that prove them, the full skill catalogue and the profile.'
  )
  public static List<Response> match(List<Request> requests) {
    String jd = requests.isEmpty() ? '' : requests[0].jobDescription;
    Response response = new Response();
    response.evidence = AtlasKnowledge.matchJob(
      PortfolioService.getSiteData(),
      jd
    );
    return new List<Response>{ response };
  }

  public class Request {
    @InvocableVariable(
      required=true
      description='The job description text pasted by the visitor.'
    )
    public String jobDescription;
  }

  public class Response {
    @InvocableVariable(
      description='Matched skills with project evidence, the skill catalogue and profile.'
    )
    public String evidence;
  }
}
