# Execution Plans

Execution plans translate approved behavior into temporary implementation decisions for one delivery slice. They are not product specifications or required reading for unrelated work.

## Active plans

| Plan | State | Reading guidance |
| --- | --- | --- |
| [Player Interface Refresh](player-interface-refresh.md) | Active | Current documented acceptance is verified; additional interface scope remains to be defined and delivered |

## Completed plans

Completed plans are retained as historical verification records and are not required reading for current behavior or architecture.

| Plan | State | Reading guidance |
| --- | --- | --- |
| [iPhone Portrait-Only Orientation](iphone-portrait-orientation.md) | Complete | Verified portrait-only iPhone metadata and launch configurations while preserving the four-orientation iPad declaration and landscape launch coverage |
| [Playback Integration](playback-integration.md) | Complete | Verified automated, iPhone system-integration, and representative iPad acceptance record |
| [Development Schema Simplification](archive/development-schema-simplification.md) | Complete | Verified single-schema development persistence record |
| [Item Model Removal](archive/item-model-removal.md) | Complete | Verified TD-001 schema cleanup record |
| [Library Management](archive/library-management.md) | Complete | Historical verification record only |
| [Basic Playback](archive/basic-playback.md) | Complete | Historical verification record only |
| [Import to Songs List](archive/import-to-songs-list.md) | Complete | Historical verification record only |

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
