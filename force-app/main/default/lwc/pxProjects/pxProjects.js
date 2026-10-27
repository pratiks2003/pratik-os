import { LightningElement, api } from "lwc";

const HASH_PREFIX = "#project/";
const MAX_CARD_SKILLS = 5;

function splitMetrics(metrics) {
  return String(metrics || "")
    .split("·")
    .map((m) => m.trim())
    .filter(Boolean);
}

function firstBullet(text) {
  const line = String(text || "")
    .split(/\r?\n/)
    .find((l) => l.trim().startsWith("- "));
  return line ? line.trim().slice(2) : "";
}

function truncate(text, length) {
  const value = String(text || "");
  return value.length > length
    ? `${value.slice(0, length - 1).trimEnd()}…`
    : value;
}

/** Project case studies: filterable cards plus a detail dialog with deep links. */
export default class PxProjects extends LightningElement {
  @api mode = "recruiter";

  _projects = [];
  filter = "All";
  selectedSlug;
  tab = "recruiter";
  restoreFocusTo;
  hashChecked = false;

  @api
  get projects() {
    return this._projects;
  }
  set projects(value) {
    this._projects = value || [];
  }

  renderedCallback() {
    if (!this.hashChecked && this._projects.length) {
      this.hashChecked = true;
      const hash = window.location.hash || "";
      if (hash.startsWith(HASH_PREFIX)) {
        this.open(decodeURIComponent(hash.slice(HASH_PREFIX.length)));
      }
    }
    if (this.selectedSlug && this.focusDialog) {
      this.focusDialog = false;
      this.template.querySelector(".close")?.focus();
    }
    if (this.restoreFocusTo) {
      this.template
        .querySelector(`.card-button[data-slug="${this.restoreFocusTo}"]`)
        ?.focus();
      this.restoreFocusTo = undefined;
    }
  }

  get filters() {
    const categories = [
      ...new Set(
        this._projects.map((p) => p.record.Category__c).filter(Boolean)
      )
    ];
    return ["All", ...categories].map((name) => ({
      key: name,
      name,
      pressed: String(this.filter === name)
    }));
  }

  get cards() {
    const engineer = this.mode === "engineer";
    return this._projects
      .filter(
        (p) => this.filter === "All" || p.record.Category__c === this.filter
      )
      .map((p, index) => {
        const r = p.record;
        const skills = p.skills || [];
        return {
          key: r.Slug__c,
          slug: r.Slug__c,
          index: String(index + 1).padStart(2, "0"),
          title: r.Name,
          category: r.Category__c,
          isPersonal: r.Project_Type__c === "Personal",
          featured: r.Featured__c,
          blurb: engineer
            ? truncate(
                firstBullet(r.Technical_Deep_Dive__c) || r.Tagline__c,
                170
              )
            : r.Tagline__c,
          metrics: splitMetrics(r.Metrics__c).slice(0, 3),
          skills: skills.slice(0, MAX_CARD_SKILLS),
          moreSkills:
            skills.length > MAX_CARD_SKILLS
              ? `+${skills.length - MAX_CARD_SKILLS}`
              : null
        };
      });
  }

  get selected() {
    const project = this._projects.find(
      (p) => p.record.Slug__c === this.selectedSlug
    );
    if (!project) {
      return null;
    }
    const r = project.record;
    return {
      title: r.Name,
      tagline: r.Tagline__c,
      category: r.Category__c,
      type: r.Project_Type__c,
      metrics: splitMetrics(r.Metrics__c),
      impact: r.Business_Impact__c,
      deepDive: r.Technical_Deep_Dive__c,
      diagram: r.Architecture_DSL__c,
      repoUrl: r.Repo_URL__c,
      skills: project.skills || [],
      star: this.parseStar(r.STAR_Story__c)
    };
  }

  get tabs() {
    const tabs = [
      { key: "recruiter", label: "recruiter view" },
      { key: "engineer", label: "engineer view" }
    ];
    if (this.selected?.star.length) {
      tabs.push({ key: "story", label: "STAR story" });
    }
    return tabs.map((t) => ({
      ...t,
      selected: String(this.tab === t.key),
      tabIndex: this.tab === t.key ? "0" : "-1"
    }));
  }

  get isRecruiterTab() {
    return this.tab === "recruiter";
  }

  get isEngineerTab() {
    return this.tab === "engineer";
  }

  get isStoryTab() {
    return this.tab === "story";
  }

  parseStar(text) {
    return String(text || "")
      .split(/\r?\n/)
      .map((line) =>
        line.match(/^\s*(Situation|Task|Action|Result)\s*:\s*(.+)$/i)
      )
      .filter(Boolean)
      .map((m) => ({ key: m[1], label: m[1], text: m[2] }));
  }

  handleFilter(event) {
    this.filter = event.currentTarget.dataset.name;
  }

  handleOpen(event) {
    this.open(event.currentTarget.dataset.slug);
  }

  open(slug) {
    if (!this._projects.some((p) => p.record.Slug__c === slug)) {
      return;
    }
    this.selectedSlug = slug;
    this.tab = this.mode === "engineer" ? "engineer" : "recruiter";
    this.focusDialog = true;
    this.replaceHash(`${HASH_PREFIX}${encodeURIComponent(slug)}`);
  }

  handleClose() {
    this.restoreFocusTo = this.selectedSlug;
    this.selectedSlug = undefined;
    this.replaceHash("");
  }

  handleBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.handleClose();
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.handleClose();
    }
  }

  handleTab(event) {
    this.tab = event.currentTarget.dataset.key;
  }

  replaceHash(hash) {
    try {
      const { pathname, search } = window.location;
      window.history.replaceState(null, "", `${pathname}${search}${hash}`);
    } catch {
      // History may be unavailable in some embeds; deep links are optional.
    }
  }
}
