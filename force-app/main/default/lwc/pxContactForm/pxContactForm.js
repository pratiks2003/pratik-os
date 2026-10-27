import { LightningElement } from "lwc";
import submitContactForm from "@salesforce/apex/SiteController.submitContactForm";

/** Contact form for visitors who would rather not chat. Bots are filtered server-side. */
export default class PxContactForm extends LightningElement {
  startedAt = Date.now();
  sending = false;
  sent = false;
  status;
  message;

  get statusClass() {
    return this.status === "ok" ? "notice ok" : "notice warn";
  }

  get hasMessage() {
    return Boolean(this.message);
  }

  async handleSubmit(event) {
    event.preventDefault();
    const field = (name) =>
      this.template.querySelector(`[name="${name}"]`)?.value?.trim() || "";
    this.sending = true;
    try {
      const result = await submitContactForm({
        formJson: JSON.stringify({
          fullName: field("fullName"),
          email: field("email"),
          company: field("company"),
          role: field("role"),
          message: field("message"),
          website: field("website"),
          elapsedMs: Date.now() - this.startedAt
        })
      });
      this.status = result.status;
      this.message = result.message;
      this.sent = result.status === "ok";
    } catch {
      this.status = "error";
      this.message =
        "Something went wrong. Please reach Pratik on LinkedIn instead.";
    } finally {
      this.sending = false;
    }
  }
}
