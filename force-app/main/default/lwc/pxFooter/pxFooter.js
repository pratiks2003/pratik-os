import { LightningElement, api } from "lwc";

const REPO_URL = "https://github.com/pratiks2003/pratik-os";

export default class PxFooter extends LightningElement {
  @api profile = {};
  @api generatedAt;

  repoUrl = REPO_URL;

  get links() {
    const p = this.profile;
    return [
      { key: "linkedin", label: "linkedin", url: p.LinkedIn_URL__c },
      { key: "github", label: "github", url: p.GitHub_URL__c },
      { key: "trailhead", label: "trailhead", url: p.Trailhead_URL__c }
    ].filter((l) => l.url);
  }

  get fetchedAt() {
    if (!this.generatedAt) {
      return "";
    }
    return new Date(this.generatedAt).toLocaleString("en-GB", {
      dateStyle: "medium",
      timeStyle: "short"
    });
  }

  get year() {
    return new Date().getFullYear();
  }
}
