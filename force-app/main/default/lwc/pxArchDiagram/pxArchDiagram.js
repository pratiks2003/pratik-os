import { LightningElement, api } from "lwc";
import { layoutDiagram, parseDiagram } from "c/pxUtils";

/**
 * Renders a project's Architecture_DSL__c ("A -> B : label" per line) as an
 * SVG flow diagram with animated edges. No third-party libraries.
 */
export default class PxArchDiagram extends LightningElement {
  @api dsl;
  @api label = "Architecture diagram";

  get layout() {
    return layoutDiagram(parseDiagram(this.dsl));
  }

  get hasDiagram() {
    return this.layout.nodes.length > 0;
  }

  get viewBox() {
    const { width, height } = this.layout;
    return `0 0 ${Math.ceil(width)} ${Math.ceil(height)}`;
  }

  get svgStyle() {
    // Never shrink below 75% of natural size; wider diagrams scroll instead.
    return `min-width: ${Math.ceil(this.layout.width * 0.75)}px`;
  }

  get description() {
    return parseDiagram(this.dsl)
      .edges.map((e) => `${e.from} to ${e.to}${e.label ? ` (${e.label})` : ""}`)
      .join("; ");
  }
}
