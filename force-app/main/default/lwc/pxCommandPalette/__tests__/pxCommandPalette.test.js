import { createElement } from "lwc";
import PxCommandPalette, { fuzzyScore } from "c/pxCommandPalette";
import PxContactForm from "c/pxContactForm";
import PxBehindScenes from "c/pxBehindScenes";
import submitContactForm from "@salesforce/apex/SiteController.submitContactForm";
import getStats from "@salesforce/apex/SiteController.getStats";

const {
  projects,
  profile
} = require("../../pxApp/__tests__/data/siteData.json");

jest.mock(
  "@salesforce/apex/SiteController.submitContactForm",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/SiteController.getStats",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

function flush() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

afterEach(() => {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
  jest.clearAllMocks();
});

async function openPalette() {
  const element = createElement("c-px-command-palette", {
    is: PxCommandPalette
  });
  element.projects = projects;
  element.profile = profile;
  element.skillCount = 3;
  document.body.appendChild(element);
  element.open();
  await flush();
  return element;
}

async function type(element, text) {
  const input = element.shadowRoot.querySelector("input");
  input.value = text;
  input.dispatchEvent(new CustomEvent("input"));
  await flush();
  return input;
}

describe("fuzzyScore", () => {
  it("prefers substrings and rejects non-matches", () => {
    expect(fuzzyScore("proj", "cd ~/projects")).toBeGreaterThan(
      fuzzyScore("pjs", "cd ~/projects")
    );
    expect(fuzzyScore("xyz", "help")).toBe(-1);
    expect(fuzzyScore("", "help")).toBe(0);
  });
});

describe("c-px-command-palette", () => {
  it("emits a command for the selected result", async () => {
    const element = await openPalette();
    const handler = jest.fn();
    element.addEventListener("command", handler);
    const input = await type(element, "cat event");
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await flush();
    expect(handler.mock.calls[0][0].detail).toEqual({
      action: "openProject",
      value: "event-engine"
    });
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
  });

  it("falls back to asking Atlas and supports arrow keys", async () => {
    const element = await openPalette();
    const handler = jest.fn();
    element.addEventListener("command", handler);
    const input = await type(element, "ask does he know LWC");
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await flush();
    expect(handler.mock.calls[0][0].detail).toEqual({
      action: "ask",
      value: "does he know LWC"
    });
  });

  it("prints output for whoami and easter eggs", async () => {
    const element = await openPalette();
    let input = await type(element, "whoami");
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await flush();
    expect(element.shadowRoot.querySelector(".output").textContent).toContain(
      "Ada Example"
    );

    input = await type(element, "rm -rf /");
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await flush();
    expect(element.shadowRoot.querySelector(".output").textContent).toContain(
      "governor limits"
    );
  });

  it("moves the selection and closes on Escape", async () => {
    const element = await openPalette();
    const input = element.shadowRoot.querySelector("input");
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown" }));
    await flush();
    expect(
      element.shadowRoot.querySelectorAll(".result")[1].className
    ).toContain("selected");
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    await flush();
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
  });
});

describe("c-px-contact-form", () => {
  it("submits the form with honeypot and timing data", async () => {
    submitContactForm.mockResolvedValue({
      status: "ok",
      message: "Thanks, Sam!"
    });
    const element = createElement("c-px-contact-form", { is: PxContactForm });
    document.body.appendChild(element);
    const root = element.shadowRoot;
    root.querySelector('[name="fullName"]').value = "Sam";
    root.querySelector('[name="email"]').value = "sam@example.com";
    root.querySelector('[name="message"]').value = "Hello";
    root.querySelector("form").dispatchEvent(new CustomEvent("submit"));
    await flush();
    const sent = JSON.parse(submitContactForm.mock.calls[0][0].formJson);
    expect(sent).toMatchObject({
      fullName: "Sam",
      email: "sam@example.com",
      message: "Hello",
      website: ""
    });
    expect(typeof sent.elapsedMs).toBe("number");
    expect(root.querySelector('[role="status"]').textContent).toContain(
      "Thanks, Sam!"
    );
  });

  it("keeps the form and shows validation messages", async () => {
    submitContactForm.mockResolvedValue({
      status: "invalid",
      message: "Please add your name."
    });
    const element = createElement("c-px-contact-form", { is: PxContactForm });
    document.body.appendChild(element);
    element.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await flush();
    expect(element.shadowRoot.querySelector("form")).not.toBeNull();
    expect(
      element.shadowRoot.querySelector('[role="alert"]').textContent
    ).toContain("Please add your name.");
  });
});

describe("c-px-behind-scenes", () => {
  it("renders the latest deploy and usage", async () => {
    const element = createElement("c-px-behind-scenes", { is: PxBehindScenes });
    document.body.appendChild(element);
    getStats.emit({
      pageViews: 12,
      atlasSessions: 3,
      atlasMessages: 9,
      demoRuns: 4,
      deployments: [
        {
          Name: "abc1234",
          Commit_Message__c: "Ship it",
          Commit_URL__c: "https://example.com/c",
          Deployed_At__c: new Date().toISOString(),
          Apex_Tests__c: 59,
          Apex_Tests_Passed__c: 59,
          Code_Coverage__c: 94,
          Apex_Classes__c: 58,
          Apex_Triggers__c: 6,
          Lightning_Components__c: 21,
          Custom_Objects__c: 17
        }
      ]
    });
    await flush();
    const text = element.shadowRoot.textContent;
    expect(text).toContain("abc1234");
    expect(text).toContain("59/59 Apex tests passing");
    expect(text).toContain("94%");
    expect(text).toContain("Atlas conversations");
  });
});
