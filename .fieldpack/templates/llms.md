# llms.md — dense agent-facing docs

> Follows the [llms.txt](https://llmstxt.org) convention. No marketing prose.
> This file is what an agent reads to become competent in this repo.

## What this service does
<one paragraph, declarative>

## Key files
- `path/to/entry.ts` — entry point, registers routes/commands
- `path/to/config.ts` — environment + runtime config
- `path/to/<core>.ts` — core domain logic

## Conventions
- <important convention, with example>
- <another convention>

## Gotchas
- <subtle thing that an agent would otherwise get wrong>

## When changing X, also check Y
- If you touch the schema, regenerate the types via `<command>`.
- If you touch the API, update the OpenAPI spec at `<path>`.
