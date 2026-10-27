import { LightningElement, api, wire } from "lwc";
import getSource from "@salesforce/apex/DemoController.getSource";

const KEYWORDS = new Set(
  (
    "abstract break catch class continue else enum extends false final finally for global if implements " +
    "inherited insert interface new null override private protected public return select sharing static " +
    "super switch this throw true try update upsert delete virtual void when while with without from where " +
    "limit order by in for update"
  ).split(" ")
);
const TYPES = new Set(
  "Boolean Integer Long Decimal Double String Id Date Datetime List Map Set Object SObject HttpResponse Savepoint Database Limits Math JSON Type".split(
    " "
  )
);
const TOKEN =
  /(\/\/.*$|\/\*|\*\/|'(?:\\.|[^'\\])*'|@\w+|\b\d+\b|\b[A-Za-z_]\w*\b)/g;

/** Tokenises Apex for display. Output is text spans only, never HTML. */
export function tokenize(source) {
  let inComment = false;
  return String(source || "")
    .replace(/\t/g, "  ")
    .split(/\r?\n/)
    .map((line, index) => {
      const tokens = [];
      let last = 0;
      const push = (text, kind) =>
        text &&
        tokens.push({
          key: `${index}-${tokens.length}`,
          text,
          cls: kind ? `t-${kind}` : ""
        });
      if (inComment) {
        const end = line.indexOf("*/");
        if (end === -1) {
          push(line, "comment");
          return { key: `l${index}`, number: index + 1, tokens };
        }
        push(line.slice(0, end + 2), "comment");
        last = end + 2;
        inComment = false;
      }
      TOKEN.lastIndex = last;
      let match;
      while ((match = TOKEN.exec(line)) !== null) {
        push(line.slice(last, match.index));
        const text = match[0];
        if (text === "/*") {
          const end = line.indexOf("*/", match.index + 2);
          const comment =
            end === -1
              ? line.slice(match.index)
              : line.slice(match.index, end + 2);
          push(comment, "comment");
          last = match.index + comment.length;
          TOKEN.lastIndex = last;
          inComment = end === -1;
          if (inComment) {
            break;
          }
          continue;
        }
        let kind = "";
        if (text.startsWith("//")) kind = "comment";
        else if (text.startsWith("'")) kind = "string";
        else if (text.startsWith("@")) kind = "annotation";
        else if (/^\d/.test(text)) kind = "number";
        else if (KEYWORDS.has(text.toLowerCase())) kind = "keyword";
        else if (TYPES.has(text) || /^[A-Z]/.test(text)) kind = "type";
        push(text, kind);
        last = match.index + text.length;
      }
      if (!inComment) {
        push(line.slice(last));
      }
      return { key: `l${index}`, number: index + 1, tokens };
    });
}

export default class PxCodeViewer extends LightningElement {
  @api className;

  source;
  error;

  @wire(getSource, { className: "$className" })
  wiredSource({ data, error }) {
    this.source = data;
    this.error = error;
  }

  get lines() {
    return tokenize(this.source);
  }

  get loading() {
    return this.source === undefined && !this.error;
  }

  get fileName() {
    return `${this.className}.cls`;
  }
}
