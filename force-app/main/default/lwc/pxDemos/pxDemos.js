import { LightningElement, api } from "lwc";

const DEMOS = [
  {
    key: "limits",
    label: "governor limits",
    title: "Governor Limits Arena",
    sources: ["LimitsArena"]
  },
  {
    key: "router",
    label: "event router",
    title: "Strategy + Factory Event Router",
    sources: ["ShipmentEventRouter", "ShipmentEventHandlers"]
  },
  {
    key: "retry",
    label: "self-healing sync",
    title: "Self-Healing Sync",
    sources: ["NebulaPaySync"]
  },
  {
    key: "seat",
    label: "last seat",
    title: "The Last Seat Problem",
    sources: ["SeatBookingService"]
  }
];

/** Live demos: real Apex running in the org, fictional businesses, source on demand. */
export default class PxDemos extends LightningElement {
  active = "limits";
  showSource = false;
  sourceClass = "LimitsArena";

  get tabs() {
    return DEMOS.map((d) => ({
      ...d,
      selected: String(this.active === d.key),
      tabIndex: this.active === d.key ? "0" : "-1"
    }));
  }

  get demo() {
    return DEMOS.find((d) => d.key === this.active);
  }

  get isLimits() {
    return this.active === "limits";
  }

  get isRouter() {
    return this.active === "router";
  }

  get isRetry() {
    return this.active === "retry";
  }

  get isSeat() {
    return this.active === "seat";
  }

  get sourceButtons() {
    return this.demo.sources.map((s) => ({
      key: s,
      name: s,
      pressed: String(this.showSource && this.sourceClass === s)
    }));
  }

  /** Opens a demo tab from outside, e.g. the command palette. */
  @api
  openDemo(key) {
    if (DEMOS.some((d) => d.key === key)) {
      this.active = key;
      this.showSource = false;
      this.sourceClass = this.demo.sources[0];
    }
  }

  handleTab(event) {
    this.active = event.currentTarget.dataset.key;
    this.showSource = false;
    this.sourceClass = this.demo.sources[0];
  }

  handleSource(event) {
    const name = event.currentTarget.dataset.name;
    this.showSource = !(this.showSource && this.sourceClass === name);
    this.sourceClass = name;
  }
}
