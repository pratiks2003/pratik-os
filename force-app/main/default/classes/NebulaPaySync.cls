/**
 * Self-Healing Sync demo (fictional "Nebula Pay" gateway).
 *
 * Retries transient failures with exponential backoff, parks the payment for
 * a scheduled retry when attempts run out, and routes permanent failures to a
 * person instead of retrying forever. The gateway is simulated in memory, so
 * no callouts are made and backoff delays are reported, not slept.
 */
public with sharing class NebulaPaySync {
  public static final Integer MAX_ATTEMPTS = 4;
  public static final Integer BASE_BACKOFF_MS = 200;

  public static SyncResult sync(Gateway gateway) {
    SyncResult result = new SyncResult();
    for (Integer attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      HttpResponse response = gateway.charge(attempt);
      Attempt step = new Attempt(
        attempt,
        response,
        new ErrorClassifier().classifyCode(response.getStatusCode())
      );
      result.attempts.add(step);

      if (step.classification == 'success') {
        step.action = 'Payment confirmed.';
        result.outcome = 'SYNCED';
        result.summary = 'Synced on attempt ' + attempt + '.';
        return result;
      }
      if (step.classification == 'permanent') {
        step.action = 'Not retryable. Routed to the payments review queue.';
        result.outcome = 'NEEDS_HUMAN';
        result.summary = 'A person needs to look at this payment; retrying would only repeat the error.';
        return result;
      }
      if (attempt < MAX_ATTEMPTS) {
        step.backoffMs = BASE_BACKOFF_MS * Math.pow(2, attempt - 1).intValue();
        step.action =
          'Transient. Retry in ' +
          step.backoffMs +
          ' ms (a Queueable job in production).';
      } else {
        step.action = 'Attempts exhausted. Parked for the scheduled retry job.';
      }
    }
    result.outcome = 'RETRY_LATER';
    result.summary =
      'Still failing after ' +
      MAX_ATTEMPTS +
      ' attempts. Parked safely; nothing was lost or double-charged.';
    return result;
  }

  /** Separates failures worth retrying from ones a retry can never fix. */
  public class ErrorClassifier {
    private final Set<Integer> transientCodes = new Set<Integer>{
      408,
      425,
      429,
      500,
      502,
      503,
      504
    };

    public String classifyCode(Integer statusCode) {
      if (statusCode >= 200 && statusCode < 300) {
        return 'success';
      }
      return transientCodes.contains(statusCode) ? 'transient' : 'permanent';
    }
  }

  public interface Gateway {
    HttpResponse charge(Integer attempt);
  }

  /** In-memory Nebula Pay with failure modes the visitor can inject. */
  public class SimulatedGateway implements Gateway {
    private final String scenario;

    public SimulatedGateway(String scenario) {
      this.scenario = scenario;
    }

    public HttpResponse charge(Integer attempt) {
      switch on scenario {
        when 'flaky' {
          return attempt <= 2
            ? response(503, 'service_unavailable')
            : response(200, 'captured');
        }
        when 'outage' {
          return Math.mod(attempt, 2) == 0
            ? response(429, 'rate_limited')
            : response(503, 'service_unavailable');
        }
        when 'declined' {
          return response(402, 'card_declined');
        }
        when else {
          return response(200, 'captured');
        }
      }
    }

    private HttpResponse response(Integer statusCode, String code) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCode);
      response.setBody(
        JSON.serialize(new Map<String, Object>{ 'status' => code })
      );
      return response;
    }
  }

  public class SyncResult {
    @AuraEnabled
    public String outcome;
    @AuraEnabled
    public String summary;
    @AuraEnabled
    public List<Attempt> attempts = new List<Attempt>();
  }

  public class Attempt {
    @AuraEnabled
    public Integer attempt;
    @AuraEnabled
    public Integer statusCode;
    @AuraEnabled
    public String body;
    @AuraEnabled
    public String classification;
    @AuraEnabled
    public String action;
    @AuraEnabled
    public Integer backoffMs;

    public Attempt(
      Integer attempt,
      HttpResponse response,
      String classification
    ) {
      this.attempt = attempt;
      this.statusCode = response.getStatusCode();
      this.body = response.getBody();
      this.classification = classification;
    }
  }
}
