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

This dependency order describes rule ownership. It does not prescribe an
implementation sequence or require completing every library feature before
import or playback.

## Specifications

| Specification | Lifecycle status |
| --- | --- |
| [Experience foundation](experience-foundation.md) | Active |
| [Library foundation](library-foundation.md) | Active |
| [Local audio import](local-audio-import.md) | Active |
| [Music library](music-library.md) | Active |
| [Basic playback](basic-playback.md) | Implemented |
| [Playback integration](playback.md) | Active |
| [Quality attributes](quality-attributes.md) | Active |

Lifecycle status records whether behavior is approved or fully accepted.
Delivery progress and verification evidence belong in the
[execution-plan index](../execution-plans/README.md); the current implementation
map belongs in `ARCHITECTURE.md`.

## Product increments

These increments describe coherent product outcomes, not a current delivery
schedule or implementation sequence:

- **Foundations:** shared experience direction, supported formats, durable song
  identity, metadata contract, managed-resource ownership, duplicate policy,
  and consistency rules
- **Import to songs list:** app-managed offline copies presented in a persistent
  songs list with a useful empty state
- **Basic playback:** reliable play, pause, seek, natural-end, and minimum
  background behavior with one authoritative playback state
- **Library management:** safe song removal with defined current-item and queue
  behavior
- **Library expansion:** album and artist browsing informed by real imported
  metadata
- **Playback integration:** queue modes, system controls, interruption and route
  handling, and silent restoration

Each increment defines coherent, independently testable user value. A later
increment does not become a prerequisite for accepting an earlier one unless an
owning specification says so explicitly.

## Cross-feature decision ownership

This table locates each complete rule without restating it:

| Decision | Authoritative specification |
| --- | --- |
| Supported formats, canonical metadata, and durable song identity | [Library foundation](library-foundation.md) |
| Duplicate import and unavailable-song restoration | [Local audio import](local-audio-import.md) |
| Song removal, including interaction with the current Basic Playback item | [Music library](music-library.md) |
| Single-song natural end and replay | [Basic playback](basic-playback.md) |
| Queue, repeat, shuffle, system controls, interruptions, routes, and restoration | [Playback integration](playback.md) |
| Performance, capacity, and storage budgets | [Quality attributes](quality-attributes.md) |

## Status definitions

- **Proposed:** The direction is documented but unresolved questions may block implementation.
- **Active:** The behavior and acceptance criteria are approved for implementation.
- **Implemented:** The acceptance criteria are implemented, tested, and reflected in the current system documentation.
- **Superseded:** Another specification replaces this document; link to its replacement.

## Maintenance

- Resolve behavior-changing open questions before moving a specification to Active.
- Update a specification when user-visible behavior or acceptance criteria change.
- Update lifecycle status only after verifying the documented acceptance criteria.
- Keep implementation steps and progress in execution plans rather than product specifications.
- Keep algorithms, schemas, framework choices, concrete types, and file layouts out of product specifications.
- State a complete behavior in one owning specification and link to it elsewhere.
