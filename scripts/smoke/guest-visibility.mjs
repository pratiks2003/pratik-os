#!/usr/bin/env node
// Post-deploy smoke test: calls the public site as an anonymous guest and
// fails if any unpublished record leaks into the response.
//
// Usage: node scripts/smoke/guest-visibility.mjs <org-alias> <site-url>
import { execFileSync } from "node:child_process";

const [org, siteUrl] = process.argv.slice(2);
if (!org || !siteUrl) {
  console.error("Usage: guest-visibility.mjs <org-alias> <site-url>");
  process.exit(1);
}

function query(soql) {
  const out = execFileSync(
    "sf",
    ["data", "query", "--target-org", org, "--query", soql, "--json"],
    {
      encoding: "utf8",
      maxBuffer: 10 * 1024 * 1024
    }
  );
  return JSON.parse(out).result.records;
}

const publishable = [
  "Portfolio_Profile__c",
  "Highlight__c",
  "Experience__c",
  "Project__c",
  "Certification__c",
  "Skill__c"
];
const hiddenIds = publishable.flatMap((object) =>
  query(`SELECT Id FROM ${object} WHERE Published__c = false`).map((r) => r.Id)
);
const classId = query(
  "SELECT Id FROM ApexClass WHERE Name = 'PortfolioController'"
)[0].Id.slice(0, 15);

const response = await fetch(
  `${siteUrl.replace(/\/$/, "")}/webruntime/api/apex/execute?language=en-US&asGuest=true&htmlEncode=false`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      namespace: "",
      classname: `@udd/${classId}`,
      method: "getSiteData",
      isContinuation: false,
      params: {},
      cacheable: false
    })
  }
);
const body = await response.text();
const data = JSON.parse(body).returnValue;
if (!response.ok || !data) {
  console.error(
    `Guest call failed (${response.status}): ${body.slice(0, 500)}`
  );
  process.exit(1);
}

const leaked = hiddenIds.filter(
  (id) => body.includes(id) || body.includes(id.slice(0, 15))
);
if (leaked.length > 0) {
  console.error(`Unpublished records visible to guest: ${leaked.join(", ")}`);
  process.exit(1);
}
console.log(
  `Guest visibility OK: ${data.projects.length} projects, ${data.skills.length} skills visible; ` +
    `${hiddenIds.length} unpublished records hidden.`
);
