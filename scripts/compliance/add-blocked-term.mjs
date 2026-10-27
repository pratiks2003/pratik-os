#!/usr/bin/env node
// Adds confidential terms to Blocked_Term__mdt as keyed hashes. The plain
// term is never written to disk, so the public repo cannot reveal it.
//
// Usage: node scripts/compliance/add-blocked-term.mjs "Term one" "Term two"
// Then deploy force-app/main/default/customMetadata.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { normalize, keyedHash } from "./fingerprint.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const keyFile = join(root, ".secrets", "compliance-key");
const outDir = join(root, "force-app", "main", "default", "customMetadata");

if (!existsSync(keyFile)) {
  console.error(
    "Missing .secrets/compliance-key. Run scripts/compliance/set-key.sh <org> first."
  );
  process.exit(1);
}
const terms = process.argv.slice(2);
if (terms.length === 0) {
  console.error(
    'Usage: node scripts/compliance/add-blocked-term.mjs "Term" ["Term" ...]'
  );
  process.exit(1);
}

const key = readFileSync(keyFile, "utf8").trim();
let added = 0;
for (const term of terms) {
  const normalized = normalize(term);
  if (!normalized) continue;
  const hash = keyedHash(normalized, key);
  const name = `BT_${hash.slice(0, 12)}`;
  const file = join(outDir, `Blocked_Term.${name}.md-meta.xml`);
  if (existsSync(file)) continue;
  writeFileSync(
    file,
    `<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <label>${name}</label>
  <protected>false</protected>
  <values>
    <field>Term_Hash__c</field>
    <value xsi:type="xsd:string">${hash}</value>
  </values>
  <values>
    <field>Token_Count__c</field>
    <value xsi:type="xsd:double">${normalized.split(" ").length}</value>
  </values>
  <values>
    <field>Is_Active__c</field>
    <value xsi:type="xsd:boolean">true</value>
  </values>
</CustomMetadata>
`
  );
  added++;
}
console.log(
  `Added ${added} blocked term(s). Deploy force-app/main/default/customMetadata to apply.`
);
