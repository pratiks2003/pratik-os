/**
 * Event Router demo (fictional "Orbit Supply" shipments).
 *
 * Routes each incoming event through a factory to the strategy registered for
 * its type, and refuses events whose version is not newer than the shipment's
 * current version, so a late or replayed event can never overwrite newer
 * state. Runs entirely in memory and returns a step-by-step trace.
 */
public with sharing class ShipmentEventRouter {
  public static final Integer MAX_EVENTS = 20;

  public static List<TraceStep> route(List<ShipmentEvent> events) {
    Shipment shipment = new Shipment();
    List<TraceStep> trace = new List<TraceStep>();
    Integer index = 0;
    for (ShipmentEvent event : events) {
      if (index == MAX_EVENTS) {
        break;
      }
      TraceStep step = new TraceStep(++index, event);
      if (event.version == null || event.version <= shipment.version) {
        step.outcome = 'stale';
        step.message =
          'Ignored: version ' +
          event.version +
          ' is not newer than current version ' +
          shipment.version +
          '.';
      } else {
        ShipmentEventHandlers.Handler handler = new HandlerFactory()
          .create(event.type);
        if (handler == null) {
          step.outcome = 'unknown';
          step.message =
            'No strategy is registered for "' +
            event.type +
            '". Parked for review.';
        } else {
          step.handler = handler.name();
          try {
            handler.apply(shipment);
            shipment.version = event.version;
            step.outcome = 'applied';
            step.message = 'Shipment is now ' + shipment.status + '.';
          } catch (ShipmentEventHandlers.TransitionException e) {
            step.outcome = 'rejected';
            step.message = e.getMessage();
          }
        }
      }
      step.statusAfter = shipment.status;
      step.versionAfter = shipment.version;
      trace.add(step);
    }
    return trace;
  }

  /** Maps an event type to its strategy class. New types are one registry line. */
  public class HandlerFactory {
    private final Map<String, String> registry = new Map<String, String>{
      'Created' => 'ShipmentEventHandlers.CreatedHandler',
      'Packed' => 'ShipmentEventHandlers.PackedHandler',
      'Shipped' => 'ShipmentEventHandlers.ShippedHandler',
      'Delivered' => 'ShipmentEventHandlers.DeliveredHandler'
    };

    public ShipmentEventHandlers.Handler create(String eventType) {
      String className = registry.get(eventType);
      return className == null
        ? null
        : (ShipmentEventHandlers.Handler) Type.forName(className).newInstance();
    }
  }

  public class Shipment {
    public String status = 'New';
    public Integer version = 0;
  }

  public class ShipmentEvent {
    @AuraEnabled
    public String type { get; set; }
    @AuraEnabled
    public Integer version { get; set; }
  }

  public class TraceStep {
    @AuraEnabled
    public Integer index;
    @AuraEnabled
    public String type;
    @AuraEnabled
    public Integer version;
    @AuraEnabled
    public String handler;
    @AuraEnabled
    public String outcome;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public String statusAfter;
    @AuraEnabled
    public Integer versionAfter;

    public TraceStep(Integer index, ShipmentEvent event) {
      this.index = index;
      this.type = event.type;
      this.version = event.version;
    }
  }
}
