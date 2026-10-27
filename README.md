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

## Development

```bash
npm install
sf project deploy start --source-dir force-app --target-org <alias>
sf community publish --name "pratik.os" --target-org <alias>
```

CI validates every pull request (lint, LWC tests, Apex tests, deploy validation). Merges to `main` deploy and publish the site. A weekly job keeps the Developer Edition org active.
