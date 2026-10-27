/** Atlas action: saves a visitor's contact request for Pratik. */
public with sharing class AtlasCreateInquiry {
  private static final Pattern EMAIL_FORMAT = Pattern.compile(
    '^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$'
  );

  @InvocableMethod(
    label='Create Inquiry for Pratik'
    description='Saves a visitor\'s contact details and message so Pratik can follow up. Only call after the visitor has confirmed their name and email.'
  )
  public static List<Response> create(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request request : requests) {
      responses.add(createOne(request));
    }
    return responses;
  }

  private static Response createOne(Request request) {
    Response response = new Response();
    String email = request.email?.trim();
    if (
      String.isBlank(request.fullName) ||
      String.isBlank(email) ||
      !EMAIL_FORMAT.matcher(email).matches()
    ) {
      response.success = false;
      response.message = 'A name and a valid email address are required before the inquiry can be saved.';
      return response;
    }
    Inquiry__c inquiry = new Inquiry__c(
      Full_Name__c = request.fullName.left(120),
      Email__c = email,
      Company__c = request.company?.left(120),
      Role_Hiring_For__c = request.roleHiringFor?.left(120),
      Message__c = request.message?.left(5000),
      JD_Text__c = request.jobDescription?.left(32768),
      Conversation_Summary__c = request.conversationSummary?.left(5000),
      Interest_Score__c = request.interestScore == null
        ? null
        : Math.max(1, Math.min(10, request.interestScore)),
      Source__c = 'Atlas',
      Status__c = 'New'
    );
    insert as user inquiry;
    response.success = true;
    response.reference = [
      SELECT Name
      FROM Inquiry__c
      WHERE Id = :inquiry.Id
      WITH USER_MODE
    ]
    .Name;
    response.message =
      'Saved. Pratik has been notified and will reply to ' +
      email +
      '.';
    return response;
  }

  public class Request {
    @InvocableVariable(required=true description='Visitor\'s full name.')
    public String fullName;
    @InvocableVariable(required=true description='Visitor\'s email address.')
    public String email;
    @InvocableVariable(description='Visitor\'s company.')
    public String company;
    @InvocableVariable(
      description='The role the visitor is hiring for, if any.'
    )
    public String roleHiringFor;
    @InvocableVariable(description='The visitor\'s message for Pratik.')
    public String message;
    @InvocableVariable(
      description='Job description text, if the visitor shared one.'
    )
    public String jobDescription;
    @InvocableVariable(
      description='Short summary of what the visitor asked about in this conversation.'
    )
    public String conversationSummary;
    @InvocableVariable(
      description='1 to 10: how strong a hiring opportunity this looks, 10 being a concrete role with clear fit.'
    )
    public Integer interestScore;
  }

  public class Response {
    @InvocableVariable(description='True when the inquiry was saved.')
    public Boolean success;
    @InvocableVariable(
      description='Inquiry reference number, for example INQ-00001.'
    )
    public String reference;
    @InvocableVariable(description='Message to relay to the visitor.')
    public String message;
  }
}
