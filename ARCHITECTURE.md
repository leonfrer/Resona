# Resona Architecture

This document is the system map for Resona.

## Product boundary

Resona is an offline-first local music player for iPhone and iPad. Its core product boundary is media that the user imports and keeps available locally. Accounts, subscriptions, streaming catalogs, and server-side services are outside that boundary.

The product direction is described in `README.md`. A feature listed there is planned, not implemented, unless it also appears in the current system map below.

## Current implementation

The repository now contains the Import to Songs List slice, the implemented Basic Playback runtime, the implemented Library Management runtime, and the Playback Integration runtime in a single iOS application target, a unit-test target, and a UI-test target. The approved Audio background mode and hands-on background and locked-device audio behavior are verified. Playback Integration queue, system-state projection, interruption and route policy, persistence, silent restoration, and UI behavior have automated Simulator coverage; physical-device Lock Screen, Control Center, headset, route, and interruption acceptance remains pending in its active execution plan.

- `ResonaApp` is the composition root.
- It creates a disk-backed, versioned SwiftData `ModelContainer` using `ResonaMigrationPlan`.
- It constructs the managed-media store, Library repository, shared mutation gate, audio-import and removal services, playback item provider, AVFoundation playback adapters, shared `LibraryStore`, and application-lifetime `PlaybackStore`, then installs presentation dependencies in the SwiftUI environment.
- Schema V0 represents the original `Item`-only store. Schema V1 adds `LibrarySongRecord`, and Schema V2 adds `LibrarySongRemovalRecord`, while retaining `Item` through a verified lightweight V0-to-V1-to-V2 migration chain.
- `ContentView` hosts one `NavigationStack` rooted at `LibraryView`; it no longer presents or mutates scaffold `Item` values.
- `Item` contains only a timestamp.
- The Library domain defines stable song identity, normalized song values, content fingerprints, resource availability, duplicate candidates, and deterministic localized sorting.
- `SwiftDataLibraryRepository` is a model actor that owns library-record queries and mutations behind `LibraryRepository`, including fresh stable-ID lookup for playback and the atomic active-record-to-pending-removal transaction. Pending removals are excluded from active lookup and duplicate matching while retaining managed-resource ownership until idempotent finalization. SwiftData records and `ModelContext` do not cross that boundary.
- `ManagedMediaStore` is an actor that owns versioned app-managed Audio, Artwork, and Staging directories. It provides staging locations, same-volume moves into identity-derived final filenames, complete byte comparison, availability resolution, explicit cleanup, and reconciliation of abandoned or unreferenced files.
- The Library import boundary now includes complete-file SHA-256 fingerprinting, security-scoped and coordinated source reads, content-based container and codec validation, canonical metadata and artwork normalization, and typed per-file outcomes.
- `LibraryMutationGate` is an actor that grants one explicit reservation across import, removal, retry, and reconciliation work. Busy operations return without interleaving repository or managed-storage mutations, and reservations are released after success, failure, or cancellation.
- `LibraryRemovalService` is an actor that establishes durable removal intent, deletes managed audio and artwork idempotently, finalizes tombstones, supports targeted retry, and reconciles pending removals before general orphan cleanup.
- `AudioImportService` is an actor that serializes one import operation, holds the shared mutation reservation through its async stream, runs ordered removal and managed-storage reconciliation before work, processes selected files sequentially, cooperatively cancels unfinished files, reports progress, and supports one-file retry.
- Import coordination confirms available duplicates with a complete byte comparison, restores unavailable matching records without changing identity, and removes newly committed resources when persistence fails.
- The repository exposes the active and pending-removal managed filenames needed for reconciliation without exposing SwiftData records.
- `LibraryStore` owns library loading and removal-presentation state, publishes immutable, deterministically sorted song snapshots, runs launch reconciliation before its first fetch, coordinates removal through `LibraryRemoving`, refreshes only from the repository, and retains a deterministic queue of retryable cleanup issues.
- `LibraryView` presents the Songs List, offline-copy empty state, loading and recovery states, toolbar import action, reusable system multi-file importer, available-row playback actions, row-level Remove actions, unavailable-row Re-import, item-driven removal confirmation and feedback, and the persistent current-song surface.
- `ImportSessionModel` consumes import events and owns one operation's progress, results, cancellation, Choose Files recovery, and one-file retry. `ImportSheet` remains presented while active and owns its actions and dismissal.
- `SongRow` displays artwork or a standard placeholder, normalized title, artist fallback, optional duration, labeled unavailable state, and per-identity removal progress. Only available rows become playback buttons, and a row is disabled while its removal request is active.
- `LibraryPlaybackItemProvider` maps freshly resolved `LibrarySong` values into immutable Playback input, including ordered batch hydration for queue presentation and restoration, without exposing SwiftData, managed storage, or import implementation types.
- `PlaybackStore` is the sole live owner of the current item, mutually exclusive phase, elapsed position, playable duration, failure, selection generation, active engine session, queue, traversal, history, shuffle, repeat, and temporary removal-selection blocks. It serializes transport commands, performs bounded playable-candidate resolution, rejects blocked identities, invalidates matching in-flight resolution, and ignores stale selection, restoration, and tagged engine events.
- `PlaybackRemovalInvalidating` is the narrow main-actor Library-to-Playback boundary for purging one identity from live and persisted queue state before deletion, stopping and clearing a matching current item, and later removing the temporary block without exposing Playback internals to Library persistence or storage.
- `AVAudioPlayerEngine` owns one local `AVAudioPlayer`, its retained delegate bridge, tagged event stream, and position publication. `AVAudioSessionController` configures the playback category, defers explicit activation until playback, deactivates on silent states, and maps interruption and external-output-disconnection notifications into typed events; `PlaybackStore` owns the resulting pause and conditional-resume decisions.
- `MPNowPlayingController` publishes canonical metadata, artwork, position, rate, and queue location. `MPRemoteCommandController` registers the supported system commands once, disables unsupported commands, reflects current capabilities, and forwards accepted commands to `PlaybackStore` on the main actor.
- `FilePlaybackRestorationStore` atomically persists one versioned Playback-owned snapshot under Application Support. Restoration resolves fresh Library values, sanitizes queue state, prepares and seeks without activating the audio session, and always restores as non-playing.
- `CurrentSongBar` and item-driven `PlayerView` render shared Playback state and send commands without creating a second player or changing transport merely through presentation. `PlayerView` adds previous, next, shuffle, repeat, and a read-only queue; resource recovery reuses the Library import presentation.
- Confirmed removal invokes playback invalidation and a persisted queue flush before the durable repository transaction, refreshes the authoritative Library snapshot after acceptance, and removes the temporary playback block after that identity can no longer resolve.

### Current runtime flow

```text
ResonaApp
  -> creates V2 versioned ModelContainer, ManagedMediaStore,
     SwiftDataLibraryRepository, LibraryMutationGate,
     AudioImportService, LibraryRemovalService, LibraryStore,
     LibraryPlaybackItemProvider, AVAudioPlayerEngine,
     AVAudioSessionController, MPNowPlayingController,
     MPRemoteCommandController, FilePlaybackRestorationStore,
     and PlaybackStore
  -> migrates an existing Item-only store without deleting Item data
  -> installs the model container plus Library and Playback dependencies

ContentView
  -> hosts NavigationStack -> LibraryView
  -> initiates one silent Playback restoration
  -> synchronizes the engine position when active and flushes restoration state
     when leaving the active scene phase

LibraryView
  -> starts the initial LibraryStore load
  -> renders empty, failure, or deterministic Songs List state
  -> sends the selected stable ID plus visible ordered IDs to PlaybackStore
  -> presents Remove for every row and Re-import for unavailable rows
  -> confirms consequences and renders deterministic retryable removal feedback
  -> presents reusable import flow, CurrentSongBar, and item-driven PlayerView

LibraryStore / LibraryRemovalService
  -> prevent repeated removal requests for one stable identity
  -> establish playback invalidation before beginning durable removal
  -> refresh active songs from LibraryRepository after durable acceptance
  -> retain cleanup issues separately from the active Songs List
  -> target pending cleanup through Try Again without restoring the song

PlaybackStore
  -> snapshots one authoritative queue and freshly resolves selected or
     navigated IDs through LibraryPlaybackItemProvider
  -> prepares one tagged engine session and activates audio before Play
  -> owns play, pause, seek, previous, next, shuffle, repeat, retry,
     natural completion, failure, interruption, route, and stale-event rules
  -> temporarily blocks a removal identity and invalidates matching current or
     in-flight state through PlaybackRemovalInvalidating
  -> projects Now Playing metadata and remote-command capabilities
  -> restores a sanitized queue and position without activating or playing

AVAudioPlayerEngine / AVAudioSessionController
  -> adapt one managed local URL and the iOS playback audio session
  -> publish tagged position, completion, failure, interruption, and
     external-output-disconnection events
  -> never expose AVFoundation objects to Playback presentation

MPNowPlayingController / MPRemoteCommandController
  -> adapt PlaybackStore projections to MediaPlayer system surfaces
  -> never own transport state or call AudioPlaybackEngine directly

FilePlaybackRestorationStore
  -> atomically persists one versioned queue and position snapshot
  -> remains separate from SwiftData Library persistence

ImportSessionModel
  -> consumes AudioImportService events
  -> publishes progress, mixed per-file results, cancellation, and retry state
  -> refreshes LibraryStore after committed results

SwiftData
  -> persists Item values on device
  -> persists active LibrarySongRecord and pending LibrarySongRemovalRecord
     values through SwiftDataLibraryRepository

LibraryRepository
  -> maps LibrarySongRecord to Sendable Library domain values
  -> derives availability through LibraryResourceResolving
  -> freshly resolves one stable identity for Playback
  -> atomically replaces an accepted active identity with pending cleanup intent
  -> reports active and pending-removal filenames as owned resources

ManagedMediaStore
  -> owns ManagedLibrary/v1 Audio, Artwork, and Staging directories
  -> resolves only complete regular managed resources
  -> removes abandoned staging work and unreferenced final resources

LibraryMutationGate / LibraryRemovalService
  -> serialize import, removal, retry, and reconciliation mutations
  -> retry pending-removal cleanup in deterministic identity order
  -> preserve failed cleanup ownership in durable tombstones
  -> reconcile genuinely unreferenced resources only after pending removals

AudioImportService
  -> holds one shared mutation reservation across an import operation
  -> runs ordered pending-removal and managed-storage reconciliation
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
├── ContentView.swift              Application navigation root
├── Item.swift                     Retained scaffold model and V0 schema
├── Library/
│   ├── Coordination/              Shared Library mutation serialization
│   ├── Domain/                    Sendable song, identity, availability, and sorting values
│   ├── Import/                    Source access, fingerprinting, typed results, and import coordination
│   ├── Metadata/                  AVFoundation validation/reading and canonical normalization
│   ├── Persistence/               V2 records, migration plan, repository, and resource boundary
│   ├── Presentation/              Library state, removal feedback, Songs List, import UI, and rows
│   ├── Removal/                   Removal boundary, cleanup, retry, and ordered reconciliation
│   └── Storage/                   Managed resource staging, commit, cleanup, and reconciliation
├── Playback/
│   ├── Domain/                    Current item, queue, repeat, restoration, system state, phase, and failures
│   ├── Engine/                    Playback/audio-session interfaces and AVFoundation adapters
│   ├── Integration/               MediaPlayer Now Playing and remote-command adapters
│   ├── Library/                   Stable-ID provider and removal-invalidation boundaries
│   ├── Persistence/               Versioned atomic playback-restoration storage
│   └── Presentation/              PlaybackStore, CurrentSongBar, PlayerView, and formatting
└── Assets.xcassets                App icons, accent color, and visual assets

ResonaTests/                       Library, Playback queue/state-machine, adapter, persistence, and presentation tests
ResonaUITests/                     Import, Library, Basic Playback, queue, and silent-restoration UI journeys
```

The Library and Playback folders are established source boundaries inside the application target, not separate Swift packages. Playback consumes canonical Library values only through `PlaybackItemProviding`; Library removal can affect live Playback state only through `PlaybackRemovalInvalidating`. Presentation reaches feature behavior through feature-facing state and interfaces.

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

The implemented Playback runtime uses `PlaybackStore` as that owner and `AVAudioPlayer` behind `AudioPlaybackEngine` for one managed local song at a time. `PlaybackQueue` is a pure value owning base order, active traversal, bounded history, shuffle, and repeat decisions, while every transition to audible playback freshly resolves Library availability. Engine events carry a session ID so replaced sessions cannot mutate current state. `AudioSessionControlling` isolates activation and typed interruption or route events. MediaPlayer controllers consume store projections and forward commands without owning transport state. `PlaybackRemovalInvalidating` purges live and persisted references before Library deletion. A versioned file snapshot restores queue and position silently and independently of SwiftData.

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
- The Playback boundary owns live playback and queue state plus its versioned restoration snapshot.
- The app composition layer owns the lifetime of shared services.
- SwiftData is the current persistence technology, but `ModelContext` should not become a general-purpose dependency passed through unrelated features.

The existing `Item` model remains scaffold data, not a music-library model. It is retained through schema V2 so the migration chain remains additive and non-destructive. Removing it requires a separately approved migration decision.

`LibrarySongRecord` is the active persisted music-library model. `LibrarySongRemovalRecord` is the minimal V2 pending-cleanup intent containing the former identity, display title, and managed filenames. `SwiftDataLibraryRepository` owns their `ModelContext` access and exposes immutable Library domain values. Resource availability is derived through `LibraryResourceResolving` rather than persisted as an independent source of truth. `LibraryRemovalService` owns managed-resource cleanup, tombstone finalization, explicit retry, and launch reconciliation. `LibraryStore` invokes it through `LibraryRemoving`, supplies the narrow playback-invalidation callbacks, and publishes transient request progress and retryable feedback without becoming a second persistence source.

`ManagedMediaStore` owns app-managed resources under the versioned `ManagedLibrary/v1` root. Staging and final directories share that root so accepted resources can move to final identity-derived filenames without crossing volumes. Reconciliation consumes the repository's combined active and pending-removal filename snapshot and removes abandoned staging work plus genuinely unreferenced final resources; it never treats file presence as a persisted library record or bypasses tombstone-owned cleanup.

The managed root currently lives in the app's Application Support directory. Audio and artwork are durable user data; Staging is temporary recovery state. Product capacity, backup, free-space, and responsiveness expectations are owned by [Quality Attributes](docs/product-specs/quality-attributes.md). Concrete storage mechanics belong here only after they are implemented.

`LibraryMutationGate` owns one cross-service mutation reservation. `AudioImportService` owns the lifetime and cancellation of one active import task while holding that reservation through completion. It publishes immutable progress and terminal per-file outcomes through an async stream. `LibraryRemovalService` uses the same gate for removal, targeted retry, and ordered reconciliation. `ImportSessionModel` consumes import events on the main actor and refreshes `LibraryStore` after committed results.

`LibraryStore` owns the shared presentation snapshot, load state, per-identity removal progress, transient request failures, and the deterministic pending-cleanup feedback queue. SwiftUI owns only the current confirmation candidate. `ImportSessionModel` owns only one sheet operation and never becomes a second durable source of library truth.

`PlaybackStore` owns live transport and queue state plus temporary removal-selection blocks. `FilePlaybackRestorationStore` owns only the versioned queue, traversal, history, mode, current stable identity, and position snapshot under `Application Support/Resona/Playback`; it does not persist a playing intention. Relaunch freshly resolves Library values, sanitizes missing identities, prepares one valid resource, seeks to a finite clamped position, and remains paused or stopped at end without activating the audio session. The engine's finite positive duration remains authoritative for seeking.

## Platform integrations

Planned platform integrations belong to these boundaries:

| Apple framework or system surface | Owning boundary |
| --- | --- |
| SwiftUI | Presentation |
| SwiftData | Library persistence |
| File importer and security-scoped resources | Library import; system multi-file selection and coordinated security-scoped reading are implemented |
| AVFoundation | Playback and metadata; Library validation/metadata adapters plus the single-song `AVAudioPlayer` and `AVAudioSession` adapters are implemented behind feature interfaces |
| MediaPlayer and remote commands | Playback; Now Playing and the approved command set are implemented behind focused controllers |
| Background audio capability | Playback and app composition |

Changes to capabilities, entitlements, signing, deployment targets, or background modes require explicit approval as defined in `AGENTS.md`.

The app target declares only `audio` in `UIBackgroundModes` for Debug and Release. Together with the playback category and application-lifetime Playback owner, this supports continuation of already-started local audio while backgrounded or locked. Now Playing, remote commands, route and interruption policy, and relaunch restoration use existing Apple frameworks and require no additional capability or entitlement.

## Architectural decisions not yet made

The repository does not yet establish whether the existing source-folder boundaries should later become Swift packages.

Resolve these decisions when the corresponding product specification is written. Record decisions in this document when they change the system map; do not silently infer them from planned feature names.

## Keeping this document accurate

Update this document when a change:

- Adds, removes, or renames an architectural boundary
- Changes ownership of state, persistence, or a platform integration
- Introduces a new dependency direction or shared service
- Implements something currently described as planned or not implemented
- Resolves one of the undecided architectural questions above

Keep implementation details in code and task-specific plans. This document should remain a concise map of the system and its durable boundaries.
