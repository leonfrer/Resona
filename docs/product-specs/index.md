# Product Specifications

Product specifications are the source of truth for user-visible behavior and acceptance criteria. They describe what Resona should do without prescribing implementation details owned by `ARCHITECTURE.md` or an execution plan.

[Quality attributes](quality-attributes.md) apply across the dependency chain and define the release qualification envelope, responsiveness budgets, and storage expectations.

## Product dependency order

The specifications are ordered by dependency rather than by screen or user journey:

```text
Experience foundation
  -> Library foundation
  -> Local audio import
  -> Music library
  -> Basic playback
  -> Playback integration
```

The experience foundation defines cross-feature navigation and feedback principles. The library foundation defines what an imported song is and owns its durable identity, normalized metadata contract, supported-format policy, and managed audio resource. Import reads external files and creates conforming library songs, the library UI presents and manages them, and playback consumes their stable identities and available audio resources.

This dependency order does not require completing every library feature before import or playback. Work should proceed in the smallest end-to-end slices described below.

## Specifications

| Specification | Status | Implementation |
| --- | --- | --- |
| [Experience foundation](experience-foundation.md) | Active | Import, library, Basic Playback, removal feedback, and removal accessibility subsets verified |
| [Library foundation](library-foundation.md) | Active | Identity, storage, metadata, consistency, and removal subsets implemented and verified |
| [Local audio import](local-audio-import.md) | Active | Import to Songs List slice implemented and verified |
| [Music library](music-library.md) | Active | Songs List, playback selection, and Library Management implemented and verified |
| [Basic playback](basic-playback.md) | Implemented | Runtime, Audio background mode, automated suites, and physical background/lock behavior verified |
| [Playback integration](playback.md) | Proposed | Not started |
| [Quality attributes](quality-attributes.md) | Active | Initial performance and storage targets defined; release evidence pending |

## Implementation readiness

The active specifications approve the remaining Foundation and Music Library work. Concrete SwiftData fields, managed-file layout, playback-engine boundaries, authoritative playback-state representation, and other type boundaries remain implementation decisions; an execution plan must record them before they are introduced and `ARCHITECTURE.md` must be updated when the current system map changes.

The [execution-plan index](../execution-plans/README.md) separates active plans from historical verification records. The completed [Library Management Execution Plan](../execution-plans/library-management.md) retains its delivery evidence.

Basic Playback is implemented, including its explicitly approved Audio background mode and minimum background continuation. Playback Integration remains Proposed; system Now Playing presentation, remote commands, queues, restoration, and broader interruption or route behavior owned by it are not part of Basic Playback and must not be claimed as implemented until its remaining decisions are resolved and it becomes Active.

## Recommended delivery slices

1. **Foundations:** resolve the shared experience direction, supported formats, durable song identity, metadata contract, managed-resource ownership, duplicate policy, and consistency rules.
2. **Import to songs list:** import supported files into app-managed storage and display successful imports in a persistent songs list with a useful empty state.
3. **Basic playback:** start a song from the list and provide reliable play, pause, seek, end-of-song behavior, and minimum background continuation with one authoritative playback state.
4. **Library management:** remove songs safely after interaction with the current item and queue has a defined policy.
5. **Library expansion:** add album and artist browsing after real imported metadata is available to validate grouping behavior.
6. **Playback integration:** add queue modes, system controls, interruption and route-change handling, and restoration while preserving Basic Playback's minimum background continuation.

Each slice must leave the app in a coherent, testable state. Later slices must not be treated as prerequisites for validating an earlier one unless a specification says so explicitly.

## Cross-feature decision ownership

This table locates each complete rule without restating it:

| Decision | Authoritative specification |
| --- | --- |
| Supported formats, canonical metadata, and durable song identity | [Library foundation](library-foundation.md) |
| Duplicate import and unavailable-song restoration | [Local audio import](local-audio-import.md) |
| Song removal, including interaction with the current Basic Playback item | [Music library](music-library.md) |
| Single-song natural end and replay | [Basic playback](basic-playback.md) |
| Queue, repeat, shuffle, system controls, interruptions, routes, and restoration | [Playback integration](playback.md); unresolved while Proposed |
| Performance, capacity, and storage budgets | [Quality attributes](quality-attributes.md) |

## Status definitions

- **Proposed:** The direction is documented but unresolved questions may block implementation.
- **Active:** The behavior and acceptance criteria are approved for implementation.
- **Implemented:** The acceptance criteria are implemented, tested, and reflected in the current system documentation.
- **Superseded:** Another specification replaces this document; link to its replacement.

## Maintenance

- Resolve behavior-changing open questions before moving a specification to Active.
- Update a specification when user-visible behavior or acceptance criteria change.
- Update the implementation status only after verifying the documented acceptance criteria.
- Keep implementation steps and progress in execution plans rather than product specifications.
- Keep algorithms, schemas, framework choices, concrete types, and file layouts out of product specifications.
- State a complete behavior in one owning specification and link to it elsewhere.
