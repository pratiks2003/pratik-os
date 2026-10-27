import { LightningElement, api } from "lwc";
import { prefersReducedMotion } from "c/pxUtils";

const LINE_DELAY_MS = 420;

/**
 * Hero: photo, name and headline beside a terminal that "boots" the org.
 * Every number in the boot sequence is counted from live records.
 */
export default class PxHero extends LightningElement {
  @api profile = {};
  @api projects = [];
  @api skills = [];
  @api certifications = [];

  visibleLines = 0;
  timers = [];

  connectedCallback() {
    const total = this.allLines.length;
    if (prefersReducedMotion()) {
      this.visibleLines = total;
      return;
    }
    for (let i = 1; i <= total; i++) {
      this.timers.push(
        // Typing effect for the boot sequence; cleared on disconnect.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => (this.visibleLines = i), i * LINE_DELAY_MS)
      );
    }
  }

  disconnectedCallback() {
    this.timers.forEach((t) => clearTimeout(t));
  }

  get allLines() {
    const p = this.profile;
    const lines = [
      { kind: "command", text: "sf org display --target-org pratik" },
      {
        kind: "ok",
        text: `Connected · ${p.Headline__c || "Salesforce Developer"}`
      }
    ];
    if (this.certifications.length) {
      lines.push({
        kind: "ok",
        text: `Certified · ${this.certifications.map((c) => c.Name).join(" · ")}`
      });
    }
    lines.push({
      kind: "ok",
      text: `Loaded ${this.projects.length} projects · ${this.skills.length} skills from live records`
    });
    if (p.Availability__c) {
      lines.push({
        kind: "status",
        text: [p.Availability__c, p.Location__c].filter(Boolean).join(" · ")
      });
    }
    return lines.map((line, i) => ({
      ...line,
      key: `l${i}`,
      isCommand: line.kind === "command",
      isStatus: line.kind === "status"
    }));
  }

  get lines() {
    return this.allLines.slice(0, this.visibleLines);
  }

  get booted() {
    return this.visibleLines >= this.allLines.length;
  }

  get firstName() {
    return (this.profile.Name || "").split(" ")[0];
  }

  get roles() {
    return this.profile.Open_To_Roles__c;
  }

  get links() {
    const p = this.profile;
    return [
      { key: "linkedin", label: "LinkedIn", url: p.LinkedIn_URL__c },
      { key: "github", label: "GitHub", url: p.GitHub_URL__c },
      { key: "trailhead", label: "Trailhead", url: p.Trailhead_URL__c }
    ].filter((l) => l.url);
  }

  handleProjects() {
    this.dispatchEvent(
      new CustomEvent("navigate", { detail: { section: "projects" } })
    );
  }

  handleContact() {
    this.dispatchEvent(
      new CustomEvent("navigate", { detail: { section: "contact" } })
    );
  }
}
