import { LightningElement, wire } from "lwc";
import getStats from "@salesforce/apex/SiteController.getStats";

const ARCHITECTURE = [
  "Visitor -> LWR Site : HTTPS, guest user",
  "LWR Site -> Apex Controllers : cacheable, user mode",
  "Apex Controllers -> Published Records : guest sharing rules",
  "LWR Site -> Atlas : invocable agent action",
  "Atlas -> Apex Actions : live record lookups",
  "GitHub -> GitHub Actions : push to main",
  "GitHub Actions -> Salesforce Org : deploy, test, publish",
  "GitHub Actions -> Org Snapshot : metrics"
].join("\n");

const SECURITY = [
  {
    key: "guest",
    title: "Read-only guest",
    text: "Visitors run as a locked-down guest user with read access to published records only."
  },
  {
    key: "mode",
    title: "User-mode queries",
    text: "Every query runs WITH USER_MODE, so permissions and sharing are enforced by the platform."
  },
  {
    key: "smoke",
    title: "Leak test on every deploy",
    text: "After each deploy, CI calls the live site anonymously and fails if any draft is visible."
  },
  {
    key: "caps",
    title: "Credit guard",
    text: "Atlas, the demos and the contact form each have daily caps and input limits."
  },
  {
    key: "secrets",
    title: "Confidentiality guard",
    text: "Publishing is blocked if text contains a confidential term; terms are stored only as keyed hashes."
  },
  {
    key: "repo",
    title: "No secrets in Git",
    text: "CI authenticates with a GitHub secret; the public repo holds no credentials or personal data."
  }
];

function timeAgo(value) {
  if (!value) {
    return "";
  }
  const minutes = Math.round((Date.now() - new Date(value).getTime()) / 60000);
  if (minutes < 60) {
    return `${Math.max(minutes, 1)} min ago`;
  }
  const hours = Math.round(minutes / 60);
  return hours < 48 ? `${hours} h ago` : `${Math.round(hours / 24)} days ago`;
}

/** How the site is built, with numbers the CI pipeline writes into the org. */
export default class PxBehindScenes extends LightningElement {
  stats;
  error;
  architecture = ARCHITECTURE;
  security = SECURITY;
  repoUrl = "https://github.com/pratiks2003/pratik-os";

  @wire(getStats)
  wiredStats({ data, error }) {
    this.stats = data;
    this.error = error;
  }

  get latest() {
    const d = this.stats?.deployments?.[0];
    if (!d) {
      return null;
    }
    return {
      sha: d.Name,
      message: d.Commit_Message__c,
      commitUrl: d.Commit_URL__c,
      runUrl: d.Run_URL__c,
      when: timeAgo(d.Deployed_At__c),
      tests: `${d.Apex_Tests_Passed__c}/${d.Apex_Tests__c}`,
      allPassing: d.Apex_Tests_Passed__c === d.Apex_Tests__c,
      coverage: `${d.Code_Coverage__c}%`,
      coverageStyle: `width: ${Math.min(d.Code_Coverage__c || 0, 100)}%`,
      tiles: [
        { key: "classes", label: "Apex classes", value: d.Apex_Classes__c },
        { key: "triggers", label: "Apex triggers", value: d.Apex_Triggers__c },
        {
          key: "lwc",
          label: "Lightning web components",
          value: d.Lightning_Components__c
        },
        { key: "objects", label: "Custom objects", value: d.Custom_Objects__c }
      ]
    };
  }

  get history() {
    return (this.stats?.deployments || []).map((d) => ({
      key: d.Name + d.Deployed_At__c,
      sha: d.Name,
      message: d.Commit_Message__c,
      url: d.Commit_URL__c,
      coverage: `${d.Code_Coverage__c}%`,
      when: timeAgo(d.Deployed_At__c)
    }));
  }

  get usage() {
    const s = this.stats || {};
    return [
      { key: "views", label: "Visits", value: s.pageViews ?? 0 },
      {
        key: "sessions",
        label: "Atlas conversations",
        value: s.atlasSessions ?? 0
      },
      { key: "messages", label: "Atlas messages", value: s.atlasMessages ?? 0 },
      { key: "demos", label: "Live demo runs", value: s.demoRuns ?? 0 }
    ];
  }

  get testsClass() {
    return `px-status ${this.latest?.allPassing ? "px-good" : "px-bad"}`;
  }
}
