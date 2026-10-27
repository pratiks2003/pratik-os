import { createElement } from "lwc";
import PxAtlas from "c/pxAtlas";
import getConfig from "@salesforce/apex/AtlasChatController.getConfig";
import sendMessage from "@salesforce/apex/AtlasChatController.sendMessage";

const { projects } = require("../../pxApp/__tests__/data/siteData.json");

jest.mock(
  "@salesforce/apex/AtlasChatController.getConfig",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/AtlasChatController.sendMessage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function flush() {
  // Lets the mocked Apex promise and re-render settle.
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-px-atlas", () => {
  beforeEach(() => {
    window.sessionStorage.clear();
    sendMessage.mockReset();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function render() {
    const element = createElement("c-px-atlas", { is: PxAtlas });
    element.projects = projects;
    document.body.appendChild(element);
    return element;
  }

  async function ask(element, text) {
    const input = element.shadowRoot.querySelector("textarea");
    input.value = text;
    input.dispatchEvent(new CustomEvent("input"));
    await flush();
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await flush();
  }

  it("greets the visitor and offers suggestions", () => {
    const element = render();
    expect(element.shadowRoot.querySelector(".log").textContent).toContain(
      "I'm Atlas"
    );
    expect(element.shadowRoot.querySelectorAll(".chip").length).toBeGreaterThan(
      3
    );
  });

  it("turns project titles into links and keeps bold text", async () => {
    sendMessage.mockResolvedValue({
      status: "ok",
      sessionId: "S1",
      reply: "**Fit: 8/10**\nSee Event Engine for the pattern."
    });
    const element = render();
    const opened = jest.fn();
    element.addEventListener("openproject", opened);

    await ask(element, "What uses events?");

    expect(sendMessage).toHaveBeenCalledWith({
      message: "What uses events?",
      sessionId: undefined
    });
    expect(element.shadowRoot.querySelector("textarea").value).toBe("");
    expect(element.shadowRoot.querySelector("strong").textContent).toBe(
      "Fit: 8/10"
    );
    const link = element.shadowRoot.querySelector(".project-link");
    expect(link.textContent).toContain("Event Engine");
    link.click();
    expect(opened.mock.calls[0][0].detail).toEqual({ slug: "event-engine" });
  });

  it("reuses the session and remembers the conversation", async () => {
    sendMessage.mockResolvedValue({
      status: "ok",
      sessionId: "S1",
      reply: "One"
    });
    const element = render();
    await ask(element, "first");
    await ask(element, "second");

    expect(sendMessage.mock.calls[1][0].sessionId).toBe("S1");
    const saved = JSON.parse(window.sessionStorage.getItem("pxAtlas"));
    expect(saved.sentCount).toBe(2);
    expect(saved.history.map((m) => m.text)).toEqual([
      "first",
      "One",
      "second",
      "One"
    ]);
  });

  it("locks the composer when the daily limit is reached", async () => {
    sendMessage.mockResolvedValue({
      status: "limit",
      reply: "Atlas has answered all the questions it can for today."
    });
    const element = render();
    await ask(element, "hi");

    expect(element.shadowRoot.querySelector(".badge.notice")).not.toBeNull();
    expect(element.shadowRoot.querySelector("textarea").disabled).toBe(true);
  });

  it("wraps pasted job descriptions and shows a short label", async () => {
    sendMessage.mockResolvedValue({
      status: "ok",
      sessionId: "S1",
      reply: "Strong match"
    });
    const element = render();
    element.shadowRoot.querySelector('[data-key="jd"]').click();
    await flush();
    expect(element.shadowRoot.querySelector("textarea").rows).toBe(6);

    await ask(element, "Senior Salesforce Developer, Apex, LWC");

    expect(sendMessage.mock.calls[0][0].message).toMatch(
      /^Here is a job description/
    );
    expect(element.shadowRoot.querySelector(".user").textContent).toContain(
      "job description pasted"
    );
  });

  it("applies the per-chat message cap from config", async () => {
    sendMessage.mockResolvedValue({
      status: "ok",
      sessionId: "S1",
      reply: "ok"
    });
    const element = render();
    getConfig.emit({
      enabled: true,
      maxMessagesPerSession: 1,
      maxMessageLength: 100
    });
    await flush();
    await ask(element, "one");

    expect(element.shadowRoot.querySelector("textarea").disabled).toBe(true);
    expect(element.shadowRoot.querySelector("textarea").placeholder).toContain(
      "limit"
    );
  });

  it("shows a notice when Apex cannot be reached", async () => {
    sendMessage.mockRejectedValue(new Error("network"));
    const element = render();
    await ask(element, "hi");
    expect(element.shadowRoot.querySelector(".log").textContent).toContain(
      "could not be reached"
    );
  });
});
