/**
 * Strategies for the Event Router demo (fictional "Orbit Supply" shipments).
 * Each handler owns one event type and the state transition it allows, so
 * a new event type is a new class, not an edit to existing logic.
 */
public with sharing class ShipmentEventHandlers {
  public interface Handler {
    String name();
    void apply(ShipmentEventRouter.Shipment shipment);
  }

  public abstract class StatusTransition implements Handler {
    protected abstract Set<String> allowedFrom();
    protected abstract String target();

    public void apply(ShipmentEventRouter.Shipment shipment) {
      if (!allowedFrom().contains(shipment.status)) {
        throw new TransitionException(
          'Cannot move a shipment from ' +
            shipment.status +
            ' to ' +
            target() +
            '.'
        );
      }
      shipment.status = target();
    }
  }

  public class CreatedHandler extends StatusTransition {
    public String name() {
      return 'CreatedHandler';
    }
    protected override Set<String> allowedFrom() {
      return new Set<String>{ 'New' };
    }
    protected override String target() {
      return 'Created';
    }
  }

  public class PackedHandler extends StatusTransition {
    public String name() {
      return 'PackedHandler';
    }
    protected override Set<String> allowedFrom() {
      return new Set<String>{ 'Created' };
    }
    protected override String target() {
      return 'Packed';
    }
  }

  public class ShippedHandler extends StatusTransition {
    public String name() {
      return 'ShippedHandler';
    }
    protected override Set<String> allowedFrom() {
      return new Set<String>{ 'Packed' };
    }
    protected override String target() {
      return 'Shipped';
    }
  }

  public class DeliveredHandler extends StatusTransition {
    public String name() {
      return 'DeliveredHandler';
    }
    protected override Set<String> allowedFrom() {
      return new Set<String>{ 'Shipped' };
    }
    protected override String target() {
      return 'Delivered';
    }
  }

  public class TransitionException extends Exception {
  }
}
