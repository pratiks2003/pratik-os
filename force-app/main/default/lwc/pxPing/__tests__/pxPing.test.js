import { createElement } from "lwc";
import PxPing from "c/pxPing";
import ping from "@salesforce/apex/PortfolioPingController.ping";

jest.mock(
  "@salesforce/apex/PortfolioPingController.ping",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

describe("c-px-ping", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function render() {
    const element = createElement("c-px-ping", { is: PxPing });
    document.body.appendChild(element);
    return element;
  }

  it("shows a booting message before data arrives", () => {
    const element = render();
    expect(element.shadowRoot.querySelector("p").textContent).toBe("… booting");
  });

  it("shows the connected user type when Apex responds", async () => {
    const element = render();
    ping.emit({ userType: "Guest", serverTime: "2026-10-27T00:00:00Z" });
    await Promise.resolve();
    expect(element.shadowRoot.querySelector("p").textContent).toContain(
      "Connected as Guest"
    );
  });

  it("shows the error message when Apex fails", async () => {
    const element = render();
    ping.error({ message: "Insufficient access" });
    await Promise.resolve();
    expect(element.shadowRoot.querySelector("p").textContent).toContain("✖");
  });
});
