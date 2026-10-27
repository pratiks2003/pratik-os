import { LightningElement, wire } from "lwc";
import ping from "@salesforce/apex/PortfolioPingController.ping";

export default class PxPing extends LightningElement {
  @wire(ping) result;

  get status() {
    if (this.result?.data) {
      return `✔ Connected as ${this.result.data.userType} · ${this.result.data.serverTime}`;
    }
    if (this.result?.error) {
      return `✖ ${this.result.error.body?.message ?? "Apex call failed"}`;
    }
    return "… booting";
  }
}
