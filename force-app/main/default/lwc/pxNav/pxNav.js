import { LightningElement, api } from "lwc";

const LINKS = [
  { section: "experience", label: "~/experience" },
  { section: "projects", label: "~/projects" },
  { section: "skills", label: "~/skills" },
  { section: "certifications", label: "~/certs" },
  { section: "contact", label: "~/contact" }
];

export default class PxNav extends LightningElement {
  @api mode = "recruiter";

  links = LINKS;

  get isRecruiter() {
    return String(this.mode === "recruiter");
  }

  get isEngineer() {
    return String(this.mode === "engineer");
  }

  handleLink(event) {
    this.navigate(event.currentTarget.dataset.section);
  }

  handleHome() {
    this.navigate("about");
  }

  handleMode(event) {
    this.dispatchEvent(
      new CustomEvent("modechange", {
        detail: { mode: event.currentTarget.dataset.mode }
      })
    );
  }

  navigate(section) {
    this.dispatchEvent(new CustomEvent("navigate", { detail: { section } }));
  }
}
