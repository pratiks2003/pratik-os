import { LightningElement } from "lwc";
import runLimitsArena from "@salesforce/apex/DemoController.runLimitsArena";

const SIZES = [10, 50, 200];

function meter(label, value, limit, needed) {
  const ratio = Math.min(value / limit, 1);
  const over = needed > limit;
  const tone = over ? "bad" : ratio >= 0.6 ? "warn" : "good";
  return {
    key: label,
    label,
    value: `${value} / ${limit}`,
    needed: over ? `needs ${needed}` : "",
    fillStyle: `width: ${Math.max(ratio * 100, 1.5)}%`,
    fillClass: `fill fill-${tone}`
  };
}

/** Governor Limits Arena: bulkified code vs SOQL and DML in a loop, live. */
export default class PxDemoLimits extends LightningElement {
  size = 200;
  running = false;
  result;
  error;

  get sizes() {
    return SIZES.map((s) => ({
      key: s,
      value: s,
      pressed: String(this.size === s)
    }));
  }

  get runLabel() {
    return this.running ? "running in the org…" : `▶ run ${this.size} orders`;
  }

  get cards() {
    if (!this.result) {
      return [];
    }
    const r = this.result;
    return [r.bulkified, r.naive].map((a) => {
      const crashes =
        a.queriesNeeded > r.queryLimit || a.dmlNeeded > r.dmlLimit;
      return {
        key: a.name,
        title: a.name === "bulkified" ? "Bulkified" : "SOQL + DML in a loop",
        subtitle:
          a.name === "bulkified"
            ? "one query, one update for all orders"
            : "a query and an update per order",
        ok: !crashes,
        badge: crashes ? "✖ would crash" : "✔ within limits",
        badgeClass: `px-status ${crashes ? "px-bad" : "px-good"}`,
        meters: [
          meter("SOQL queries", a.queries, r.queryLimit, a.queriesNeeded),
          meter("DML statements", a.dmlStatements, r.dmlLimit, a.dmlNeeded)
        ],
        cpu: `${a.cpuMs} ms CPU`,
        processed: `${a.processed} / ${a.records} orders processed`,
        note: a.halted
          ? `Stopped at order ${a.processed} of ${a.records} to keep this request alive. Unguarded, query ${r.queryLimit + 1} throws System.LimitException: Too many SOQL queries: ${r.queryLimit + 1}, which no try/catch can stop.`
          : ""
      };
    });
  }

  handleSize(event) {
    this.size = Number(event.currentTarget.dataset.value);
  }

  async handleRun() {
    this.running = true;
    this.error = undefined;
    try {
      this.result = await runLimitsArena({ recordCount: this.size });
    } catch (e) {
      this.error = e?.body?.message || "The demo could not run right now.";
    } finally {
      this.running = false;
    }
  }
}
