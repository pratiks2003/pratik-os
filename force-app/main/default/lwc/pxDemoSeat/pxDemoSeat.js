import { LightningElement } from "lwc";
import prepareSeatRace from "@salesforce/apex/DemoController.prepareSeatRace";
import bookSeat from "@salesforce/apex/DemoController.bookSeat";
import seatRaceResult from "@salesforce/apex/DemoController.seatRaceResult";

const BUYERS = ["Ava", "Ben"];

/**
 * Last Seat: fires two booking requests at the same moment, as two real
 * concurrent Apex transactions, with and without SELECT ... FOR UPDATE.
 */
export default class PxDemoSeat extends LightningElement {
  locking = false;
  running = false;
  lanes = {};
  result;
  error;

  get lockOffPressed() {
    return String(!this.locking);
  }

  get lockOnPressed() {
    return String(this.locking);
  }

  get buyers() {
    return BUYERS.map((name) => {
      const lane = this.lanes[name] || {};
      let status = "waiting to start";
      let cls = "lane-status";
      if (lane.state === "booking") {
        status = this.locking
          ? "reading the seat (FOR UPDATE)…"
          : "reading the seat…";
      } else if (lane.state === "done") {
        status = lane.booked
          ? `saw ${lane.seen} seat left → booked ✔`
          : `saw ${lane.seen} seats left → sold out ✖`;
        cls = `lane-status ${lane.booked ? "px-good" : "px-bad"}`;
      }
      return {
        key: name,
        name,
        status,
        cls,
        time: lane.ms ? `${(lane.ms / 1000).toFixed(1)} s` : ""
      };
    });
  }

  get verdict() {
    if (!this.result) {
      return null;
    }
    const count = this.result.bookings.length;
    return this.result.overbooked
      ? {
          cls: "verdict bad",
          title: `💥 Overbooked: ${count} bookings for 1 seat`,
          text: `Both requests read "1 seat left" before either saved, so both sold it. The counter still says ${this.result.seatsLeft}, hiding the double sale. This is a lost-update race.`
        }
      : {
          cls: "verdict good",
          title: `✔ ${count} booking, no oversell`,
          text: "FOR UPDATE locked the seat row. The second request waited for the first to commit, then read 0 seats left and refused the sale."
        };
  }

  handleLocking(event) {
    this.locking = event.currentTarget.dataset.locking === "on";
    this.result = undefined;
    this.lanes = {};
  }

  async handleRace() {
    this.running = true;
    this.error = undefined;
    this.result = undefined;
    this.lanes = { Ava: { state: "booking" }, Ben: { state: "booking" } };
    try {
      const seatId = await prepareSeatRace({ useLocking: this.locking });
      const started = Date.now();
      await Promise.all(
        BUYERS.map(async (buyer) => {
          const outcome = await bookSeat({ seatId, buyer });
          this.lanes = {
            ...this.lanes,
            [buyer]: {
              state: "done",
              booked: outcome.booked,
              seen: outcome.seatsSeen,
              ms: Date.now() - started
            }
          };
        })
      );
      this.result = await seatRaceResult({ seatId });
    } catch (e) {
      this.error = e?.body?.message || "The race could not run right now.";
      this.lanes = {};
    } finally {
      this.running = false;
    }
  }
}
