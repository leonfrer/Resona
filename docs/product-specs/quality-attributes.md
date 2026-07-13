# Quality Attributes

## Status

Active

## Purpose

Define cross-feature performance, capacity, and storage expectations without prescribing algorithms, framework types, or source structure.

These are approved qualification targets. Implementation and verification coverage is tracked per delivery slice.

## Qualification envelope

The first release is designed and tested for:

- A library containing 10,000 songs.
- One import selection containing up to 100 files.
- An individual supported audio file up to 4 GiB.
- Managed media whose aggregate size is limited by available device storage rather than an artificial Resona quota.

These values are qualification targets, not automatic rejection thresholds. A lower product limit requires a user-visible decision in the owning feature specification. Larger workloads may work but are not release-qualified until this document is updated.

## Responsiveness budgets

Measure release builds on the oldest device class supported for the release candidate. Record the device, OS, dataset, build, and measurement method with the result.

- With 10,000 persisted songs and no migration or reconciliation work pending, a warm launch makes the Songs List usable within 2 seconds in at least 9 of 10 measured runs.
- Direct controls acknowledge input within 100 milliseconds. Work that cannot finish within 500 milliseconds exposes progress or a clear busy state without blocking navigation or playback controls.
- A 30-second scroll through the 10,000-song list has no main-thread hang of 100 milliseconds or longer and does not show sustained visible hitching.
- Import, metadata reading, duplicate detection, and storage reconciliation do not block the main actor with file-sized work.
- Reading a 4 GiB import candidate does not require memory proportional to the file size. The peak additional memory attributable to file-content processing stays within 64 MiB, excluding system media-decoder and decoded-artwork allocations.
- Canceling an import updates presentation promptly and stops pending work. In-progress work reaches a safe cancellation boundary within 1 second after the active system file or media operation returns control.
- Playback control remains responsive while library loading, import, or reconciliation is active.

Performance regressions are release blockers when they exceed a budget reproducibly. A temporary exception must identify the measured result, user impact, owner, and removal milestone.

## Storage policy

- Successfully imported audio and extracted artwork are durable app-managed user data. Resona does not evict them automatically to reclaim space.
- The original external file is never counted as Resona-managed storage and is never modified or deleted.
- Temporary import data is not durable user content. It is removed after success, failure, or cancellation and reconciled after interruption.
- Before starting a copy whose size is known, Resona requires enough available capacity for that copy plus 256 MiB of safety headroom. If capacity falls below the requirement during import, the file fails cleanly and committed songs remain intact.
- Database records remain small relative to media. Audio and artwork bytes are stored as managed files rather than database blobs.
- Managed audio and artwork remain eligible for device backup because Resona cannot assume the original source is still available. Temporary staging data must not be relied on for backup or restoration.
- Removing a song releases its app-managed audio and artwork according to the Music Library removal policy. Deleting the app removes all Resona-managed data through normal iOS behavior.
- Resona does not silently transcode imported audio merely to reduce storage. Any future optimization, cache, or user-selectable storage policy requires its own product decision.

## Verification

- Maintain deterministic generated datasets for 1,000 and 10,000 song records without checking large media collections into the repository.
- Use a sparse or generated local file for large-file memory and cancellation checks when the media behavior under test does not require valid encoded audio.
- Record launch timing, scrolling hitch evidence, peak memory, free-space behavior, and cleanup results in the execution plan for the slice that first implements or materially changes them.
- Run performance checks outside ordinary unit-test assertions unless the check is deterministic enough for CI. CI should detect functional regressions; release qualification records device performance evidence.

## Acceptance criteria

- The release candidate meets the qualification envelope and responsiveness budgets on its recorded reference device.
- Importing large files never scales process memory with the full file size and never exposes a partial song as playable.
- Insufficient space produces actionable feedback and leaves existing songs and the original file unchanged.
- Relaunch cleanup removes abandoned temporary data without removing active managed media.
- The app never automatically evicts durable managed media or silently changes its encoding.

## Related documents

- [Product specifications](index.md)
- [Library foundation](library-foundation.md)
- [Local audio import](local-audio-import.md)
- [Music library](music-library.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
