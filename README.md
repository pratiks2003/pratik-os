# pratik.os

> A self-documenting Salesforce portfolio. The site doesn't just describe Salesforce skills, it runs on them.

Built on **Experience Cloud (LWR)**, **Lightning Web Components**, **Apex**, and **Agentforce**.

## How it works

- **One record in, everything updates.** All site content and everything the AI assistant (Atlas) knows comes from records in the org. Insert a `Project__c`, mark it published, and it appears on the site and in Atlas's answers. No code changes.
- **Guest-safe by design.** The public site uses a read-only guest user, sharing rules that expose only published records, and `with sharing` Apex.
- **Live demos.** Governor limits, Strategy/Factory event routing, self-healing retries, and record locking, running for real in the org. All demos use fictional businesses and are written from scratch.

## Status

| Milestone | Scope                                             | Status         |
| --------- | ------------------------------------------------- | -------------- |
| M0        | Foundations, CI/CD, technical spikes              | 🚧 In progress |
| M1        | Data model, "one record" engine, compliance guard | ⏳             |
| M2        | Site shell and dark design system                 | ⏳             |
| M3        | Atlas, the Agentforce assistant                   | ⏳             |
| M4        | Live demos                                        | ⏳             |
| M5        | Command palette, behind-the-scenes                | ⏳             |
| M6        | Admin experience                                  | ⏳             |
| M7        | Hardening and launch                              | ⏳             |

## Architecture notes

### The "one record" engine

`Project__c.Tech_Stack__c` is plain comma-separated text. `ProjectTriggerHandler` hands changed projects to `SkillLinkService`, which creates missing `Skill__c` records (categorised by `SkillCategorizer`) and keeps `Project_Skill__c` links in sync, with a fixed number of queries and DML statements however many records are saved.

### Guest access

The public site runs as the Experience Cloud guest user with the `Portfolio_Guest` permission set (read-only). `PortfolioSelector` queries in **user mode**, so object permissions, field-level security and guest sharing rules (only `Published__c = true`) are enforced by the platform. After every deploy, `scripts/smoke/guest-visibility.mjs` calls the live site anonymously and fails the build if any unpublished record leaks.

### Confidentiality guard

Some portfolio content describes professional work that must not reveal confidential names. `ComplianceGuard` blocks publishing any record whose text contains a blocked term. Terms are stored in `Blocked_Term__mdt` only as HMAC-SHA256 hashes keyed by a secret held in the protected `Compliance_Settings__c` setting, so this public repository never reveals what is blocked.

```bash
scripts/compliance/set-key.sh <org>                              # one-time: create and store the key
node scripts/compliance/add-blocked-term.mjs "Term" "Other Term" # writes hashed metadata records
sf project deploy start -d force-app/main/default/customMetadata --target-org <org>
```

## Development

```bash
npm install
sf project deploy start --source-dir force-app --target-org <alias>
sf community publish --name "pratik.os" --target-org <alias>
```

To rebuild the content in a fresh org (after `set-key.sh`, so the confidentiality guard allows publishing):

```bash
sf data import tree --plan data/seed/plan.json --target-org <alias>
```

CI validates every pull request (lint, LWC tests, Apex tests, deploy validation). Merges to `main` deploy and publish the site. A weekly job keeps the Developer Edition org active.
