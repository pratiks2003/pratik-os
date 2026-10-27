import { LightningElement } from "lwc";
import routeShipmentEvents from "@salesforce/apex/DemoController.routeShipmentEvents";

const TYPES = ["Created", "Packed", "Shipped", "Delivered"];
const PRESETS = {
  happy: [
    ["Created", 1],
    ["Packed", 2],
    ["Shipped", 3],
    ["Delivered", 4]
  ],
  outOfOrder: [
    ["Created", 1],
    ["Shipped", 2],
    ["Packed", 3],
    ["Shipped", 4]
  ],
  replay: [
    ["Created", 1],
    ["Packed", 2],
    ["Created", 1],
    ["Packed", 2],
    ["Shipped", 3]
  ]
};
const OUTCOME = {
  applied: { label: "✔ applied", cls: "px-status px-good" },
  stale: { label: "↺ stale, ignored", cls: "px-status px-warn" },
  rejected: { label: "✖ rejected", cls: "px-status px-bad" },
  unknown: { label: "? no strategy", cls: "px-status px-serious" }
};

/** Event Router: Strategy + Factory with version gating, executed in Apex. */
export default class PxDemoRouter extends LightningElement {
  events = PRESETS.outOfOrder.map(([type, version]) => ({ type, version }));
  trace;
  running = false;
  error;

  get palette() {
    return [...TYPES, "Teleported"].map((t) => ({ key: t, type: t }));
  }

  get queue() {
    return this.events.map((e, i) => ({
      key: `q${i}`,
      label: `${e.type} v${e.version}`
    }));
  }

  get runDisabled() {
    return this.running || !this.events.length;
  }

  get nextVersion() {
    return this.events.reduce((max, e) => Math.max(max, e.version), 0) + 1;
  }

  get steps() {
    return (this.trace || []).map((s, i) => ({
      key: `s${s.index}`,
      ...s,
      handler: s.handler || "—",
      badge: OUTCOME[s.outcome].label,
      badgeClass: OUTCOME[s.outcome].cls,
      rowStyle: `animation-delay: ${i * 120}ms`
    }));
  }

  handleAdd(event) {
    if (this.events.length >= 12) {
      return;
    }
    this.events = [
      ...this.events,
      { type: event.currentTarget.dataset.type, version: this.nextVersion }
    ];
    this.trace = undefined;
  }

  handleReplay() {
    if (this.events.length) {
      this.events = [
        ...this.events,
        { ...this.events[this.events.length - 1] }
      ];
      this.trace = undefined;
    }
  }

  handlePreset(event) {
    this.events = PRESETS[event.currentTarget.dataset.preset].map(
      ([type, version]) => ({ type, version })
    );
    this.trace = undefined;
  }

  handleClear() {
    this.events = [];
    this.trace = undefined;
  }

  async handleRun() {
    this.running = true;
    this.error = undefined;
    try {
      this.trace = await routeShipmentEvents({
        eventsJson: JSON.stringify(this.events)
      });
    } catch (e) {
      this.error = e?.body?.message || "The router could not run right now.";
    } finally {
      this.running = false;
    }
  }
}
