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

None.

## Closed debt

### TD-001 — Removed scaffold `Item`

**Status:** Closed 2026-07-14

**Owner:** Library persistence

Schema V3 removed `Item` from current persistence and intentionally discards
its timestamp-only scaffold rows. Historical V0, V1, and V2 definitions retain
the model solely as migration input. Actual on-disk migrations from every
supported prior schema preserved active songs and pending-removal records, the
standalone `Item.swift` file was removed with approval, and the complete
physical-device unit suite passed. See the completed
[Item Model Removal Execution Plan](item-model-removal.md) for the migration
decision and verification evidence.
