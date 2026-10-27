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

### Atlas, the AI assistant

Atlas is an Agentforce agent written in **Agent Script** ([`Atlas.agent`](force-app/main/default/aiAuthoringBundles/Atlas/Atlas.agent)) and versioned in Git. Its actions are invocable Apex (`AtlasGetProfile`, `AtlasSearchProjects`, `AtlasGetProjectDetail`, `AtlasMatchJobDescription`, `AtlasCreateInquiry`) built on the same `PortfolioService` as the site, so Atlas only knows what is published, and learns a new project the moment it is saved.

- **Guest access:** the site calls `AtlasChatController`, which invokes the agent through the `generateAiAgentResponse` invocable action. No connected app or stored secret is involved.
- **Credit guard:** a kill switch and a daily message cap in `Portfolio_Setting__mdt`, metered per day in `Site_Metric_Day__c`, plus a per-chat cap and input length limit.
- **Leads:** confirmed contact requests become `Inquiry__c` records, and `InquiryNotifier` emails every `Portfolio_Admin` user.
- **Links:** Atlas names projects by exact title; the chat UI turns published titles into buttons that open the case study.

To rebuild Atlas in a fresh org, create an Einstein Agent user, assign it the `Portfolio_Agent` permission set, set `default_agent_user` in the script, then:

```bash
sf agent publish authoring-bundle --api-name Atlas --target-org <alias>
sf agent activate --api-name Atlas --version <n> --target-org <alias>
```

### Live demos

Four demos run real Apex for anonymous visitors (`DemoController`, capped per day by `Daily_Demo_Cap__c`). Every business in them is fictional and the code was written from scratch for this site; each demo has a "view source" panel that loads the class body straight from the org.

| Demo                                                          | Pattern                                                              | How it stays safe                                                                                      |
| ------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Governor Limits Arena (`LimitsArena`)                         | Bulkified vs per-record SOQL/DML, measured with `Limits`             | Seeds and rolls back inside a savepoint; the naive run stops short of the uncatchable `LimitException` |
| Event Router (`ShipmentEventRouter`, `ShipmentEventHandlers`) | Strategy + Factory, version gating against stale events              | In memory, no DML                                                                                      |
| Self-Healing Sync (`NebulaPaySync`)                           | Error classification, exponential backoff, park or route to a person | Simulated gateway, no callouts                                                                         |
| Last Seat (`SeatBookingService`)                              | Lost-update race vs `SELECT … FOR UPDATE`                            | Two truly concurrent requests on a throwaway record, deleted when the run ends                         |

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
