# Product Specifications

Product specifications are the source of truth for user-visible behavior and acceptance criteria. They describe what Resona should do without prescribing implementation details owned by `ARCHITECTURE.md` or an execution plan.

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
| [Experience foundation](experience-foundation.md) | Active | Import, library, and Basic Playback feedback subsets verified |
| [Library foundation](library-foundation.md) | Active | Identity, storage, metadata, and consistency subset verified; removal deferred |
| [Local audio import](local-audio-import.md) | Active | Import to Songs List slice implemented and verified |
| [Music library](music-library.md) | Active | Songs List and playback-selection subsets verified; Library Management deferred |
| [Basic playback](basic-playback.md) | Implemented | Runtime, Audio background mode, automated suites, and physical background/lock behavior verified |
| [Playback integration](playback.md) | Proposed | Not started |

## Implementation readiness

The active specifications approve the remaining Foundation and Music Library work. Concrete SwiftData fields, managed-file layout, playback-engine boundaries, authoritative playback-state representation, and other type boundaries remain implementation decisions; an execution plan must record them before they are introduced and `ARCHITECTURE.md` must be updated when the current system map changes.

The current completed technical plans are [Import to Songs List Execution Plan](../execution-plans/import-to-songs-list.md) and [Basic Playback Execution Plan](../execution-plans/basic-playback.md).

Basic Playback is implemented, including its explicitly approved Audio background mode and minimum background continuation. Playback Integration remains Proposed; system Now Playing presentation, remote commands, queues, restoration, and broader interruption or route behavior owned by it are not part of Basic Playback and must not be claimed as implemented until its remaining decisions are resolved and it becomes Active.

## Recommended delivery slices

1. **Foundations:** resolve the shared experience direction, supported formats, durable song identity, metadata contract, managed-resource ownership, duplicate policy, and consistency rules.
2. **Import to songs list:** import supported files into app-managed storage and display successful imports in a persistent songs list with a useful empty state.
3. **Basic playback:** start a song from the list and provide reliable play, pause, seek, end-of-song behavior, and minimum background continuation with one authoritative playback state.
4. **Library management:** remove songs safely after interaction with the current item and queue has a defined policy.
5. **Library expansion:** add album and artist browsing after real imported metadata is available to validate grouping behavior.
6. **Playback integration:** add queue modes, system controls, interruption and route-change handling, and restoration while preserving Basic Playback's minimum background continuation.

Each slice must leave the app in a coherent, testable state. Later slices must not be treated as prerequisites for validating an earlier one unless a specification says so explicitly.

## Resolved cross-feature decisions

- **Supported audio:** The first release accepts validated, unprotected MP3, AAC or Apple Lossless in M4A/MP4 audio containers, and supported PCM audio in WAV or AIFF containers. Extensions alone do not establish validity.
- **Duplicate import:** Exact byte-identical content is skipped and reported as already imported when the existing managed resource is available. If the matching song is unavailable, re-import restores its managed resource while preserving its stable identity. Matching filenames or display metadata do not make different files duplicates.
- **Natural end:** Without a following queue item, playback stops at the end and retains the current song; the next Play restarts it from the beginning. With a following queue item, playback advances according to the queue and repeat policy.
- **Removal during playback:** Removing the current song stops playback and clears it from the current state and queue before deleting library resources. Removing another queued song removes all of its queue occurrences.

The owning specifications contain the complete behavior and acceptance criteria. This summary exists to make decisions that cross feature boundaries easy to discover.

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
