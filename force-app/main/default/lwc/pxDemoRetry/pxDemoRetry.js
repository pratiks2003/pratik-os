import { LightningElement } from "lwc";
import runPaymentSync from "@salesforce/apex/DemoController.runPaymentSync";

const SCENARIOS = [
  { key: "healthy", label: "healthy gateway" },
  { key: "flaky", label: "flaky network" },
  { key: "outage", label: "gateway outage" },
  { key: "declined", label: "card declined" }
];
const OUTCOMES = {
  SYNCED: { label: "✔ synced", cls: "px-status px-good" },
  RETRY_LATER: {
    label: "⏸ parked for scheduled retry",
    cls: "px-status px-warn"
  },
  NEEDS_HUMAN: { label: "➜ routed to a person", cls: "px-status px-serious" }
};
const CLASSES = {
  success: "px-status px-good",
  transient: "px-status px-warn",
  permanent: "px-status px-bad"
};

/** Self-Healing Sync: retry policy plus error classifier, executed in Apex. */
export default class PxDemoRetry extends LightningElement {
  scenario = "flaky";
  result;
  running = false;
  error;

  get scenarios() {
    return SCENARIOS.map((s) => ({
      ...s,
      pressed: String(this.scenario === s.key)
    }));
  }

  get attempts() {
    return (this.result?.attempts || []).map((a, i) => ({
      key: `a${a.attempt}`,
      ...a,
      badgeClass: CLASSES[a.classification],
      style: `animation-delay: ${i * 220}ms`
    }));
  }

  get outcome() {
    return this.result ? OUTCOMES[this.result.outcome] : null;
  }

  handleScenario(event) {
    this.scenario = event.currentTarget.dataset.key;
    this.result = undefined;
  }

  async handleRun() {
    this.running = true;
    this.error = undefined;
    try {
      this.result = await runPaymentSync({ scenario: this.scenario });
    } catch (e) {
      this.error = e?.body?.message || "The sync could not run right now.";
    } finally {
      this.running = false;
    }
  }
}
