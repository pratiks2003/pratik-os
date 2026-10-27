import { createElement } from "lwc";
import PxSkillMap from "c/pxSkillMap";

const {
  skills,
  projects
} = require("../../pxApp/__tests__/data/siteData.json");

function flush() {
  return Promise.resolve().then(() => Promise.resolve());
}

describe("c-px-skill-map", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function render(narrow = false) {
    window.matchMedia = jest.fn().mockReturnValue({ matches: narrow });
    const element = createElement("c-px-skill-map", { is: PxSkillMap });
    element.skills = skills;
    element.projects = projects;
    document.body.appendChild(element);
    return element;
  }

  it("draws a labelled node per skill and a link per evidence", async () => {
    const element = render();
    await flush();
    const root = element.shadowRoot;
    expect(root.querySelectorAll(".skill")).toHaveLength(3);
    expect(root.querySelectorAll(".link")).toHaveLength(4);
    expect(
      root.querySelector('.skill[data-name="Apex"]').getAttribute("aria-label")
    ).toBe("Apex, Apex, used in 2 projects");
  });

  it("highlights a skill's projects on hover and focus", async () => {
    const element = render();
    await flush();
    element.shadowRoot
      .querySelector('.skill[data-name="GitHub Actions"]')
      .dispatchEvent(new CustomEvent("focus"));
    await flush();
    const root = element.shadowRoot;
    expect(root.querySelector(".center-title").textContent).toBe(
      "GitHub Actions"
    );
    expect(
      root.querySelector('[data-slug="event-engine"]').getAttribute("class")
    ).toContain("dim");
    expect(
      root.querySelector('[data-slug="pipeline"]').getAttribute("class")
    ).not.toContain("dim");
  });

  it("filters by category from the legend", async () => {
    const element = render();
    await flush();
    element.shadowRoot
      .querySelector('.legend [data-name="Integration"]')
      .click();
    await flush();
    const lit = [...element.shadowRoot.querySelectorAll(".skill")].filter(
      (g) => !g.getAttribute("class").includes("dim")
    );
    expect(lit.map((g) => g.dataset.name)).toEqual(["Platform Events"]);
  });

  it("defaults to the table view on narrow screens", async () => {
    const element = render(true);
    await flush();
    const rows = element.shadowRoot.querySelectorAll("tbody tr");
    expect(rows).toHaveLength(3);
    expect(element.shadowRoot.querySelector("svg")).toBeNull();
  });
});
