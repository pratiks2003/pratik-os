import { LightningElement, api } from "lwc";

const SECTIONS = [
  "about",
  "experience",
  "projects",
  "demos",
  "skills",
  "certifications",
  "behind-the-scenes",
  "contact"
];
const DEMOS = [
  { key: "limits", label: "governor limits arena" },
  { key: "router", label: "event router" },
  { key: "retry", label: "self-healing sync" },
  { key: "seat", label: "last seat race" }
];

/** Fuzzy subsequence score: higher is better, -1 means no match. */
export function fuzzyScore(query, text) {
  const q = query.toLowerCase().trim();
  const t = text.toLowerCase();
  if (!q) {
    return 0;
  }
  if (t.includes(q)) {
    return 100 - t.indexOf(q);
  }
  let score = 0;
  let position = 0;
  for (const char of q) {
    const found = t.indexOf(char, position);
    if (found === -1) {
      return -1;
    }
    score += found === position ? 3 : 1;
    position = found + 1;
  }
  return score;
}

/**
 * ⌘K command palette. Commands either emit a "command" event for pxApp to
 * run, or print a line of output in the palette (whoami, help, easter eggs).
 */
export default class PxCommandPalette extends LightningElement {
  @api projects = [];
  @api profile = {};
  @api skillCount = 0;

  isOpen = false;
  query = "";
  selected = 0;
  output = [];

  @api
  open() {
    this.isOpen = true;
    this.query = "";
    this.selected = 0;
    this.output = [];
    // Focus after the dialog renders.
    Promise.resolve().then(() => this.template.querySelector("input")?.focus());
  }

  @api
  close() {
    this.isOpen = false;
  }

  get commands() {
    const projectCommands = this.projects.map((p) => ({
      id: `cat:${p.record.Slug__c}`,
      label: `cat ${p.record.Slug__c}.md`,
      hint: p.record.Name,
      action: "openProject",
      value: p.record.Slug__c
    }));
    return [
      {
        id: "help",
        label: "help",
        hint: "list what this terminal can do",
        print: "help"
      },
      {
        id: "whoami",
        label: "whoami",
        hint: "who built this site",
        print: "whoami"
      },
      {
        id: "ls",
        label: "ls projects",
        hint: "list case studies",
        print: "ls"
      },
      ...projectCommands,
      ...DEMOS.map((d) => ({
        id: `demo:${d.key}`,
        label: `run demo ${d.key}`,
        hint: d.label,
        action: "demo",
        value: d.key
      })),
      ...SECTIONS.map((s) => ({
        id: `cd:${s}`,
        label: `cd ~/${s}`,
        hint: "jump to section",
        action: "navigate",
        value: s
      })),
      {
        id: "mode:recruiter",
        label: "mode recruiter",
        hint: "business impact first",
        action: "mode",
        value: "recruiter"
      },
      {
        id: "mode:engineer",
        label: "mode engineer",
        hint: "architecture and code first",
        action: "mode",
        value: "engineer"
      },
      {
        id: "contact",
        label: "contact",
        hint: "send Pratik a message",
        action: "navigate",
        value: "contact"
      }
    ];
  }

  get results() {
    const query = this.query.trim();
    const easterEgg = this.easterEgg(query);
    let list;
    if (!query) {
      list = this.commands.filter((c) =>
        [
          "help",
          "whoami",
          "ls",
          "demo:limits",
          "demo:seat",
          "cd:projects",
          "mode:engineer",
          "contact"
        ].includes(c.id)
      );
    } else {
      list = this.commands
        .map((c) => ({
          c,
          score: Math.max(
            fuzzyScore(query, c.label),
            fuzzyScore(query, c.hint) - 20
          )
        }))
        .filter((r) => r.score >= 0)
        .sort((a, b) => b.score - a.score)
        .slice(0, 7)
        .map((r) => r.c);
      const question = query.replace(/^ask\s+/i, "");
      list.push({
        id: "ask",
        label: `ask "${question}"`,
        hint: "send to Atlas, the AI assistant",
        action: "ask",
        value: question
      });
      if (/^ask\s+/i.test(query)) {
        list.unshift(list.pop());
      }
    }
    if (easterEgg) {
      list.unshift(easterEgg);
    }
    return list.map((c, index) => ({
      ...c,
      key: c.id,
      index,
      selected: index === this.selected,
      cls: `result${index === this.selected ? " selected" : ""}`
    }));
  }

  get hasOutput() {
    return this.output.length > 0;
  }

  easterEgg(query) {
    const q = query.toLowerCase();
    const eggs = {
      "sudo hire pratik": "sudo",
      "rm -rf /": "rm",
      "sf org display": "org",
      coffee: "coffee",
      "git blame": "blame",
      exit: "exit"
    };
    const match = eggs[q];
    return match
      ? { id: `egg:${match}`, label: query, hint: "↵ to run", print: match }
      : null;
  }

  printLines(kind) {
    const p = this.profile;
    switch (kind) {
      case "help":
        return [
          "ask <question>      ask Atlas anything about Pratik",
          "ls projects         list case studies · cat <name>.md opens one",
          "run demo <name>     limits · router · retry · seat",
          "cd ~/<section>      jump around · mode recruiter|engineer",
          "whoami · contact    and a few things worth guessing"
        ];
      case "whoami":
        return [
          `${p.Name} · ${p.Headline__c}`,
          `${p.Availability__c || ""}${p.Location__c ? ` · ${p.Location__c}` : ""}`
        ];
      case "ls":
        return this.projects.map(
          (x) => `${x.record.Slug__c}.md  ${x.record.Name}`
        );
      case "sudo":
        return [
          "[sudo] password for recruiter: ••••••••",
          "✔ Access granted. Opening a channel to Pratik…"
        ];
      case "rm":
        return [
          "rm: refusing to remove '/': this org is protected by governor limits 😉"
        ];
      case "org":
        return [
          `✔ Connected · ${this.projects.length} projects · ${this.skillCount} skills · Atlas online`
        ];
      case "coffee":
        return ["☕ Brewing… dark roast, to match the theme."];
      case "blame":
        return [
          "Every line on this site was written for it. Blame accepted: Pratik Shinde."
        ];
      default:
        return [];
    }
  }

  run(command) {
    if (!command) {
      return;
    }
    if (command.print === "exit") {
      this.close();
      return;
    }
    if (command.print) {
      this.output = this.printLines(command.print).map((text, i) => ({
        key: `o${i}`,
        text
      }));
      if (command.print === "sudo") {
        // Let the joke land, then open the contact section.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.emit("navigate", "contact"), 1200);
      }
      this.query = "";
      this.selected = 0;
      return;
    }
    if (command.action === "ask" && !command.value) {
      return;
    }
    this.emit(command.action, command.value);
  }

  emit(action, value) {
    this.close();
    this.dispatchEvent(
      new CustomEvent("command", { detail: { action, value } })
    );
  }

  handleInput(event) {
    this.query = event.target.value;
    this.selected = 0;
  }

  handleKeydown(event) {
    const count = this.results.length;
    if (event.key === "ArrowDown") {
      event.preventDefault();
      this.selected = (this.selected + 1) % count;
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.selected = (this.selected - 1 + count) % count;
    } else if (event.key === "Enter") {
      event.preventDefault();
      this.run(this.results[this.selected]);
    } else if (event.key === "Escape") {
      this.close();
    }
  }

  handleResult(event) {
    this.run(this.results[Number(event.currentTarget.dataset.index)]);
  }

  handleBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }
}
