import { createElement } from "lwc";
import PxProjects from "c/pxProjects";

const { projects } = require("../../pxApp/__tests__/data/siteData.json");

function flush() {
  return Promise.resolve().then(() => Promise.resolve());
}

describe("c-px-projects", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    window.history.replaceState(null, "", "/");
  });

  function render(mode = "recruiter") {
    const element = createElement("c-px-projects", { is: PxProjects });
    element.projects = projects;
    element.mode = mode;
    document.body.appendChild(element);
    return element;
  }

  it("renders a card per project and filters by category", async () => {
    const element = render();
    await flush();
    expect(element.shadowRoot.querySelectorAll(".card")).toHaveLength(2);
    element.shadowRoot.querySelector('[data-name="DevOps"]').click();
    await flush();
    const cards = element.shadowRoot.querySelectorAll(".card");
    expect(cards).toHaveLength(1);
    expect(cards[0].textContent).toContain("Pipeline");
  });

  it("opens a dialog with recruiter content, switches tabs and closes on Escape", async () => {
    const element = render();
    await flush();
    element.shadowRoot.querySelector('[data-slug="event-engine"]').click();
    await flush();
    const dialog = element.shadowRoot.querySelector('[role="dialog"]');
    expect(dialog.textContent).toContain("Event Engine");
    expect(dialog.querySelector("c-px-rich-text").text).toBe("Saved time.");
    expect(window.location.hash).toBe("#project/event-engine");

    element.shadowRoot.querySelector('[data-key="story"]').click();
    await flush();
    expect(
      element.shadowRoot.querySelector(".star-story").textContent
    ).toContain("Built it.");

    element.shadowRoot
      .querySelector(".backdrop")
      .dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    await flush();
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
    expect(window.location.hash).toBe("");
  });

  it("opens the engineer view with the diagram in engineer mode", async () => {
    const element = render("engineer");
    await flush();
    element.shadowRoot.querySelector('[data-slug="event-engine"]').click();
    await flush();
    expect(
      element.shadowRoot.querySelector("c-px-arch-diagram")
    ).not.toBeNull();
  });

  it("opens the project named in the URL hash", async () => {
    window.history.replaceState(null, "", "/#project/pipeline");
    const element = render();
    await flush();
    await flush();
    expect(
      element.shadowRoot.querySelector('[role="dialog"]').textContent
    ).toContain("Pipeline");
  });
});
