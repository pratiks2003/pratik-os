import { LightningElement, api } from "lwc";
import { SKILL_CATEGORIES, layoutSkillMap } from "c/pxUtils";

const NARROW_QUERY = "(max-width: 720px)";

/**
 * Radial skill map. Category is encoded by position (labelled sectors in
 * fixed palette order) and reinforced by colour; every node is labelled.
 * Hover or keyboard focus highlights the projects that prove a skill. A list
 * view carries the same data and is the default on narrow screens.
 */
export default class PxSkillMap extends LightningElement {
  @api skills = [];
  @api projects = [];

  view = "map";
  activeSkill;
  activeProject;
  activeCategory;

  connectedCallback() {
    if (window.matchMedia?.(NARROW_QUERY).matches) {
      this.view = "list";
    }
  }

  get layout() {
    return layoutSkillMap(
      this.skills,
      this.projects.map((p) => ({
        slug: p.record.Slug__c,
        title: p.record.Name
      }))
    );
  }

  get isMap() {
    return this.view === "map";
  }

  get mapPressed() {
    return String(this.view === "map");
  }

  get listPressed() {
    return String(this.view === "list");
  }

  get viewBox() {
    return `0 0 ${this.layout.size} ${this.layout.size}`;
  }

  get focus() {
    const { skills, projects } = this.layout;
    if (this.activeSkill) {
      const skill = skills.find((s) => s.name === this.activeSkill);
      return {
        skills: new Set([skill.name]),
        projects: new Set(skill.projectSlugs)
      };
    }
    if (this.activeProject) {
      return {
        skills: new Set(
          skills
            .filter((s) => s.projectSlugs.includes(this.activeProject))
            .map((s) => s.name)
        ),
        projects: new Set([this.activeProject])
      };
    }
    if (this.activeCategory) {
      const inCategory = skills.filter(
        (s) => s.category === this.activeCategory
      );
      return {
        skills: new Set(inCategory.map((s) => s.name)),
        projects: new Set(inCategory.flatMap((s) => s.projectSlugs))
      };
    }
    return { skills: null, projects: new Set(projects.map((p) => p.slug)) };
  }

  get mapSkills() {
    const { skills } = this.focus;
    return this.layout.skills.map((s) => {
      const dim = skills && !skills.has(s.name);
      return {
        ...s,
        groupClass: `skill${dim ? " dim" : ""}${skills?.has(s.name) ? " lit" : ""}`,
        ariaLabel: `${s.name}, ${s.category}, used in ${s.evidenceCount} project${s.evidenceCount === 1 ? "" : "s"}`
      };
    });
  }

  get mapLinks() {
    const { skills } = this.focus;
    return this.layout.links.map((l) => ({
      ...l,
      linkClass: skills
        ? skills.has(l.skill) &&
          (!this.activeProject || l.slug === this.activeProject)
          ? "link lit"
          : "link dim"
        : "link",
      style: `stroke: ${l.color}`
    }));
  }

  get mapProjects() {
    const { projects } = this.focus;
    return this.layout.projects.map((p) => ({
      ...p,
      groupClass: `project${projects.has(p.slug) ? "" : " dim"}`,
      textY: p.y + 4
    }));
  }

  get sectors() {
    return this.layout.sectors.map((s) => ({
      ...s,
      style: `stroke: ${s.color}`,
      textStyle: `fill: ${s.color}`
    }));
  }

  get legend() {
    const present = new Set(this.skills.map((s) => s.category || "Platform"));
    return SKILL_CATEGORIES.filter((c) => present.has(c.name)).map((c) => ({
      key: c.name,
      name: c.name,
      swatch: `background: ${c.color}`,
      pressed: String(this.activeCategory === c.name),
      count: this.skills.filter((s) => (s.category || "Platform") === c.name)
        .length
    }));
  }

  get center() {
    const { center } = this.layout;
    if (this.activeSkill) {
      const skill = this.layout.skills.find((s) => s.name === this.activeSkill);
      return {
        title: skill.name,
        detail: `${skill.category} · ${skill.evidenceCount} project${skill.evidenceCount === 1 ? "" : "s"}`,
        x: center
      };
    }
    if (this.activeProject) {
      const project = this.layout.projects.find(
        (p) => p.slug === this.activeProject
      );
      return {
        title: project.title,
        detail: `${this.focus.skills.size} skills`,
        x: center
      };
    }
    return {
      title: `${this.skills.length} skills`,
      detail: `${this.projects.length} projects`,
      x: center
    };
  }

  get centerTitleY() {
    return this.layout.center - 4;
  }

  get centerDetailY() {
    return this.layout.center + 16;
  }

  get centerTitle() {
    const title = this.center.title;
    return title.length > 24 ? `${title.slice(0, 23)}…` : title;
  }

  get projectKey() {
    return this.layout.projects.map((p) => ({
      key: p.slug,
      code: p.code,
      title: p.title
    }));
  }

  get groups() {
    return this.legend.map((c) => ({
      ...c,
      skills: this.layout.skills
        .filter((s) => s.category === c.name)
        .map((s) => ({
          key: s.key,
          name: s.name,
          evidence: `${s.evidenceCount} project${s.evidenceCount === 1 ? "" : "s"}`,
          projects: s.projectSlugs
            .map(
              (slug) => this.layout.projects.find((p) => p.slug === slug)?.title
            )
            .filter(Boolean)
            .join(", ")
        }))
    }));
  }

  handleView(event) {
    this.view = event.currentTarget.dataset.view;
  }

  handleSkillEnter(event) {
    this.activeSkill = event.currentTarget.dataset.name;
    this.activeProject = undefined;
  }

  handleProjectEnter(event) {
    this.activeProject = event.currentTarget.dataset.slug;
    this.activeSkill = undefined;
  }

  handleLeave() {
    this.activeSkill = undefined;
    this.activeProject = undefined;
  }

  handleCategory(event) {
    const name = event.currentTarget.dataset.name;
    this.activeCategory = this.activeCategory === name ? undefined : name;
  }
}
