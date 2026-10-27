import { LightningElement, api, wire } from "lwc";
import getConfig from "@salesforce/apex/AtlasChatController.getConfig";
import sendMessage from "@salesforce/apex/AtlasChatController.sendMessage";

const STORAGE_KEY = "pxAtlas";
const WELCOME =
  "Hi, I'm Atlas, Pratik's AI assistant. Ask me about his Salesforce projects, skills or experience, or paste a job description and I'll show how he matches.";
const JD_PREFIX =
  "Here is a job description. How well does Pratik match it?\n\n";
const SUGGESTIONS = [
  { key: "built", label: "What has Pratik built with Apex?" },
  { key: "jd", label: "Paste a job description", jd: true },
  { key: "story", label: "Tell me about a time he fixed a production issue" },
  { key: "open", label: "Is Pratik open to new roles?" },
  { key: "contact", label: "How do I contact Pratik?" }
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Chat with Atlas inside the hero terminal. Replies are rendered as text
 * segments (never HTML); published project titles become buttons that open
 * the project's case study on the page.
 */
export default class PxAtlas extends LightningElement {
  @api projects = [];
  @api linkedInUrl;

  enabled = true;
  maxMessages = 20;
  maxLength = 8000;
  history = [];
  sessionId;
  sentCount = 0;
  pending = false;
  locked = false;
  jdMode = false;
  draft = "";
  shouldScroll = false;

  @wire(getConfig)
  wiredConfig({ data }) {
    if (data) {
      this.enabled = data.enabled;
      this.maxMessages = data.maxMessagesPerSession;
      this.maxLength = data.maxMessageLength;
    }
  }

  connectedCallback() {
    try {
      const saved = JSON.parse(
        window.sessionStorage.getItem(STORAGE_KEY) || "null"
      );
      if (saved) {
        this.history = saved.history || [];
        this.sessionId = saved.sessionId;
        this.sentCount = saved.sentCount || 0;
      }
    } catch {
      this.history = [];
    }
  }

  renderedCallback() {
    if (this.shouldScroll) {
      this.shouldScroll = false;
      const log = this.template.querySelector(".log");
      if (log) {
        log.scrollTop = log.scrollHeight;
      }
    }
  }

  get titlePattern() {
    const titles = this.projects
      .map((p) => p.record.Name)
      .filter(Boolean)
      .sort((a, b) => b.length - a.length)
      .map(escapeRegExp);
    return titles.length
      ? new RegExp(`(\\*\\*[^*]+\\*\\*|${titles.join("|")})`, "g")
      : /(\*\*[^*]+\*\*)/g;
  }

  get slugByTitle() {
    return new Map(this.projects.map((p) => [p.record.Name, p.record.Slug__c]));
  }

  toSegments(text, keyPrefix) {
    const slugs = this.slugByTitle;
    return String(text)
      .split(/\r?\n/)
      .filter((line, i, lines) => line.trim() || (i > 0 && lines[i - 1].trim()))
      .map((line, lineIndex) => ({
        key: `${keyPrefix}-l${lineIndex}`,
        isBlank: !line.trim(),
        parts: line
          .split(this.titlePattern)
          .filter((part) => part !== "")
          .map((part, partIndex) => {
            const bold =
              part.startsWith("**") && part.endsWith("**") && part.length > 4;
            const value = bold ? part.slice(2, -2) : part;
            const slug = slugs.get(value);
            return {
              key: `${keyPrefix}-l${lineIndex}-p${partIndex}`,
              text: value,
              isLink: Boolean(slug),
              slug,
              isBold: bold && !slug
            };
          })
      }));
  }

  get messages() {
    const all = [{ role: "atlas", text: WELCOME }, ...this.history];
    return all.map((m, index) => ({
      key: `m${index}`,
      isUser: m.role === "user",
      isNotice: m.role === "notice",
      lines: m.role === "user" ? [] : this.toSegments(m.text, `m${index}`),
      text: m.text,
      displayText:
        m.role === "user" && m.text.startsWith(JD_PREFIX)
          ? "📋 [job description pasted]"
          : m.text
    }));
  }

  get showSuggestions() {
    return !this.history.some((m) => m.role === "user") && !this.pending;
  }

  get suggestions() {
    return SUGGESTIONS;
  }

  get inputDisabled() {
    return (
      this.pending ||
      this.locked ||
      !this.enabled ||
      this.sentCount >= this.maxMessages
    );
  }

  get sendDisabled() {
    return this.inputDisabled || !this.draft.trim();
  }

  get placeholder() {
    if (!this.enabled) {
      return "Atlas is offline right now";
    }
    if (this.sentCount >= this.maxMessages) {
      return "This chat has reached its message limit";
    }
    return this.jdMode
      ? "Paste the job description, then press Enter…"
      : "Ask Atlas about Pratik…";
  }

  get rows() {
    return this.jdMode ? 6 : 1;
  }

  get remainingLabel() {
    const left = this.maxMessages - this.sentCount;
    return left <= 5 && left >= 0
      ? `${left} message${left === 1 ? "" : "s"} left in this chat`
      : "";
  }

  get hasHistory() {
    return this.history.length > 0;
  }

  /** Sends a question programmatically, e.g. from the command palette. */
  @api
  ask(question) {
    this.jdMode = false;
    this.draft = String(question || "");
    this.handleSend();
  }

  handleInput(event) {
    this.draft = event.target.value;
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.handleSend();
    }
  }

  handleSuggestion(event) {
    const suggestion = SUGGESTIONS.find(
      (s) => s.key === event.currentTarget.dataset.key
    );
    if (suggestion.jd) {
      this.jdMode = true;
      this.draft = "";
      this.focusInput();
      return;
    }
    this.draft = suggestion.label;
    this.handleSend();
  }

  handleLink(event) {
    this.dispatchEvent(
      new CustomEvent("openproject", {
        detail: { slug: event.currentTarget.dataset.slug },
        bubbles: true,
        composed: true
      })
    );
  }

  handleReset() {
    this.history = [];
    this.sessionId = undefined;
    this.sentCount = 0;
    this.locked = false;
    this.jdMode = false;
    this.draft = "";
    this.persist();
  }

  async handleSend() {
    const typed = this.draft.trim();
    if (!typed || this.inputDisabled) {
      return;
    }
    const message = (this.jdMode ? JD_PREFIX + typed : typed).slice(
      0,
      this.maxLength
    );
    this.history = [...this.history, { role: "user", text: message }];
    this.draft = "";
    // Clear the element too: if text is set and sent before a re-render, the
    // bound value never changes and the DOM would keep showing it.
    const input = this.template.querySelector("textarea");
    if (input) {
      input.value = "";
    }
    this.jdMode = false;
    this.pending = true;
    this.sentCount += 1;
    this.shouldScroll = true;
    this.persist();

    try {
      const result = await sendMessage({ message, sessionId: this.sessionId });
      if (result.status === "ok") {
        this.sessionId = result.sessionId || this.sessionId;
        this.history = [...this.history, { role: "atlas", text: result.reply }];
      } else {
        this.locked = result.status === "limit" || result.status === "offline";
        this.history = [
          ...this.history,
          { role: "notice", text: result.reply }
        ];
      }
    } catch {
      this.history = [
        ...this.history,
        {
          role: "notice",
          text: "Atlas could not be reached. Please try again in a moment."
        }
      ];
    } finally {
      this.pending = false;
      this.shouldScroll = true;
      this.persist();
      this.focusInput();
    }
  }

  focusInput() {
    Promise.resolve().then(() =>
      this.template.querySelector("textarea")?.focus()
    );
  }

  persist() {
    try {
      window.sessionStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          history: this.history.slice(-40),
          sessionId: this.sessionId,
          sentCount: this.sentCount
        })
      );
    } catch {
      // Storage may be unavailable; the conversation still works in memory.
    }
  }
}
