# Technical Debt Tracker

This versioned tracker makes known compromises legible and actionable without turning `AGENTS.md`, product specifications, or `ARCHITECTURE.md` into debt backlogs. It follows the repository-knowledge and continuous-garbage-collection approach described in OpenAI's [Harness Engineering](https://openai.com/index/harness-engineering/).

## Operating rules

- Record only an intentional, currently present compromise with concrete cost. Feature ideas and speculative refactors do not belong here.
- Every active item has an owner, interest, cleanup trigger, safe guardrails, and objective exit criteria.
- Pay debt down continuously in the smallest coherent changes. Do not wait for a broad cleanup project when a touched area permits safe incremental removal.
- Review an entry whenever related code, architecture, or an execution plan changes. Update its evidence and last-reviewed date in the same change.
- Close an entry only after the exit criteria are verified. Keep closed entries as compact historical evidence or move them to a completed section during documentation gardening.
- If cleanup changes product behavior, persisted data, capabilities, or architectural boundaries, obtain the required approval and create an execution plan before implementation.

## Active debt

| ID | Area | Summary | Owner | Cleanup trigger | Last reviewed |
| --- | --- | --- | --- | --- | --- |
| TD-001 | Library persistence | Retained scaffold `Item` model and V0 schema | Library persistence | After Library Management's additive schema and migration are implemented and verified | 2026-07-13 |

## TD-001 — Retained scaffold `Item`

**Status:** Accepted, active
**Introduced:** Initial app scaffold
**Owner:** Library persistence

### Context and interest

`Item` and schema V0 remain solely to preserve the original store through the current additive V1 migration. The app no longer reads or presents `Item`.

The debt adds an irrelevant persisted model to every schema, expands migration reasoning and tests, and may mislead future work into reusing scaffold data as a Library concept.

### Guardrails while active

- Do not add fields, relationships, UI, or new runtime references to `Item`.
- Keep migration coverage proving that supported prior stores open without deleting Library songs.
- Do not delete the store or bypass migration to remove the model.
- Removing the persisted model or `Item.swift` requires the explicit destructive-data-model and file-deletion approval in `AGENTS.md`.

### Cleanup trigger

After Library Management's next additive schema is implemented and its migration path is verified, create a focused execution plan for removing `Item` in the following schema version.

### Exit criteria

- The current schema and app composition no longer reference `Item`.
- Migration tests open every supported prior schema without deleting Library songs.
- Existing scaffold rows are intentionally discarded or transformed according to the approved migration plan.
- `Item.swift` is removed after approval.
- `ARCHITECTURE.md`, migration documentation, and this tracker reflect the completed cleanup.

## Closed debt

None yet.
