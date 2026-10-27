import { LightningElement, api } from "lwc";
import { prefersReducedMotion } from "c/pxUtils";

const DURATION_MS = 1400;

/** Highlight stat tiles; values count up once when scrolled into view. */
export default class PxStats extends LightningElement {
  @api highlights = [];

  progress = 0;
  frame;
  observer;
  started = false;

  renderedCallback() {
    if (this.observer || this.started) {
      return;
    }
    if (prefersReducedMotion() || typeof IntersectionObserver === "undefined") {
      this.started = true;
      this.progress = 1;
      return;
    }
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) {
        this.observer.disconnect();
        this.start();
      }
    });
    this.observer.observe(this.template.querySelector(".stats"));
  }

  disconnectedCallback() {
    this.observer?.disconnect();
    cancelAnimationFrame(this.frame);
  }

  start() {
    this.started = true;
    const began = performance.now();
    const tick = (now) => {
      const t = Math.min((now - began) / DURATION_MS, 1);
      this.progress = 1 - Math.pow(1 - t, 3);
      if (t < 1) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.frame = requestAnimationFrame(tick);
      }
    };
    // Count-up animation; cancelled on disconnect.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.frame = requestAnimationFrame(tick);
  }

  get tiles() {
    return this.highlights.map((h) => ({
      key: h.Id,
      label: h.Name,
      value: Math.round((h.Value__c || 0) * this.progress).toLocaleString(
        "en-US"
      ),
      finalValue: `${(h.Value__c || 0).toLocaleString("en-US")}${h.Suffix__c || ""}`,
      suffix: h.Suffix__c || ""
    }));
  }
}
