import {
  categoryColor,
  formatMonth,
  layoutDiagram,
  layoutSkillMap,
  parseDiagram,
  shortHash,
  toBlocks,
  SKILL_CATEGORIES
} from "c/pxUtils";

describe("toBlocks", () => {
  it("splits paragraphs and bullet lists", () => {
    const blocks = toBlocks(
      "Intro line\nsecond line\n\n- one\n- two\nAfter list"
    );
    expect(blocks.map((b) => (b.isList ? "list" : b.text))).toEqual([
      "Intro line second line",
      "list",
      "After list"
    ]);
    expect(blocks[1].items.map((i) => i.text)).toEqual(["one", "two"]);
  });

  it("treats markup as plain text", () => {
    expect(toBlocks("<b>hi</b>")[0].text).toBe("<b>hi</b>");
  });

  it("handles empty input", () => {
    expect(toBlocks(null)).toEqual([]);
  });
});

describe("parseDiagram and layoutDiagram", () => {
  it("parses edges with and without labels", () => {
    const graph = parseDiagram("A -> B : calls\nB -> C\nnot an edge");
    expect(graph.nodes.map((n) => n.label)).toEqual(["A", "B", "C"]);
    expect(graph.edges).toEqual([
      { from: "a", to: "b", label: "calls" },
      { from: "b", to: "c", label: "" }
    ]);
  });

  it("places each node right of its predecessor", () => {
    const layout = layoutDiagram(parseDiagram("A -> B\nB -> C\nA -> C"));
    const x = Object.fromEntries(layout.nodes.map((n) => [n.id, n.x]));
    expect(x.a).toBeLessThan(x.b);
    expect(x.b).toBeLessThan(x.c);
    expect(layout.edges.every((e) => e.path && e.arrow)).toBe(true);
  });

  it("routes cycles as feedback edges instead of looping forever", () => {
    const layout = layoutDiagram(parseDiagram("A -> B\nB -> A : retry"));
    expect(layout.edges.filter((e) => e.feedback)).toHaveLength(1);
    expect(layout.height).toBeGreaterThan(0);
  });

  it("widens columns to fit long edge labels", () => {
    const short = layoutDiagram(parseDiagram("A -> B : x"));
    const long = layoutDiagram(
      parseDiagram("A -> B : a much longer label here")
    );
    const gap = (layout) =>
      layout.nodes[1].x - (layout.nodes[0].x + layout.nodes[0].w);
    expect(gap(long)).toBeGreaterThan(gap(short));
    expect(gap(long)).toBeGreaterThanOrEqual(
      "a much longer label here".length * 6.4
    );
  });

  it("returns an empty layout for no diagram", () => {
    expect(layoutDiagram(parseDiagram("")).nodes).toEqual([]);
  });
});

describe("layoutSkillMap", () => {
  const skills = [
    {
      id: "1",
      name: "Apex",
      category: "Apex",
      evidenceCount: 3,
      projectSlugs: ["a", "b"]
    },
    {
      id: "2",
      name: "LWC",
      category: "LWC",
      evidenceCount: 1,
      projectSlugs: ["a"]
    },
    {
      id: "3",
      name: "Odd",
      category: undefined,
      evidenceCount: 1,
      projectSlugs: ["missing"]
    }
  ];
  const projects = [
    { slug: "a", title: "A" },
    { slug: "b", title: "B" }
  ];

  it("is deterministic", () => {
    expect(layoutSkillMap(skills, projects)).toEqual(
      layoutSkillMap(skills, projects)
    );
  });

  it("keeps sectors in palette order and sizes nodes by evidence", () => {
    const layout = layoutSkillMap(skills, projects);
    const order = SKILL_CATEGORIES.map((c) => c.name);
    const sectorOrder = layout.sectors.map((s) => order.indexOf(s.name));
    expect(sectorOrder).toEqual([...sectorOrder].sort((a, b) => a - b));
    const apex = layout.skills.find((s) => s.name === "Apex");
    const lwc = layout.skills.find((s) => s.name === "LWC");
    expect(apex.r).toBeGreaterThan(lwc.r);
    expect(layout.skills.find((s) => s.name === "Odd").category).toBe(
      "Platform"
    );
  });

  it("only links to known projects", () => {
    const layout = layoutSkillMap(skills, projects);
    expect(layout.links.map((l) => l.slug).sort()).toEqual(["a", "a", "b"]);
  });
});

describe("small helpers", () => {
  it("formats ISO dates without timezone drift", () => {
    expect(formatMonth("2024-02-01")).toBe("Feb 2024");
    expect(formatMonth(null)).toBe("");
  });

  it("produces stable 7-character hashes", () => {
    expect(shortHash("abc")).toMatch(/^[0-9a-f]{7}$/);
    expect(shortHash("abc")).toBe(shortHash("abc"));
    expect(shortHash("abc")).not.toBe(shortHash("abd"));
  });

  it("falls back to the Platform colour", () => {
    expect(categoryColor("Unknown")).toBe(categoryColor("Platform"));
  });
});
