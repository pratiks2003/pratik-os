import { LightningElement, wire } from "lwc";
import getSiteData from "@salesforce/apex/PortfolioController.getSiteData";
import { prefersReducedMotion } from "c/pxUtils";

const MODE_KEY = "pxMode";

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
    } catch {
      this.mode = "recruiter";
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

  handleNavigate(event) {
    const target = this.template.querySelector(
      `[data-section="${event.detail.section}"]`
    );
    if (target) {
      target.scrollIntoView({
        behavior: prefersReducedMotion() ? "auto" : "smooth",
        block: "start"
      });
    }
  }
}
