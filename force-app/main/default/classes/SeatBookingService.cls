/**
 * Last Seat demo (fictional "Starlight Tickets").
 *
 * Two buyers try to book the last seat at the same moment, as two truly
 * concurrent requests from the browser. Without locking, both read "1 seat
 * left" before either saves, so both book it. With SELECT ... FOR UPDATE, the
 * second request waits for the first to commit, then sees 0 and is refused.
 *
 * Runs without sharing because the public guest user owns no demo rows; it
 * only ever touches Demo_Seat__c and Demo_Booking__c, and every run is deleted
 * when its result is read (stale runs are cleaned up on the next prepare).
 */
public without sharing class SeatBookingService {
  public static final Set<String> BUYERS = new Set<String>{ 'Ava', 'Ben' };
  @TestVisible
  private static Integer contentionMs = 1500;

  public static Id prepare(Boolean useLocking) {
    delete [
      SELECT Id
      FROM Demo_Seat__c
      WHERE CreatedDate < :System.now().addMinutes(-10)
    ];
    Demo_Seat__c seat = new Demo_Seat__c(
      Name = 'Starlight Tickets · Neon Nights, Row A Seat 1',
      Seats_Left__c = 1,
      Use_Locking__c = useLocking == true
    );
    insert seat;
    return seat.Id;
  }

  public static Map<String, Object> book(Id seatId, String buyer) {
    if (!BUYERS.contains(buyer)) {
      throw new IllegalArgumentException('Unknown buyer.');
    }
    Boolean useLocking = [
      SELECT Use_Locking__c
      FROM Demo_Seat__c
      WHERE Id = :seatId
    ]
    .Use_Locking__c;
    Demo_Seat__c seat = useLocking
      ? [
          SELECT Id, Seats_Left__c
          FROM Demo_Seat__c
          WHERE Id = :seatId
          FOR UPDATE
        ]
      : [SELECT Id, Seats_Left__c FROM Demo_Seat__c WHERE Id = :seatId];
    Integer seen = Integer.valueOf(seat.Seats_Left__c);

    Boolean booked = seen > 0;
    if (booked) {
      // Only a buyer who saw a free seat waits for payment, so repeated calls
      // on a sold-out seat return at once instead of burning CPU.
      holdForPayment();
    }
    if (booked) {
      seat.Seats_Left__c = seen - 1;
      update seat;
      insert new Demo_Booking__c(
        Seat__c = seat.Id,
        Buyer__c = buyer,
        Seats_Seen__c = seen
      );
    }
    return new Map<String, Object>{
      'buyer' => buyer,
      'seatsSeen' => seen,
      'booked' => booked,
      'locked' => useLocking
    };
  }

  public static Map<String, Object> result(Id seatId) {
    Demo_Seat__c seat = [
      SELECT
        Seats_Left__c,
        Use_Locking__c,
        (SELECT Buyer__c, Seats_Seen__c FROM Bookings__r ORDER BY CreatedDate)
      FROM Demo_Seat__c
      WHERE Id = :seatId
    ];
    List<Map<String, Object>> bookings = new List<Map<String, Object>>();
    for (Demo_Booking__c booking : seat.Bookings__r) {
      bookings.add(
        new Map<String, Object>{
          'buyer' => booking.Buyer__c,
          'seatsSeen' => booking.Seats_Seen__c
        }
      );
    }
    delete seat;
    return new Map<String, Object>{
      'seatsLeft' => seat.Seats_Left__c,
      'locked' => seat.Use_Locking__c,
      'bookings' => bookings,
      'overbooked' => bookings.size() > 1
    };
  }

  /** Stands in for payment authorisation, widening the window where the race happens. */
  private static void holdForPayment() {
    Long until = System.currentTimeMillis() + contentionMs;
    while (System.currentTimeMillis() < until) {
      continue;
    }
  }
}
