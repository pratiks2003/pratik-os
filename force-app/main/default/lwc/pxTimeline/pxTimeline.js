import { LightningElement, api } from "lwc";
import { formatMonth, shortHash } from "c/pxUtils";

/** Experience rendered as `git log`: newest commit first, HEAD on the current role. */
export default class PxTimeline extends LightningElement {
  @api experiences = [];
  @api projects = [];

  get commits() {
    return this.experiences.map((e, index) => {
      const projectCount = this.projects.filter(
        (p) => p.record.Experience__c === e.Id
      ).length;
      const start = formatMonth(e.Start_Date__c);
      const end = e.Is_Current__c ? "present" : formatMonth(e.End_Date__c);
      return {
        key: e.Id,
        hash: shortHash(e.Id),
        isHead: index === 0 && e.Is_Current__c,
        role: e.Name,
        company: e.Company__c,
        engagement: e.Engagement__c,
        dates: [start, end].filter(Boolean).join(" — "),
        summary: e.Summary__c,
        projectLabel: projectCount
          ? `${projectCount} project${projectCount === 1 ? "" : "s"}`
          : null
      };
    });
  }
}
