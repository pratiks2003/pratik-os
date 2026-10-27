import { LightningElement, wire } from "lwc";
import getSiteData from "@salesforce/apex/PortfolioController.getSiteData";
import recordVisit from "@salesforce/apex/SiteController.recordVisit";
import { prefersReducedMotion } from "c/pxUtils";

const MODE_KEY = "pxMode";
const VISIT_KEY = "pxVisited";

/**
 * Root of the portfolio. Loads every published record in one cacheable call
 * and hands slices to the section components. Owns the recruiter/engineer
 * view mode and in-page navigation.
 */
export default class PxApp extends LightningElement {
  data;
  error;
  mode = "recruiter";

  connectedCallback() {
    try {
      this.mode = window.sessionStorage.getItem(MODE_KEY) || "recruiter";
      if (!window.sessionStorage.getItem(VISIT_KEY)) {
        window.sessionStorage.setItem(VISIT_KEY, "1");
        recordVisit().catch(() => {});
      }
    } catch {
      this.mode = "recruiter";
    }
    this.keyListener = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        this.openPalette();
      }
    };
    window.addEventListener("keydown", this.keyListener);
  }

  disconnectedCallback() {
    window.removeEventListener("keydown", this.keyListener);
  }

  openPalette() {
    this.template.querySelector("c-px-command-palette")?.open();
  }

  handleOpenPalette() {
    this.openPalette();
  }

  handleCommand(event) {
    const { action, value } = event.detail;
    if (action === "navigate") {
      this.scrollTo(value);
    } else if (action === "openProject") {
      this.template.querySelector("c-px-projects")?.openProject(value);
    } else if (action === "demo") {
      this.scrollTo("demos");
      this.template.querySelector("c-px-demos")?.openDemo(value);
    } else if (action === "ask") {
      this.scrollTo("about");
      this.template.querySelector("c-px-hero")?.askAtlas(value);
    } else if (action === "mode") {
      this.handleModeChange({ detail: { mode: value } });
    }
  }

  @wire(getSiteData)
  wiredSiteData({ data, error }) {
    if (data) {
      this.data = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
    }
  }

  get isLoading() {
    return !this.data && !this.error;
  }

  get profile() {
    return this.data?.profile ?? {};
  }

  get highlights() {
    return this.data?.highlights ?? [];
  }

  get experiences() {
    return this.data?.experiences ?? [];
  }

  get projects() {
    return this.data?.projects ?? [];
  }

  get skills() {
    return this.data?.skills ?? [];
  }

  get certifications() {
    return this.data?.certifications ?? [];
  }

  get skillCount() {
    return this.skills.length;
  }

  get generatedAt() {
    return this.data?.generatedAt;
  }

  handleModeChange(event) {
    this.mode = event.detail.mode;
    try {
      window.sessionStorage.setItem(MODE_KEY, this.mode);
    } catch {
      // Storage can be unavailable in private browsing; the mode still applies.
    }
  }

  handleOpenProject(event) {
    this.template
      .querySelector("c-px-projects")
      ?.openProject(event.detail.slug);
  }

  handleNavigate(event) {
    this.scrollTo(event.detail.section);
  }

  scrollTo(section) {
    const target = this.template.querySelector(`[data-section="${section}"]`);
    if (target) {
      target.scrollIntoView({
        behavior: prefersReducedMotion() ? "auto" : "smooth",
        block: "start"
      });
    }
  }
}
