import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import draftFromNotes from "@salesforce/apex/ProjectAssistantController.draftFromNotes";
import applyDraft from "@salesforce/apex/ProjectAssistantController.applyDraft";

const FIELDS = [
  { key: "tagline", label: "Tagline" },
  { key: "category", label: "Category" },
  { key: "businessImpact", label: "Business Impact (recruiter view)" },
  { key: "technicalDeepDive", label: "Technical Deep Dive (engineer view)" },
  { key: "starStory", label: "STAR Story" },
  { key: "techStack", label: "Tech Stack (skills are linked automatically)" },
  { key: "metrics", label: "Metrics" }
];

/** Quick action: turn rough notes into case-study fields with a prompt template. */
export default class PxDraftFromNotes extends LightningElement {
  @api recordId;

  notes = "";
  draft;
  loading = false;
  error;

  get hasDraft() {
    return Boolean(this.draft);
  }

  get fields() {
    return FIELDS.map((f) => ({ ...f, value: this.draft?.[f.key] || "—" }));
  }

  get blockedTerms() {
    return (this.draft?.blockedTerms || []).join(", ");
  }

  get hasBlockedTerms() {
    return (this.draft?.blockedTerms || []).length > 0;
  }

  get generateDisabled() {
    return this.loading || !this.notes.trim();
  }

  handleNotes(event) {
    this.notes = event.target.value;
  }

  async handleGenerate() {
    this.loading = true;
    this.error = undefined;
    try {
      this.draft = await draftFromNotes({
        projectId: this.recordId,
        notes: this.notes
      });
    } catch (e) {
      this.error = e?.body?.message || "The draft could not be generated.";
    } finally {
      this.loading = false;
    }
  }

  handleBack() {
    this.draft = undefined;
  }

  async handleApply() {
    this.loading = true;
    this.error = undefined;
    try {
      await applyDraft({
        projectId: this.recordId,
        draftJson: JSON.stringify(this.draft)
      });
      await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Draft applied",
          message: "Review it, then tick Published when it is ready.",
          variant: "success"
        })
      );
      this.dispatchEvent(new CloseActionScreenEvent());
    } catch (e) {
      this.error = e?.body?.message || "The draft could not be applied.";
    } finally {
      this.loading = false;
    }
  }

  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}
