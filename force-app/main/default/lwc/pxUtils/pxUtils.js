/**
 * Shared, framework-free helpers for the pratik.os site: text blocks, the
 * architecture diagram parser/layout, the skill map layout and the palette.
 * Everything here is pure, so it is unit tested without rendering.
 */

/** Skill categories in fixed palette order (validated for a dark surface). */
export const SKILL_CATEGORIES = [
  { name: "Apex", color: "#3987e5" },
  { name: "LWC", color: "#d95926" },
  { name: "Integration", color: "#199e70" },
  { name: "Automation", color: "#c98500" },
  { name: "Architecture", color: "#d55181" },
  { name: "DevOps", color: "#008300" },
  { name: "AI", color: "#9085e9" },
  { name: "Platform", color: "#e66767" }
];

const CATEGORY_COLOR = Object.fromEntries(
  SKILL_CATEGORIES.map((c) => [c.name, c.color])
);

export function categoryColor(category) {
  return CATEGORY_COLOR[category] || CATEGORY_COLOR.Platform;
}

export function prefersReducedMotion() {
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

/** Deterministic 7-character hex "commit hash" for a record id. */
export function shortHash(value) {
  let hash = 0x811c9dc5;
  const text = String(value ?? "");
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, "0").slice(0, 7);
}

const MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
];

/** "2024-02-01" -> "Feb 2024". Parsed as text to avoid timezone shifts. */
export function formatMonth(isoDate) {
  if (!isoDate) {
    return "";
  }
  const [year, month] = String(isoDate).split("-");
  return `${MONTHS[Number(month) - 1]} ${year}`;
}

/**
 * Splits plain text into paragraphs and bullet lists. Lines starting with
 * "- " become list items; blank lines separate paragraphs. Rendered with
 * templates (never innerHTML), so record text cannot inject markup.
 */
export function toBlocks(text) {
  const blocks = [];
  let list = null;
  let paragraph = [];
  const flushParagraph = () => {
    if (paragraph.length) {
      blocks.push({
        key: `p${blocks.length}`,
        isList: false,
        text: paragraph.join(" ")
      });
      paragraph = [];
    }
  };
  String(text ?? "")
    .split(/\r?\n/)
    .forEach((rawLine) => {
      const line = rawLine.trim();
      if (line.startsWith("- ")) {
        flushParagraph();
        if (!list) {
          list = { key: `l${blocks.length}`, isList: true, items: [] };
          blocks.push(list);
        }
        list.items.push({ key: `i${list.items.length}`, text: line.slice(2) });
      } else if (line === "") {
        flushParagraph();
        list = null;
      } else {
        list = null;
        paragraph.push(line);
      }
    });
  flushParagraph();
  return blocks;
}

/** Parses "Source -> Target : label" lines into nodes and edges. */
export function parseDiagram(dsl) {
  const nodes = new Map();
  const edges = [];
  const addNode = (label) => {
    const id = label.toLowerCase();
    if (!nodes.has(id)) {
      nodes.set(id, { id, label });
    }
    return id;
  };
  String(dsl ?? "")
    .split(/\r?\n/)
    .forEach((rawLine) => {
      const match = rawLine.match(/^\s*(.+?)\s*->\s*(.+?)\s*(?::\s*(.*))?$/);
      if (match) {
        const from = addNode(match[1]);
        const to = addNode(match[2]);
        edges.push({ from, to, label: (match[3] || "").trim() });
      }
    });
  return { nodes: [...nodes.values()], edges };
}

const DIAGRAM = {
  charWidth: 7.4,
  labelCharWidth: 6.4,
  nodePadding: 28,
  nodeHeight: 40,
  columnGap: 96,
  rowGap: 40,
  margin: 16
};

/**
 * Left-to-right layered layout. Each node sits one column right of its
 * deepest predecessor (longest path); edges that would point backwards are
 * treated as feedback and routed underneath.
 */
export function layoutDiagram(graph) {
  const { nodes, edges } = graph;
  if (!nodes.length) {
    return { width: 0, height: 0, nodes: [], edges: [] };
  }
  const outgoing = new Map(nodes.map((n) => [n.id, []]));
  edges.forEach((e, index) => outgoing.get(e.from).push({ ...e, index }));

  // Depth-first search marks back edges so the remaining graph is acyclic.
  const state = new Map();
  const backEdges = new Set();
  const visit = (id) => {
    state.set(id, "active");
    outgoing.get(id).forEach((edge) => {
      if (state.get(edge.to) === "active") {
        backEdges.add(edge.index);
      } else if (!state.has(edge.to)) {
        visit(edge.to);
      }
    });
    state.set(id, "done");
  };
  nodes.forEach((n) => !state.has(n.id) && visit(n.id));

  const layer = new Map(nodes.map((n) => [n.id, 0]));
  for (let pass = 0; pass < nodes.length; pass++) {
    let changed = false;
    edges.forEach((e, index) => {
      if (!backEdges.has(index) && layer.get(e.to) < layer.get(e.from) + 1) {
        layer.set(e.to, layer.get(e.from) + 1);
        changed = true;
      }
    });
    if (!changed) {
      break;
    }
  }

  const columns = [];
  nodes.forEach((n) => {
    const column = layer.get(n.id);
    (columns[column] = columns[column] || []).push(n);
  });

  // Leave room for the longest edge label between columns.
  const longestLabel = Math.max(0, ...edges.map((e) => (e.label || "").length));
  const columnGap = Math.max(
    DIAGRAM.columnGap,
    Math.ceil(longestLabel * DIAGRAM.labelCharWidth + 32)
  );

  const placed = new Map();
  let x = DIAGRAM.margin;
  let maxRows = 0;
  columns.forEach((column) => {
    const width = Math.max(
      ...column.map(
        (n) => n.label.length * DIAGRAM.charWidth + DIAGRAM.nodePadding
      )
    );
    column.forEach((n, row) => {
      placed.set(n.id, {
        ...n,
        x,
        y: DIAGRAM.margin + row * (DIAGRAM.nodeHeight + DIAGRAM.rowGap),
        w: width,
        h: DIAGRAM.nodeHeight
      });
    });
    maxRows = Math.max(maxRows, column.length);
    x += width + columnGap;
  });

  const contentHeight =
    DIAGRAM.margin * 2 +
    maxRows * DIAGRAM.nodeHeight +
    (maxRows - 1) * DIAGRAM.rowGap;
  const routedEdges = edges.map((e, index) => {
    const a = placed.get(e.from);
    const b = placed.get(e.to);
    let path;
    let arrow;
    let labelX;
    let labelY;
    if (backEdges.has(index) || layer.get(e.to) <= layer.get(e.from)) {
      const sx = a.x + a.w / 2;
      const tx = b.x + b.w / 2;
      const bottom = contentHeight + 8;
      const ty = b.y + b.h;
      path = `M ${sx} ${a.y + a.h} C ${sx} ${bottom}, ${tx} ${bottom}, ${tx} ${ty + 8}`;
      arrow = `M ${tx} ${ty} L ${tx - 4.5} ${ty + 8} L ${tx + 4.5} ${ty + 8} Z`;
      labelX = (sx + tx) / 2;
      labelY = bottom - 4;
    } else {
      const sx = a.x + a.w;
      const sy = a.y + a.h / 2;
      const tx = b.x;
      const ty = b.y + b.h / 2;
      const mid = (sx + tx) / 2;
      path = `M ${sx} ${sy} C ${mid} ${sy}, ${mid} ${ty}, ${tx - 8} ${ty}`;
      arrow = `M ${tx} ${ty} L ${tx - 8} ${ty - 4.5} L ${tx - 8} ${ty + 4.5} Z`;
      labelX = mid;
      labelY = (sy + ty) / 2 - 6;
    }
    return {
      key: `e${index}`,
      path,
      arrow,
      label: e.label,
      labelX,
      labelY,
      feedback: backEdges.has(index)
    };
  });

  return {
    width: x - columnGap + DIAGRAM.margin,
    height: contentHeight + (backEdges.size ? 32 : 0),
    nodes: [...placed.values()].map((n) => ({
      ...n,
      key: n.id,
      textX: n.x + n.w / 2,
      textY: n.y + n.h / 2 + 4
    })),
    edges: routedEdges
  };
}

const MAP = {
  size: 960,
  projectRadius: 120,
  bandRadius: 262,
  skillRadius: 290,
  minNode: 4,
  maxNode: 11,
  labelChars: 26,
  gap: 0.035
};

/**
 * Radial skill map. Projects sit on an inner ring; skills sit on an outer
 * ring grouped into category sectors in fixed palette order, so only
 * neighbouring categories are ever adjacent. Node area tracks evidence.
 */
export function layoutSkillMap(skills, projects) {
  const center = MAP.size / 2;
  const polar = (radius, angle) => ({
    x: center + radius * Math.cos(angle),
    y: center + radius * Math.sin(angle)
  });

  const projectNodes = projects.map((p, i) => {
    const angle =
      -Math.PI / 2 + (i / Math.max(projects.length, 1)) * 2 * Math.PI;
    return {
      key: p.slug,
      slug: p.slug,
      title: p.title,
      code: String(i + 1).padStart(2, "0"),
      angle,
      ...polar(MAP.projectRadius, angle)
    };
  });
  const projectBySlug = new Map(projectNodes.map((p) => [p.slug, p]));

  const groups = SKILL_CATEGORIES.map((category) => ({
    ...category,
    skills: skills
      .filter((s) => (s.category || "Platform") === category.name)
      .sort(
        (a, b) =>
          b.evidenceCount - a.evidenceCount || a.name.localeCompare(b.name)
      )
  })).filter((g) => g.skills.length);

  const total = groups.reduce((sum, g) => sum + g.skills.length, 0);
  const usable = 2 * Math.PI - MAP.gap * groups.length;
  const maxEvidence = Math.max(1, ...skills.map((s) => s.evidenceCount));
  const radiusFor = (evidence) =>
    MAP.minNode +
    (MAP.maxNode - MAP.minNode) *
      Math.sqrt((evidence - 1) / Math.max(maxEvidence - 1, 1));

  let angle = -Math.PI / 2;
  const sectors = [];
  const skillNodes = [];
  const links = [];
  groups.forEach((group) => {
    const span = (group.skills.length / total) * usable;
    const start = angle;
    const step = span / group.skills.length;
    group.skills.forEach((skill, i) => {
      const a = start + step * (i + 0.5);
      const point = polar(MAP.skillRadius, a);
      const onLeft = Math.cos(a) < 0;
      const degrees = (a * 180) / Math.PI + (onLeft ? 180 : 0);
      const labelPoint = polar(MAP.skillRadius + 16, a);
      const name =
        skill.name.length > MAP.labelChars
          ? `${skill.name.slice(0, MAP.labelChars - 1)}…`
          : skill.name;
      skillNodes.push({
        key: skill.id || skill.name,
        name: skill.name,
        label: name,
        category: group.name,
        color: group.color,
        evidenceCount: skill.evidenceCount,
        projectSlugs: skill.projectSlugs || [],
        r: radiusFor(skill.evidenceCount),
        hitR: 13,
        ...point,
        labelX: labelPoint.x,
        labelY: labelPoint.y,
        anchor: onLeft ? "end" : "start",
        labelTransform: `rotate(${degrees.toFixed(2)} ${labelPoint.x.toFixed(2)} ${labelPoint.y.toFixed(2)})`
      });
      (skill.projectSlugs || []).forEach((slug) => {
        const project = projectBySlug.get(slug);
        if (project) {
          const control = polar(
            MAP.projectRadius * 0.6,
            (a + project.angle) / 2
          );
          links.push({
            key: `${skill.id || skill.name}:${slug}`,
            skill: skill.name,
            slug,
            color: group.color,
            path: `M ${point.x.toFixed(1)} ${point.y.toFixed(1)} Q ${control.x.toFixed(1)} ${control.y.toFixed(1)} ${project.x.toFixed(1)} ${project.y.toFixed(1)}`
          });
        }
      });
    });
    const end = start + span;
    const bandStart = polar(MAP.bandRadius, start + step * 0.15);
    const bandEnd = polar(MAP.bandRadius, end - step * 0.15);
    const mid = (start + end) / 2;
    const labelPoint = polar(MAP.bandRadius - 26, mid);
    sectors.push({
      key: group.name,
      name: group.name,
      color: group.color,
      count: group.skills.length,
      path: `M ${bandStart.x.toFixed(1)} ${bandStart.y.toFixed(1)} A ${MAP.bandRadius} ${MAP.bandRadius} 0 ${span > Math.PI ? 1 : 0} 1 ${bandEnd.x.toFixed(1)} ${bandEnd.y.toFixed(1)}`,
      labelX: labelPoint.x,
      labelY: labelPoint.y + 4
    });
    angle = end + MAP.gap;
  });

  return {
    size: MAP.size,
    center,
    projects: projectNodes,
    skills: skillNodes,
    sectors,
    links
  };
}
