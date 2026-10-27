import { LightningElement, api } from "lwc";
import { formatMonth } from "c/pxUtils";

export default class PxCerts extends LightningElement {
  @api certifications = [];
  @api profile = {};

  get cards() {
    return this.certifications.map((c) => ({
      key: c.Id,
      name: c.Name,
      issuer: c.Issuer__c,
      issued: c.Issued_Date__c
        ? `Issued ${formatMonth(c.Issued_Date__c)}`
        : null,
      url: c.Credential_URL__c || this.profile.Trailhead_URL__c
    }));
  }
}
