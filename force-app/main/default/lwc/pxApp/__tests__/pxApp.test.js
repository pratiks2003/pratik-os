import { createElement } from "lwc";
import PxApp from "c/pxApp";
import getSiteData from "@salesforce/apex/PortfolioController.getSiteData";

const SITE_DATA = require("./data/siteData.json");

jest.mock(
  "@salesforce/apex/PortfolioController.getSiteData",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

function flush() {
  return Promise.resolve().then(() => Promise.resolve());
}

describe("c-px-app", () => {
  beforeEach(() => {
    window.matchMedia = jest.fn().mockReturnValue({ matches: true });
    window.IntersectionObserver = undefined;
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function render() {
    const element = createElement("c-px-app", { is: PxApp });
    document.body.appendChild(element);
    return element;
  }

  it("shows a loading status before data arrives", () => {
    const element = render();
    expect(element.shadowRoot.querySelector('[role="status"]')).not.toBeNull();
  });

  it("shows a friendly error when Apex fails", async () => {
    const element = render();
    getSiteData.error();
    await flush();
    expect(
      element.shadowRoot.querySelector('[role="alert"]').textContent
    ).toContain("unavailable");
  });

  it("renders every section from live data", async () => {
    const element = render();
    getSiteData.emit(SITE_DATA);
    await flush();
    const root = element.shadowRoot;
    [
      "about",
      "experience",
      "projects",
      "skills",
      "certifications",
      "contact"
    ].forEach((section) => {
      expect(root.querySelector(`[data-section="${section}"]`)).not.toBeNull();
    });
    const hero = root.querySelector("c-px-hero");
    expect(hero.shadowRoot.querySelector("h1").textContent).toBe("Ada Example");
    const terminal = hero.shadowRoot.querySelector('[role="log"]').textContent;
    expect(terminal).toContain("Loaded 2 projects · 3 skills");
    const timeline = root.querySelector("c-px-timeline").shadowRoot;
    expect(timeline.textContent).toContain("HEAD → main");
    expect(timeline.textContent).toContain("Feb 2024 — present");
  });

  it("switches to engineer mode from the nav", async () => {
    const element = render();
    getSiteData.emit(SITE_DATA);
    await flush();
    const nav = element.shadowRoot.querySelector("c-px-nav");
    nav.shadowRoot.querySelector('[data-mode="engineer"]').click();
    await flush();
    expect(element.shadowRoot.querySelector("c-px-projects").mode).toBe(
      "engineer"
    );
    expect(
      nav.shadowRoot
        .querySelector('[data-mode="engineer"]')
        .getAttribute("aria-pressed")
    ).toBe("true");
  });
});
