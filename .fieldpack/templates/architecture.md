# Architecture

Internal-tier mental model. Update when components are added, renamed, or removed.

## Overview
<2-3 sentences: what this service is and how it fits into Fieldpack>

## Components
| Component | Job | Depends on |
|---|---|---|
| <name> | <one-sentence responsibility> | <other components or external systems> |

## Data flow
<short narrative or bullet list — what happens when the primary use case runs>

## Operational notes
- Deploy target: <see service.yaml deploy.target>
- Secrets required: <see .env.example>
- Failure modes worth knowing: <list, brief>
