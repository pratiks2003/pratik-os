import { createElement } from "lwc";
import PxDraftFromNotes from "c/pxDraftFromNotes";
import PxConfidentialityCheck from "c/pxConfidentialityCheck";
import draftFromNotes from "@salesforce/apex/ProjectAssistantController.draftFromNotes";
import applyDraft from "@salesforce/apex/ProjectAssistantController.applyDraft";
import reviewConfidentiality from "@salesforce/apex/ProjectAssistantController.reviewConfidentiality";

jest.mock(
  "@salesforce/apex/ProjectAssistantController.draftFromNotes",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ProjectAssistantController.applyDraft",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ProjectAssistantController.reviewConfidentiality",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function flush() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function button(element, label) {
  return [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (b) => b.label === label
  );
}

afterEach(() => {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
  jest.clearAllMocks();
});

describe("c-px-draft-from-notes", () => {
  it("generates a draft, warns about blocked terms and applies it", async () => {
    draftFromNotes.mockResolvedValue({
      tagline: "Synced orders.",
      businessImpact: "Cut fixes.",
      blockedTerms: ["acmesys"]
    });
    applyDraft.mockResolvedValue();
    const element = createElement("c-px-draft-from-notes", {
      is: PxDraftFromNotes
    });
    element.recordId = "a07000000000001";
    document.body.appendChild(element);

    const textarea = element.shadowRoot.querySelector("lightning-textarea");
    textarea.value = "notes";
    textarea.dispatchEvent(new CustomEvent("change"));
    await flush();
    button(element, "Generate draft").click();
    await flush();

    expect(draftFromNotes).toHaveBeenCalledWith({
      projectId: "a07000000000001",
      notes: "notes"
    });
    expect(element.shadowRoot.textContent).toContain("Synced orders.");
    expect(
      element.shadowRoot.querySelector(".slds-alert_warning").textContent
    ).toContain("acmesys");

    button(element, "Apply to record").click();
    await flush();
    expect(JSON.parse(applyDraft.mock.calls[0][0].draftJson).tagline).toBe(
      "Synced orders."
    );
  });

  it("shows errors from Apex", async () => {
    draftFromNotes.mockRejectedValue({
      body: { message: "The AI response could not be read." }
    });
    const element = createElement("c-px-draft-from-notes", {
      is: PxDraftFromNotes
    });
    document.body.appendChild(element);
    const textarea = element.shadowRoot.querySelector("lightning-textarea");
    textarea.value = "x";
    textarea.dispatchEvent(new CustomEvent("change"));
    await flush();
    button(element, "Generate draft").click();
    await flush();
    expect(
      element.shadowRoot.querySelector(".slds-alert_error").textContent
    ).toContain("could not be read");
  });
});

describe("c-px-confidentiality-check", () => {
  it("runs the review when the record id arrives and lists findings", async () => {
    reviewConfidentiality.mockResolvedValue({
      verdict: "review",
      blockedTerms: ["acmesys"],
      findings: [
        {
          quote: "Zephyr",
          reason: "internal system",
          suggestion: "an external system"
        }
      ]
    });
    const element = createElement("c-px-confidentiality-check", {
      is: PxConfidentialityCheck
    });
    element.recordId = "a07000000000001";
    document.body.appendChild(element);
    await flush();

    expect(reviewConfidentiality).toHaveBeenCalledWith({
      projectId: "a07000000000001"
    });
    const text = element.shadowRoot.textContent;
    expect(text).toContain("Blocked terms: acmesys");
    expect(text).toContain('"Zephyr"');
  });

  it("reports a clean record", async () => {
    reviewConfidentiality.mockResolvedValue({
      verdict: "clear",
      blockedTerms: [],
      findings: []
    });
    const element = createElement("c-px-confidentiality-check", {
      is: PxConfidentialityCheck
    });
    element.recordId = "a07000000000002";
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain(
      "Nothing confidential found"
    );
  });
});
