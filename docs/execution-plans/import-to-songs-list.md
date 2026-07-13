# Import to Songs List Execution Plan

## Status

In Progress

## Outcome

Implement the first production slice in which a user with an empty library can choose supported local audio files, import valid files into app-managed storage, and see successful songs in a deterministic persistent list after relaunch.

This plan converts the active product specifications into concrete implementation decisions. It does not activate or implement Basic Playback, queue behavior, library removal, or system playback integration.

## Source documents

- [Experience foundation](../product-specs/experience-foundation.md)
- [Library foundation](../product-specs/library-foundation.md)
- [Local audio import](../product-specs/local-audio-import.md)
- [Music library](../product-specs/music-library.md), Songs List stage
- [Architecture](../../ARCHITECTURE.md)
- [Engineering guidelines](../engineering-guidelines.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)

## Slice boundaries

### In scope

- A versioned SwiftData library-song record and domain representation
- App-managed audio and artwork directories
- Launch reconciliation for interrupted creation work and unreferenced managed files
- System multi-file selection using SwiftUI `fileImporter`
- Security-scoped and file-coordinated reads from selected URLs
- Complete-file fingerprinting, supported-audio validation, metadata normalization, duplicate handling, and unavailable-song restoration
- Sequential multi-file import with progress, safe cancellation, per-file outcomes, and retry
- Persistent Songs List, empty state, metadata fallbacks, artwork placeholder, and unavailable state
- Previews, unit and integration tests, critical UI tests, accessibility identifiers, and localization-ready strings

### Deferred

- Starting playback when a row is selected
- Current-song affordance and detailed player sheet
- Song removal and pending-removal cleanup
- Album, artist, search, queue, shuffle, repeat, system controls, and restoration
- Background audio capability or entitlement changes
- User-edited metadata and cross-device synchronization

Rows may expose stable identity internally, but they must not show a placeholder playback destination or claim that selection starts playback in this slice.

## Architectural shape

```text
ResonaApp
  -> constructs ModelContainer, LibraryStore, and AudioImportService
  -> installs shared app dependencies in the SwiftUI environment

LibraryView
  -> renders value-type LibrarySong summaries from LibraryStore
  -> presents fileImporter and creates an item-driven ImportSessionModel

LibraryStore (@MainActor, @Observable)
  -> owns load state and the displayed song snapshot
  -> calls LibraryRepository

ImportSessionModel (@MainActor, @Observable)
  -> owns progress, result, cancellation, and retry presentation state
  -> consumes events from AudioImportService and refreshes LibraryStore

AudioImportService (actor)
  -> serializes one import operation
  -> coordinates external access, validation, duplicate policy, and commit through repository and file-store boundaries

SwiftDataLibraryRepository (@ModelActor)
  -> owns ModelContext and persisted LibrarySongRecord values

ManagedMediaStore (actor)
  -> owns staging, final managed files, availability checks, and reconciliation
```

SwiftData model objects and `ModelContext` must not cross the persistence boundary. Presentation consumes immutable, `Sendable` domain values and typed outcomes. The import service performs file and media work away from the main actor; only `LibraryStore` publishes UI state.

## Persistence design

### Schema version

Represent the current unversioned `Item`-only store as `ResonaSchemaV0` version 1.0.0. Introduce `ResonaSchemaV1` version 2.0.0 and `ResonaMigrationPlan` with a lightweight V0-to-V1 stage at the app composition boundary.

`ResonaSchemaV1` contains both `Item` and `LibrarySongRecord`. Keeping `Item` preserves the current scaffold store and avoids an unauthorized destructive model change. `ContentView` stops displaying scaffold items, but `Item.swift` and its stored rows remain untouched. Removing `Item` requires a later approved migration.

Before adopting the versioned container, add a migration test that creates a store with the current `Item` schema and opens it with `ResonaSchemaV1`. If SwiftData cannot perform the additive migration without deleting data, stop implementation and revise the migration approach; never delete or recreate the user's store as fallback.

### LibrarySongRecord

| Field | Swift representation | Rules |
| --- | --- | --- |
| `id` | `UUID`, unique | App-assigned stable identity; never derived from content or metadata. |
| `contentDigest` | `String` | Lowercase SHA-256 of the complete source bytes. |
| `byteCount` | `Int64` | Complete source byte count paired with the digest. |
| `managedAudioFilename` | `String` | Relative filename only; no absolute sandbox URL is persisted. |
| `title` | `String` | Persisted normalized non-empty title. |
| `artist` | `String?` | Source value only; “Unknown Artist” is presentation fallback. |
| `album` | `String?` | Source value only; “Unknown Album” is presentation fallback. |
| `durationSeconds` | `Double?` | Derived from the validated managed audio candidate. |
| `managedArtworkFilename` | `String?` | Relative filename for validated optional artwork. |

Resource availability is not persisted as an independent truth. `SwiftDataLibraryRepository` combines each record with `ManagedMediaStore` availability when producing a `LibrarySong` snapshot. A record with a missing final audio file becomes `.unavailable`.

Do not add speculative queue, playback, removal, album-grouping, or search fields in this schema.

### Domain values

- `LibrarySong`: stable ID, normalized metadata, duration, artwork URL when available, and `SongAvailability`.
- `SongAvailability`: `.available(audioURL)` or `.unavailable`.
- `ContentFingerprint`: SHA-256 digest and byte count.
- `ImportFileResult`: source display name plus `.imported(id)`, `.restored(id)`, `.alreadyImported(id)`, `.warning(id, warnings)`, `.failed(reason)`, or `.cancelled`.
- `ImportFailureReason` and `ImportWarning`: typed cases with no user-facing prose. Presentation maps them to localized resources and actions.

Inject the UUID generator into import coordination so identity behavior is deterministic in tests. Production uses `UUID.init`.

## Managed storage design

Use an injected root URL whose production value is inside Application Support:

```text
Application Support/ManagedLibrary/v1/
├── Audio/
│   └── <song UUID>.<validated canonical extension>
├── Artwork/
│   └── <song UUID>.<validated artwork extension>
└── Staging/
    └── <operation UUID>/
        └── <candidate UUID>.partial
```

- Store all staging and final resources on the same volume so the final move can be atomic.
- Derive the final filename from stable song identity and validated media type, never from the untrusted source filename.
- Keep default Application Support backup behavior in this slice; do not mark imported media as purgeable or excluded from backup without a separate product decision.
- `ManagedMediaStore` accepts an injected root URL so tests use isolated temporary directories.
- A failed commit removes its staging and final candidate resources. Cleanup failures remain discoverable by reconciliation.
- Launch reconciliation removes abandoned staging directories and final audio or artwork files that have no active record. Reconciliation runs before the first library snapshot and before a new import operation.
- Reconciliation never deletes a file referenced by an active record and is serialized with import mutations by the service actors.

## Import pipeline

Process selected files sequentially for the first release. This makes cancellation, progress, storage pressure, and same-operation duplicate behavior deterministic without reducing multi-file success isolation.

For each selected URL:

1. Check cancellation before starting the file.
2. Start security-scoped access and coordinate a read with `NSFileCoordinator`; always end access with `defer`.
3. Stream the complete external file into the operation's staging directory while calculating SHA-256 and byte count. Check cancellation between chunks.
4. Validate the staged bytes rather than trusting the filename extension or picker content type:
   - identify MP3, M4A/MP4, WAV, or AIFF container data;
   - require a supported MP3, AAC, Apple Lossless, or PCM audio stream as specified;
   - reject protected, corrupt, video-only, unsupported-codec, and unreadable media;
   - derive duration from the validated asset.
5. Query duplicate candidates by digest and byte count:
   - when a candidate's managed audio is available, compare both complete files byte-for-byte before returning Already Imported;
   - when a candidate is unavailable, use the persisted digest and byte count as the recovery evidence and preserve its identity;
   - because the operation is sequential, earlier successes in the same operation are visible to later candidates.
6. Normalize title, artist, album, duration, and optional artwork. Decode artwork before accepting it; corrupt artwork becomes a warning and placeholder. Perform best-effort artwork extraction in the current file operation for this slice rather than introducing an unfinished background enrichment state.
7. Move the complete staged audio and optional artwork atomically to identity-derived final paths.
8. Insert a new record or update the matching unavailable record. Only after persistence succeeds is the result committed.
9. If persistence fails, remove the just-moved files. Reconciliation handles any cleanup that cannot finish immediately.
10. Publish one terminal result and advance completed-file progress.

`AudioImportService` exposes an `AsyncStream<ImportEvent>` or equivalent single-consumer async sequence containing progress and terminal per-file results. It owns the operation task, and cancellation is cooperative rather than represented as an error.

Retry retains only the failed file URL in the in-memory import session. It starts a fresh candidate transaction for that file and never repeats successful files. If security-scoped access cannot be reacquired, presentation changes the primary action to Choose Files.

## Validation and metadata adapters

Keep Apple-framework details behind focused interfaces:

- `AudioValidating`: validates container, audio codec, protection status, playable audio track, and duration using AVFoundation and AudioToolbox as needed.
- `AudioMetadataReading`: reads common title, artist, album, and artwork metadata from the staged candidate.
- `ContentFingerprinting`: streams SHA-256 using CryptoKit while copying.
- `ManagedMediaStoring`: stages, commits, compares, checks availability, and reconciles files.
- `LibraryRepository`: fetches active summaries and duplicate candidates, inserts songs, and restores unavailable songs.

Use real adapters in integration tests with small checked-in fixtures. Use protocol fakes only for deterministic error, cancellation, and storage-failure paths that are impractical to trigger reliably.

## SwiftUI state and presentation

The SwiftUI structure follows native state ownership:

- `ResonaApp` owns the shared `LibraryStore` and `AudioImportService` and installs them with typed environment injection.
- `ContentView` remains the app root and hosts a single `NavigationStack` containing `LibraryView`; no `TabView` or router abstraction is needed yet.
- `LibraryStore` is `@MainActor @Observable` and owns `LibraryLoadState`: idle, loading, loaded, or failed.
- `LibraryView` starts initial load with `.task`, renders a SwiftUI `List` with stable song IDs, and uses `ContentUnavailableView` for the loaded empty state.
- The primary Choose Files action and toolbar import action drive the same local `fileImporter` presentation state.
- A returned selection creates one local `ImportSessionModel`, presented with `.sheet(item:)`. Do not represent import progress, results, and errors as separate sheet booleans.
- `ImportSessionModel` is `@MainActor @Observable`, consumes import events, owns progress/results/cancel/retry state, and refreshes `LibraryStore` after committed results.
- `ImportSheet` owns its Cancel, Retry, Choose Files, Done, and dismissal behavior. Interactive dismissal is disabled while import work is active.
- `SongRow` receives an immutable `LibrarySong`; it displays artwork or a standard placeholder, title, artist fallback, optional duration, and a labeled Unavailable state that does not rely on color.
- Do not attach a playback `NavigationLink` or button until Basic Playback is Active. The row remains accessible as content rather than pretending to navigate.

Add deterministic previews for:

- empty library;
- populated library with complete and missing metadata;
- unavailable song;
- importing multiple files;
- mixed import results with warning, duplicate, failure, and cancellation.

All icon-only controls require accessibility labels. Add stable accessibility identifiers only where UI tests need them; user-visible wording remains localization-ready through a string catalog or `LocalizedStringResource`.

## Sorting

Produce the displayed snapshot in one place, not independently in each view:

1. Compare normalized display titles using localized standard comparison.
2. When titles compare equally, compare stable UUID strings as the deterministic tie-breaker.

Tests set a fixed locale where exact ordering is asserted. Changing device locale may change primary title ordering but never makes the order unstable within that locale.

## Test design

### Unit tests with Swift Testing

| Area | Required coverage |
| --- | --- |
| Metadata normalization | Embedded title precedence, filename fallback, Unknown Title fallback, optional artist/album, invalid artwork warning. |
| Sorting | Localized title order and stable-ID tie-breaker with a fixed locale. |
| Fingerprinting | Same bytes match; changed bytes or byte count differ; cancellation leaves no completed fingerprint. |
| Import reducer/session | Progress counts, mixed terminal outcomes, cancellation is not failure, retry targets one file. |
| Import service | Successful import, unsupported/corrupt input, duplicate available song, unavailable restoration preserving ID, persistence failure cleanup, mixed multi-file operation. |
| Reconciliation | Abandoned staging and unreferenced final files are removed; referenced files are preserved. |
| Repository | Round-trip normalized records, unavailable derivation, duplicate-candidate lookup, restoration updates resource without changing identity. |

Repository tests use an in-memory SwiftData container. Relaunch and migration tests use an isolated temporary on-disk container because container recreation is the behavior being verified.

### Media fixtures

Check in the smallest legally generated fixtures needed for supported MP3, AAC M4A, Apple Lossless M4A, PCM WAV, and PCM AIFF plus corrupt, unsupported-codec, and video-only cases. Document how each fixture was generated. Keep fixtures out of the production target when target membership permits it.

### UI tests

- Empty launch explains offline copying and exposes the primary Choose Files action.
- A test-seeded persisted library renders deterministic songs and metadata fallbacks after relaunch.
- An unavailable seeded song has a visible non-color status and does not expose playback navigation.
- An injected test import session verifies progress, safe Cancel, mixed results, and per-file recovery actions without automating the system Files app.
- The primary library journey remains usable at an accessibility text size. Use accessibility identifiers for assertions and manually inspect VoiceOver order on Simulator.

Use debug-only launch configuration and dependency injection for seeded UI states. Production behavior must not branch on UI-test arguments outside `DEBUG`. The system Files picker handoff and a real fixture import receive a separate manual Simulator validation because controlling Files is outside Resona and is not a reliable app UI test boundary.

### Verification commands

- Run `./scripts/check.sh` after each business-logic milestone.
- Run targeted unit tests while developing import and persistence behavior.
- Run `./scripts/check-all.sh` before declaring the user-facing slice complete.
- Build and launch on an iPhone Simulator and an iPad Simulator with the latest installed iOS runtime.
- Inspect empty, populated, mixed-result, large Dynamic Type, Dark Mode, and unavailable states.
- Verify a real import, picker cancellation, active cancellation, relaunch persistence, duplicate reporting, and offline availability interactively.

## Implementation sequence

### 1. Domain, schema, and repository — Completed

- Add value types, `LibrarySongRecord`, versioned schema, migration plan, and repository boundary.
- Preserve `Item` in the schema and add the additive migration test.
- Add repository and sorting tests.
- Exit criterion: current scaffold store opens without data deletion and song records round-trip through the repository.

### 2. Managed storage and reconciliation

- Add managed directory creation, staging, atomic commit, byte comparison, availability, cleanup, and reconciliation.
- Add temporary-directory tests for every cleanup boundary.
- Exit criterion: interruption at each simulated boundary converges without a playable partial record or untracked partial file.

### 3. Validation, metadata, and import coordination

- Add CryptoKit fingerprinting, Apple-framework validation, metadata normalization, typed results, sequential multi-file orchestration, cancellation, retry, duplicate handling, and unavailable restoration.
- Add media fixtures and unit/integration coverage.
- Exit criterion: every Local Audio Import acceptance case has deterministic automated coverage where technically practical.

### 4. Library and import UI

- Replace scaffold item presentation with LibraryView, empty state, Songs List, file importer, ImportSheet, SongRow, localization-ready strings, accessibility, and previews.
- Keep playback and removal affordances out of scope.
- Exit criterion: empty-to-import-to-persistent-list works on iPhone and iPad without placeholder destinations.

### 5. Delivery verification and documentation

- Add critical UI tests and perform interactive accessibility and real-file checks.
- Run the full required validation.
- Update `ARCHITECTURE.md` from scaffold state to the implemented boundaries, source map, runtime flow, state ownership, schema version, and managed storage.
- Change implementation statuses only for acceptance criteria actually verified; keep Basic Playback and Playback Integration Proposed.
- Exit criterion: the affected target builds without new warnings, required tests pass, documentation matches runtime, and no generated build artifacts are tracked.

## Definition of ready for coding

- The product behavior required by this slice is Active.
- This plan fixes the initial schema, managed directory layout, dependency direction, transaction boundaries, UI state ownership, and test layers.
- No deployment target, bundle identifier, signing setting, entitlement, background mode, or third-party dependency change is required.
- No existing model or file is deleted. Removing the scaffold `Item` remains a separately approved migration task.

Implementation may begin with sequence 1. Any discovery that requires deleting data, changing an entitlement, accepting an additional media family, or weakening the recovery contract must pause for approval and update the owning specification or architecture document first.
