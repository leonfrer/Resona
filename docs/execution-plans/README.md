# Execution Plans

Execution plans translate approved behavior into temporary implementation decisions for one delivery slice. They are not product specifications or required reading for unrelated work.

## Current plans

| Plan | State | Reading guidance |
| --- | --- | --- |
| [Library Management](library-management.md) | In progress | Active plan; read for Library Management work |
| [Basic Playback](basic-playback.md) | Complete | Historical verification record only |
| [Import to Songs List](import-to-songs-list.md) | Complete | Historical verification record only |

Known compromises and cleanup triggers live in the [technical-debt tracker](tech-debt-tracker.md), not in `AGENTS.md`, product specifications, or the current architecture map.

## Lifecycle

1. Create a plan only when a change crosses boundaries, changes persisted data, adds a capability, or needs staged delivery and verification.
2. Reference approved behavior instead of restating it. Record implementation choices, risks, sequence, and verification evidence.
3. Keep only implementation-relevant open questions. Behavior-changing questions return to the owning product specification.
4. Mark the plan Complete only after its acceptance criteria and delivery checks are verified.
5. Once Complete, add a dated completion record, remove it from the active-plan list, and treat it as historical evidence.
6. During documentation maintenance, move completed plans to `execution-plans/archive/` or replace them with a compact completion record after link impact is checked and file-move approval is obtained. Preserve repository history rather than copying completed plans into new active documents.

Agents should not read completed plans to understand current behavior. Use the product specifications for behavior and `ARCHITECTURE.md` for the current implementation.

## Debt maintenance

- Record a compromise when it is intentionally deferred and has continuing maintenance, correctness, performance, or agent-legibility cost.
- Prefer small, continuous cleanup changes over accumulating a large future rewrite.
- Review touched debt entries during related work and close them only with verification evidence.
- Convert a debt item into an execution plan when its cleanup crosses boundaries, changes persisted data, or needs staged delivery.
