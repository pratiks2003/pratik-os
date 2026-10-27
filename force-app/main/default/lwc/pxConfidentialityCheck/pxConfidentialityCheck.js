import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import reviewConfidentiality from "@salesforce/apex/ProjectAssistantController.reviewConfidentiality";

/** Quick action: hashed blocked-term check plus an AI confidentiality review. */
export default class PxConfidentialityCheck extends LightningElement {
  _recordId;
  result;
  error;
  loading = false;

  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    const first = !this._recordId && value;
    this._recordId = value;
    if (first) {
      this.review();
    }
  }

  async review() {
    this.loading = true;
    this.error = undefined;
    try {
      this.result = await reviewConfidentiality({ projectId: this._recordId });
    } catch (e) {
      this.error = e?.body?.message || "The review could not run.";
    } finally {
      this.loading = false;
    }
  }

  get blockedTerms() {
    return (this.result?.blockedTerms || []).join(", ");
  }

  get hasBlockedTerms() {
    return (this.result?.blockedTerms || []).length > 0;
  }

  get findings() {
    return (this.result?.findings || []).map((f, i) => ({
      key: `f${i}`,
      ...f
    }));
  }

  get hasFindings() {
    return this.findings.length > 0;
  }

  get isClear() {
    return this.result && !this.hasBlockedTerms && !this.hasFindings;
  }

  handleRerun() {
    this.review();
  }

  handleClose() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}
