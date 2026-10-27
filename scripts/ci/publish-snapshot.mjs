#!/usr/bin/env node
// Measures the org after a deploy and records an Org_Snapshot__c row that the
// site's behind-the-scenes section displays. Keeps the 20 newest snapshots.
//
// Usage: node scripts/ci/publish-snapshot.mjs <org-alias>
// Reads GITHUB_SHA, GITHUB_SERVER_URL, GITHUB_REPOSITORY and GITHUB_RUN_ID when run in Actions.
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const org = process.argv[2];
if (!org) {
  console.error("Usage: publish-snapshot.mjs <org-alias>");
  process.exit(1);
}
const KEEP = 20;

function sf(args) {
  const out = execFileSync("sf", [...args, "--target-org", org, "--json"], {
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
    stdio: ["ignore", "pipe", "ignore"]
  });
  return JSON.parse(out).result;
}

function count(soql, tooling = true) {
  return sf(["data", "query", "--query", soql, ...(tooling ? ["--use-tooling-api"] : [])]).totalSize;
}

const apexClasses = count("SELECT Id FROM ApexClass WHERE NamespacePrefix = null");
const apexTriggers = count("SELECT Id FROM ApexTrigger WHERE NamespacePrefix = null");
const components = count("SELECT Id FROM LightningComponentBundle WHERE NamespacePrefix = null");
const customObjects = count("SELECT Id FROM CustomObject WHERE NamespacePrefix = null");

console.log("Running local Apex tests with coverage…");
let tests;
try {
  tests = sf(["apex", "run", "test", "--test-level", "RunLocalTests", "--code-coverage", "--wait", "30"]).summary;
} catch (error) {
  // A failing test exits non-zero; the JSON summary is still on stdout.
  tests = JSON.parse(error.stdout).result.summary;
}
const coverage = parseFloat(String(tests.orgWideCoverage || tests.testRunCoverage || "0").replace("%", ""));

const sha = process.env.GITHUB_SHA || execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
const repoUrl = process.env.GITHUB_REPOSITORY
  ? `${process.env.GITHUB_SERVER_URL || "https://github.com"}/${process.env.GITHUB_REPOSITORY}`
  : "https://github.com/pratiks2003/pratik-os";
const message = execFileSync("git", ["log", "-1", "--pretty=%s", sha], { encoding: "utf8" }).trim();

const snapshot = {
  Name: sha.slice(0, 7),
  Apex_Classes__c: apexClasses,
  Apex_Triggers__c: apexTriggers,
  Lightning_Components__c: components,
  Custom_Objects__c: customObjects,
  Apex_Tests__c: Number(tests.testsRan),
  Apex_Tests_Passed__c: Number(tests.passing),
  Code_Coverage__c: coverage,
  Commit_SHA__c: sha,
  Commit_Message__c: message.slice(0, 255),
  Commit_URL__c: `${repoUrl}/commit/${sha}`,
  Run_URL__c: process.env.GITHUB_RUN_ID ? `${repoUrl}/actions/runs/${process.env.GITHUB_RUN_ID}` : null,
  Deployed_At__c: new Date().toISOString()
};

const body = join(mkdtempSync(join(tmpdir(), "snapshot-")), "snapshot.json");
writeFileSync(body, JSON.stringify(snapshot));
execFileSync(
  "sf",
  ["api", "request", "rest", "/services/data/v66.0/sobjects/Org_Snapshot__c", "--method", "POST", "--body", `@${body}`, "--target-org", org],
  { stdio: ["ignore", "ignore", "ignore"] }
);

const old = sf(["data", "query", "--query", `SELECT Id FROM Org_Snapshot__c ORDER BY Deployed_At__c DESC NULLS LAST LIMIT 1000 OFFSET ${KEEP}`]).records;
for (const record of old) {
  sf(["data", "delete", "record", "--sobject", "Org_Snapshot__c", "--record-id", record.Id]);
}

console.log(
  `Snapshot ${snapshot.Name}: ${apexClasses} classes, ${apexTriggers} triggers, ${components} LWCs, ${customObjects} objects, ` +
    `${snapshot.Apex_Tests_Passed__c}/${snapshot.Apex_Tests__c} tests passing, ${coverage}% coverage`
);
if (snapshot.Apex_Tests_Passed__c !== snapshot.Apex_Tests__c) {
  process.exit(1);
}
