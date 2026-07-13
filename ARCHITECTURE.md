# Resona Architecture

This document is the system map for Resona.

## Product boundary

Resona is an offline-first local music player for iPhone and iPad. Its core product boundary is media that the user imports and keeps available locally. Accounts, subscriptions, streaming catalogs, and server-side services are outside that boundary.

The product direction is described in `README.md`. A feature listed there is planned, not implemented, unless it also appears in the current system map below.

## Current implementation

The repository is in its foundation stage and currently contains a single iOS application target, a unit-test target, and a UI-test target.

The application still presents the initial SwiftUI scaffold, and now includes the first implemented Library persistence foundation:

- `ResonaApp` is the composition root.
- It creates a disk-backed, versioned SwiftData `ModelContainer` using `ResonaMigrationPlan`.
- Schema V0 represents the original `Item`-only store. Schema V1 adds `LibrarySongRecord` while retaining `Item`, with a lightweight V0-to-V1 migration.
- It injects that container into `ContentView` through the SwiftUI environment.
- `ContentView` queries, inserts, and deletes `Item` records directly through SwiftData.
- `Item` contains only a timestamp.
- The Library domain defines stable song identity, normalized song values, content fingerprints, resource availability, duplicate candidates, and deterministic localized sorting.
- `SwiftDataLibraryRepository` is a model actor that owns library-record queries and mutations behind `LibraryRepository`. SwiftData records and `ModelContext` do not cross that boundary.
- `ManagedMediaStore` is an actor that owns versioned app-managed Audio, Artwork, and Staging directories. It provides staging locations, same-volume moves into identity-derived final filenames, complete byte comparison, availability resolution, explicit cleanup, and reconciliation of abandoned or unreferenced files.
- The Library import boundary now includes complete-file SHA-256 fingerprinting, security-scoped and coordinated source reads, content-based container and codec validation, canonical metadata and artwork normalization, and typed per-file outcomes.
- `AudioImportService` is an actor that serializes one import operation, reconciles managed storage before work, processes selected files sequentially, cooperatively cancels unfinished files, reports progress through an async stream, and supports one-file retry.
- Import coordination confirms available duplicates with a complete byte comparison, restores unavailable matching records without changing identity, and removes newly committed resources when persistence fails.
- The repository exposes the active managed filenames needed for reconciliation without exposing SwiftData records.
- The import service is not yet composed into `ResonaApp`; file selection, import-session presentation, and the Songs List remain the next implementation stage. No library UI, playback, queue, background audio, or system media-control functionality exists yet.

### Current runtime flow

```text
ResonaApp
  -> creates versioned ModelContainer(Item, LibrarySongRecord)
  -> migrates an existing Item-only store without deleting Item data
  -> presents ContentView
  -> injects ModelContext through the SwiftUI environment

ContentView
  -> reads Item values with @Query
  -> inserts and deletes Item values with ModelContext

SwiftData
  -> persists Item values on device
  -> can persist LibrarySongRecord through SwiftDataLibraryRepository

LibraryRepository
  -> maps LibrarySongRecord to Sendable Library domain values
  -> derives availability through LibraryResourceResolving
  -> reports active audio and artwork filenames for reconciliation

ManagedMediaStore
  -> owns ManagedLibrary/v1 Audio, Artwork, and Staging directories
  -> resolves only complete regular managed resources
  -> removes abandoned staging work and unreferenced final resources

AudioImportService (implemented, not yet installed by ResonaApp)
  -> reconciles repository references with managed storage
  -> coordinates and fingerprints external source reads
  -> validates staged audio and normalizes metadata
  -> confirms duplicates or restores unavailable identities
  -> commits managed resources before repository persistence
  -> streams deterministic progress and typed per-file results
```

### Current source map

```text
Resona/
├── ResonaApp.swift                Application entry point and container composition
├── ContentView.swift              Current scaffold user interface
├── Item.swift                     Retained scaffold model and V0 schema
├── Library/
│   ├── Domain/                    Sendable song, identity, availability, and sorting values
│   ├── Import/                    Source access, fingerprinting, typed results, and import coordination
│   ├── Metadata/                  AVFoundation validation/reading and canonical normalization
│   ├── Persistence/               V1 record, migration plan, repository, and resource boundary
│   └── Storage/                   Managed resource staging, commit, cleanup, and reconciliation
└── Assets.xcassets                App icons, accent color, and visual assets

ResonaTests/                       Persistence, storage, import, media-adapter, and scaffold tests
ResonaUITests/                     UI-test target
```

The Library folders are established source boundaries inside the application target, not separate Swift packages. The import implementation is present behind protocols but is not reachable from the scaffold UI until app composition and Library presentation are added.

## Target architectural boundaries

The following boundaries are the intended direction for the planned product. They guide new feature placement but are not a claim that these components already exist.

```text
App composition
├── Library
│   ├── Import
│   ├── Metadata
│   └── Persistence
├── Playback
│   ├── Audio session
│   ├── Player
│   ├── Queue
│   └── Now Playing integration
└── Presentation
    ├── Library UI
    └── Player UI
```

### App composition

The app entry point owns construction and connection of long-lived dependencies. Feature views should consume dependencies through explicit interfaces or SwiftUI environment values rather than construct shared services themselves.

### Library

The Library boundary owns imported media and the user's browsable collection:

- Import coordinates file selection and copies successful imports into app-managed storage for durable offline access.
- Metadata reads and normalizes embedded metadata and artwork.
- Persistence stores library records and restoration data.

External files and metadata are untrusted boundary inputs. The implemented import boundary copies coordinated source bytes into staging while calculating a complete SHA-256 fingerprint, validates supported container and codec combinations with Apple media frameworks, and normalizes optional metadata before committing domain data. The initial library schema and non-destructive migration chain are established; later schema changes must extend that chain deliberately.

### Playback

The Playback boundary owns the authoritative playback state:

- Audio-session configuration and interruption handling
- Player lifecycle and transport commands
- Queue ordering, shuffle, and repeat behavior
- Lock Screen, Control Center, and remote-command integration
- Restoration of the previous queue and playback position

Playback must have one authoritative state owner. UI state may reflect playback state but must not become a second source of truth.

### Presentation

SwiftUI views render feature state and send user actions into feature boundaries. Views may own transient presentation state, but durable library state and authoritative playback state belong to their respective boundaries.

## Dependency direction

Until concrete modules are introduced, preserve this conceptual dependency direction:

```text
Presentation -> feature interfaces -> domain behavior
                                      ^
                                      |
                          Apple-framework adapters
```

- Presentation may depend on feature-facing types and interfaces.
- Domain behavior must not depend on SwiftUI views.
- Apple-framework details such as AVFoundation, MediaPlayer, file coordination, and SwiftData should remain behind the boundary that owns them when practical.
- Cross-feature communication should go through explicit feature interfaces, not direct access to another feature's internal storage or implementation types.
- Shared abstractions should be introduced only after a real shared responsibility exists.

These boundaries are invariants; the exact types, folder layout, and use of protocols remain implementation decisions until real product behavior requires them.

## State and persistence ownership

- SwiftUI owns short-lived presentation state.
- The Library boundary owns persisted media-library data.
- The Playback boundary owns live playback and queue state.
- The app composition layer owns the lifetime of shared services.
- SwiftData is the current persistence technology, but `ModelContext` should not become a general-purpose dependency passed through unrelated features.

The existing `Item` model remains scaffold data, not a music-library model. It is retained in schema V1 so the first library migration is additive and non-destructive. Removing it requires a separately approved migration decision.

`LibrarySongRecord` is the V1 persisted music-library model. `SwiftDataLibraryRepository` owns its `ModelContext` access and exposes immutable Library domain values. Resource availability is derived through `LibraryResourceResolving` rather than persisted as an independent source of truth.

`ManagedMediaStore` owns app-managed resources under the versioned `ManagedLibrary/v1` root. Staging and final directories share that root so accepted resources can move to final identity-derived filenames without crossing volumes. Reconciliation consumes the repository's active filename snapshot and removes abandoned staging work plus unreferenced final resources; it never treats file presence as a persisted library record.

`AudioImportService` owns the lifetime and cancellation of one active import task. It publishes immutable progress and terminal per-file outcomes through an async stream; the presentation owner that will consume those events remains part of the next stage.

## Platform integrations

Planned platform integrations belong to these boundaries:

| Apple framework or system surface | Owning boundary |
| --- | --- |
| SwiftUI | Presentation |
| SwiftData | Library persistence |
| File importer and security-scoped resources | Library import; coordinated security-scoped reading is implemented, picker presentation is planned |
| AVFoundation | Playback and metadata; import validation and metadata adapters are implemented behind Library interfaces |
| MediaPlayer and remote commands | Playback |
| Background audio capability | Playback and app composition |

Changes to capabilities, entitlements, signing, deployment targets, or background modes require explicit approval as defined in `AGENTS.md`.

## Architectural decisions not yet made

The repository does not yet establish:

- The concrete playback engine and its public interface
- Queue persistence and restoration semantics
- Whether existing source-folder boundaries should later become Swift packages
- App-level dependency-injection mechanics for Library services beyond the shared `ModelContainer`

Resolve these decisions when the corresponding product specification is written. Record decisions in this document when they change the system map; do not silently infer them from planned feature names.

## Keeping this document accurate

Update this document when a change:

- Adds, removes, or renames an architectural boundary
- Changes ownership of state, persistence, or a platform integration
- Introduces a new dependency direction or shared service
- Implements something currently described as planned or not implemented
- Resolves one of the undecided architectural questions above

Keep implementation details in code and task-specific plans. This document should remain a concise map of the system and its durable boundaries.
