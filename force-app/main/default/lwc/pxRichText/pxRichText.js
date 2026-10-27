import { LightningElement, api } from "lwc";
import { toBlocks } from "c/pxUtils";

/** Renders record text as paragraphs and bullet lists, never as raw HTML. */
export default class PxRichText extends LightningElement {
  @api text;

  get blocks() {
    return toBlocks(this.text);
  }
}
