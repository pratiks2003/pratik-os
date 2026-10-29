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

/** Ranks nodes into layers (longest path) and marks back edges in cycles. */
function rankDiagram(graph) {
  const { nodes, edges } = graph;
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

  // Pull entry points (no incoming edges) down to just above their nearest
  // target, so a button or scheduler that feeds a deep node sits beside it
  // instead of drawing a long line from the top row.
  const hasIncoming = new Set();
  edges.forEach((e, index) => {
    if (!backEdges.has(index) && e.from !== e.to) {
      hasIncoming.add(e.to);
    }
  });
  nodes.forEach((n) => {
    if (hasIncoming.has(n.id)) {
      return;
    }
    const targets = edges
      .filter(
        (e, index) => e.from === n.id && !backEdges.has(index) && e.to !== n.id
      )
      .map((e) => layer.get(e.to));
    if (targets.length) {
      layer.set(n.id, Math.max(0, Math.min(...targets) - 1));
    }
  });
  return { backEdges, layer };
}

/**
 * Left-to-right layered layout. Each node sits one column right of its
 * deepest predecessor; feedback edges are routed underneath.
 */
function layoutLeftToRight(graph, { backEdges, layer }) {
  const { nodes, edges } = graph;
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

/** Point at t on a cubic Bezier given as [x, y] control points. */
function bezierPoint(p0, p1, p2, p3, t) {
  const u = 1 - t;
  const a = u * u * u;
  const b = 3 * u * u * t;
  const c = 3 * u * t * t;
  const d = t * t * t;
  return [
    a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]
  ];
}

/**
 * Top-to-bottom layered layout for long flows. Each layer is a centred row;
 * nodes are ordered by the average position of their predecessors to reduce
 * crossings. Edges that skip rows get an invisible waypoint in every row they
 * cross, so they run between nodes rather than through them. Feedback edges
 * and self-loops curve around the right side.
 */
function layoutTopToBottom(graph, { backEdges, layer }) {
  const { nodes, edges } = graph;
  const gapX = 28;
  const gapY = 72;
  const waypointWidth = 14;
  const widthOf = (item) => {
    return item.waypoint
      ? waypointWidth
      : item.label.length * DIAGRAM.charWidth + DIAGRAM.nodePadding;
  };
  const isFeedback = (e, index) =>
    backEdges.has(index) || layer.get(e.to) <= layer.get(e.from);

  const rows = [];
  const addToRow = (item, r) => (rows[r] = rows[r] || []).push(item);
  nodes.forEach((n) => addToRow(n, layer.get(n.id)));

  const predecessors = new Map(nodes.map((n) => [n.id, []]));
  const waypoints = new Map();
  const outDegree = new Map();
  const inDegree = new Map();
  edges.forEach((e, index) => {
    if (isFeedback(e, index)) {
      return;
    }
    outDegree.set(e.from, (outDegree.get(e.from) || 0) + 1);
    inDegree.set(e.to, (inDegree.get(e.to) || 0) + 1);
    let previous = e.from;
    const chain = [];
    for (let r = layer.get(e.from) + 1; r < layer.get(e.to); r++) {
      const id = `~${index}~${r}`;
      addToRow({ id, waypoint: true }, r);
      predecessors.set(id, [previous]);
      chain.push(id);
      previous = id;
    }
    waypoints.set(index, chain);
    predecessors.get(e.to).push(previous);
  });

  const rowWidth = (row) =>
    row.reduce((sum, item) => sum + widthOf(item), 0) + gapX * (row.length - 1);
  const maxRowWidth = Math.max(...rows.map(rowWidth));

  const placed = new Map();
  rows.forEach((row, r) => {
    const centre = (item) => {
      const known = predecessors.get(item.id).filter((id) => placed.has(id));
      return known.length
        ? known.reduce(
            (sum, id) => sum + placed.get(id).x + placed.get(id).w / 2,
            0
          ) / known.length
        : Number.MAX_SAFE_INTEGER;
    };
    if (r > 0) {
      row.sort((a, b) => centre(a) - centre(b));
    }
    let x = DIAGRAM.margin + (maxRowWidth - rowWidth(row)) / 2;
    row.forEach((item) => {
      const w = widthOf(item);
      placed.set(item.id, {
        ...item,
        x,
        y: DIAGRAM.margin + r * (DIAGRAM.nodeHeight + gapY),
        w,
        h: DIAGRAM.nodeHeight
      });
      x += w + gapX;
    });
  });

  const loopX = DIAGRAM.margin + maxRowWidth + 48;
  let feedbackCount = 0;
  const routedEdges = edges.map((e, index) => {
    const a = placed.get(e.from);
    const b = placed.get(e.to);
    let path;
    let arrow;
    let labelX;
    let labelY;
    const feedback = isFeedback(e, index);
    if (feedback) {
      const rx = loopX + 18 * feedbackCount++;
      const sx = a.x + a.w;
      const tx = b.x + b.w;
      const sy = a.y + a.h / 2 - (a === b ? 8 : 0);
      const ty = b.y + b.h / 2 + (a === b ? 8 : 0);
      path = `M ${sx} ${sy} C ${rx} ${sy}, ${rx} ${ty}, ${tx + 8} ${ty}`;
      arrow = `M ${tx} ${ty} L ${tx + 8} ${ty - 4.5} L ${tx + 8} ${ty + 4.5} Z`;
      labelX = rx;
      labelY = (sy + ty) / 2 + 4;
    } else {
      const tx = b.x + b.w / 2;
      const ty = b.y;
      // Ports: leave the source, pass straight through each waypoint, enter the target.
      const points = [[a.x + a.w / 2, a.y + a.h]];
      waypoints.get(index).forEach((id) => {
        const v = placed.get(id);
        points.push([v.x + v.w / 2, v.y], [v.x + v.w / 2, v.y + v.h]);
      });
      points.push([tx, ty - 8]);
      const segments = [];
      path = `M ${points[0][0]} ${points[0][1]}`;
      for (let i = 1; i < points.length; i++) {
        const [px, py] = points[i - 1];
        const [qx, qy] = points[i];
        if (i % 2 === 1) {
          const mid = (py + qy) / 2;
          segments.push([
            [px, py],
            [px, mid],
            [qx, mid],
            [qx, qy]
          ]);
          path += ` C ${px} ${mid}, ${qx} ${mid}, ${qx} ${qy}`;
        } else {
          path += ` L ${qx} ${qy}`;
        }
      }
      arrow = `M ${tx} ${ty} L ${tx - 4.5} ${ty - 8} L ${tx + 4.5} ${ty - 8} Z`;
      // Put each label where its edges spread out: near the targets of a
      // fan-out, near the sources of a fan-in, so labels do not pile up.
      const fanOut =
        (outDegree.get(e.from) || 0) > 1 &&
        (outDegree.get(e.from) || 0) >= (inDegree.get(e.to) || 0);
      const fanIn = (inDegree.get(e.to) || 0) > 1;
      const segment = fanOut ? segments[segments.length - 1] : segments[0];
      const t = fanOut ? 0.72 : fanIn ? 0.28 : 0.5;
      [labelX, labelY] = bezierPoint(...segment, t);
      labelY += 4;
    }
    return {
      key: `e${index}`,
      path,
      arrow,
      label: e.label,
      labelX,
      labelY,
      feedback
    };
  });

  return {
    direction: "TB",
    width:
      DIAGRAM.margin * 2 +
      maxRowWidth +
      (feedbackCount ? 150 + 18 * feedbackCount : 0),
    height:
      DIAGRAM.margin * 2 +
      rows.length * DIAGRAM.nodeHeight +
      (rows.length - 1) * gapY,
    nodes: [...placed.values()]
      .filter((n) => !n.waypoint)
      .map((n) => ({
        ...n,
        key: n.id,
        textX: n.x + n.w / 2,
        textY: n.y + n.h / 2 + 4
      })),
    edges: routedEdges
  };
}

/**
 * Lays out an architecture diagram, choosing left-to-right for short flows
 * and top-to-bottom for long ones: whichever shows more legibly at the given
 * display width.
 */
export function layoutDiagram(graph, displayWidth = 856) {
  if (!graph.nodes.length) {
    return { direction: "LR", width: 0, height: 0, nodes: [], edges: [] };
  }
  const ranks = rankDiagram(graph);
  const leftToRight = { direction: "LR", ...layoutLeftToRight(graph, ranks) };
  const topToBottom = layoutTopToBottom(graph, ranks);
  const fit = (layout) => Math.min(1, displayWidth / layout.width);
  return fit(topToBottom) > fit(leftToRight) + 0.05 ? topToBottom : leftToRight;
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
