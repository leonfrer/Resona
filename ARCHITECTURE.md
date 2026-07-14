# Resona Architecture

This document is the system map for Resona.

## Product boundary

Resona is an offline-first local music player for iPhone and iPad. Its core product boundary is media that the user imports and keeps available locally. Accounts, subscriptions, streaming catalogs, and server-side services are outside that boundary.

The product direction is described in `README.md`. A feature listed there is planned, not implemented, unless it also appears in the current system map below.

## Current implementation

The repository now contains the Import to Songs List slice, the implemented Basic Playback runtime, and the persistence milestone of Library Management in a single iOS application target, a unit-test target, and a UI-test target. The approved Audio background mode and hands-on background and locked-device audio behavior are verified; song-removal services and presentation are not implemented yet:

- `ResonaApp` is the composition root.
- It creates a disk-backed, versioned SwiftData `ModelContainer` using `ResonaMigrationPlan`.
- It constructs the managed-media store, Library repository, audio-import service, playback item provider, AVFoundation playback adapters, shared `LibraryStore`, and application-lifetime `PlaybackStore`, then installs presentation dependencies in the SwiftUI environment.
- Schema V0 represents the original `Item`-only store. Schema V1 adds `LibrarySongRecord`, and Schema V2 adds `LibrarySongRemovalRecord`, while retaining `Item` through a verified lightweight V0-to-V1-to-V2 migration chain.
- `ContentView` hosts one `NavigationStack` rooted at `LibraryView`; it no longer presents or mutates scaffold `Item` values.
- `Item` contains only a timestamp.
- The Library domain defines stable song identity, normalized song values, content fingerprints, resource availability, duplicate candidates, and deterministic localized sorting.
- `SwiftDataLibraryRepository` is a model actor that owns library-record queries and mutations behind `LibraryRepository`, including fresh stable-ID lookup for playback and the atomic active-record-to-pending-removal transaction. Pending removals are excluded from active lookup and duplicate matching while retaining managed-resource ownership until idempotent finalization. SwiftData records and `ModelContext` do not cross that boundary.
- `ManagedMediaStore` is an actor that owns versioned app-managed Audio, Artwork, and Staging directories. It provides staging locations, same-volume moves into identity-derived final filenames, complete byte comparison, availability resolution, explicit cleanup, and reconciliation of abandoned or unreferenced files.
- The Library import boundary now includes complete-file SHA-256 fingerprinting, security-scoped and coordinated source reads, content-based container and codec validation, canonical metadata and artwork normalization, and typed per-file outcomes.
- `AudioImportService` is an actor that serializes one import operation, reconciles managed storage before work, processes selected files sequentially, cooperatively cancels unfinished files, reports progress through an async stream, and supports one-file retry.
- Import coordination confirms available duplicates with a complete byte comparison, restores unavailable matching records without changing identity, and removes newly committed resources when persistence fails.
- The repository exposes the active managed filenames needed for reconciliation without exposing SwiftData records.
- `LibraryStore` owns library loading state and publishes immutable, deterministically sorted song snapshots to presentation. Its first load runs launch reconciliation before fetching songs.
- `LibraryView` presents the Songs List, offline-copy empty state, loading and recovery states, toolbar import action, reusable system multi-file importer, available-row playback actions, and the persistent current-song surface.
- `ImportSessionModel` consumes import events and owns one operation's progress, results, cancellation, Choose Files recovery, and one-file retry. `ImportSheet` remains presented while active and owns its actions and dismissal.
- `SongRow` displays artwork or a standard placeholder, normalized title, artist fallback, optional duration, and a labeled unavailable state. Only available rows become playback buttons.
- `LibraryPlaybackItemProvider` maps a freshly resolved `LibrarySong` into immutable Playback input without exposing SwiftData, managed storage, or import implementation types.
- `PlaybackStore` is the sole live owner of the current item, mutually exclusive phase, elapsed position, playable duration, failure, selection generation, and active engine session. It serializes transport commands and ignores stale selection results and tagged engine events.
- `AVAudioPlayerEngine` owns one local `AVAudioPlayer`, its retained delegate bridge, tagged event stream, and position publication. `AVAudioSessionController` configures the playback category, defers explicit activation until playback, deactivates on silent states, and reports interruption start.
- `CurrentSongBar` and item-driven `PlayerView` render shared Playback state and send commands without creating a second player or changing transport merely through presentation. Resource recovery reuses the Library import presentation.
- Queue, user-facing removal coordination and cleanup, Now Playing metadata, remote commands, restoration, and full interruption or route-change policy do not exist yet.

### Current runtime flow

```text
ResonaApp
  -> creates V2 versioned ModelContainer, ManagedMediaStore,
     SwiftDataLibraryRepository, AudioImportService, LibraryStore,
     LibraryPlaybackItemProvider, AVAudioPlayerEngine,
     AVAudioSessionController, and PlaybackStore
  -> migrates an existing Item-only store without deleting Item data
  -> installs the model container plus Library and Playback dependencies

ContentView
  -> hosts NavigationStack -> LibraryView
  -> synchronizes the engine position when the scene becomes active

LibraryView
  -> starts the initial LibraryStore load
  -> renders empty, failure, or deterministic Songs List state
  -> sends available stable song IDs to PlaybackStore
  -> presents reusable import flow, CurrentSongBar, and item-driven PlayerView

PlaybackStore
  -> freshly resolves selected IDs through LibraryPlaybackItemProvider
  -> prepares one tagged engine session and activates audio before Play
  -> owns play, pause, seek, retry, completion, failure, and stale-event rules
  -> remains empty after relaunch because playback state is not persisted

AVAudioPlayerEngine / AVAudioSessionController
  -> adapt one managed local URL and the iOS playback audio session
  -> publish tagged position, completion, failure, and interruption events
  -> never expose AVFoundation objects to Playback presentation

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

AudioImportService
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
├── ContentView.swift              Application navigation root
├── Item.swift                     Retained scaffold model and V0 schema
├── Library/
│   ├── Domain/                    Sendable song, identity, availability, and sorting values
│   ├── Import/                    Source access, fingerprinting, typed results, and import coordination
│   ├── Metadata/                  AVFoundation validation/reading and canonical normalization
│   ├── Persistence/               V1 record, migration plan, repository, and resource boundary
│   ├── Presentation/              Library state, Songs List, reusable import presentation, and rows
│   └── Storage/                   Managed resource staging, commit, cleanup, and reconciliation
├── Playback/
│   ├── Domain/                    Current item, phase, and typed failure values
│   ├── Engine/                    Playback/audio-session interfaces and AVFoundation adapters
│   ├── Library/                   Stable-ID Library-to-Playback provider boundary
│   └── Presentation/              PlaybackStore, CurrentSongBar, PlayerView, and formatting
└── Assets.xcassets                App icons, accent color, and visual assets

ResonaTests/                       Library, Playback state-machine, adapter, and presentation tests
ResonaUITests/                     Import, Library, and critical Basic Playback UI journeys
```

The Library and Playback folders are established source boundaries inside the application target, not separate Swift packages. Playback consumes canonical Library values only through `PlaybackItemProviding`; presentation reaches feature behavior through feature-facing state and interfaces.

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

The implemented Basic Playback subset uses `PlaybackStore` as that owner and `AVAudioPlayer` behind `AudioPlaybackEngine` for one managed local song. Engine events carry a session ID so replaced sessions cannot mutate current state. `AudioSessionControlling` isolates activation and interruption-start behavior. Queue behavior, MediaPlayer integration, restoration, and broader interruption or route policy remain planned.

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

`LibrarySongRecord` is the active persisted music-library model. `LibrarySongRemovalRecord` is the minimal V2 pending-cleanup intent containing the former identity, display title, and managed filenames. `SwiftDataLibraryRepository` owns their `ModelContext` access and exposes immutable Library domain values. Resource availability is derived through `LibraryResourceResolving` rather than persisted as an independent source of truth. Removal services, managed-resource cleanup, launch retry, and user-facing removal remain unimplemented.

`ManagedMediaStore` owns app-managed resources under the versioned `ManagedLibrary/v1` root. Staging and final directories share that root so accepted resources can move to final identity-derived filenames without crossing volumes. Reconciliation consumes the repository's active filename snapshot and removes abandoned staging work plus unreferenced final resources; it never treats file presence as a persisted library record.

The managed root currently lives in the app's Application Support directory. Audio and artwork are durable user data; Staging is temporary recovery state. Product capacity, backup, free-space, and responsiveness expectations are owned by [Quality Attributes](docs/product-specs/quality-attributes.md). Concrete storage mechanics belong here only after they are implemented.

`AudioImportService` owns the lifetime and cancellation of one active import task. It publishes immutable progress and terminal per-file outcomes through an async stream. `ImportSessionModel` consumes those events on the main actor and refreshes `LibraryStore` after committed results.

`LibraryStore` owns the shared presentation snapshot and load state. `ImportSessionModel` owns only one sheet operation and never becomes a second durable source of library truth.

`PlaybackStore` owns only live, non-persisted Basic Playback state. Relaunch begins in `idle`; it does not restore a current item or start audio. Its current item contains canonical Library metadata plus freshly resolved availability, while the engine's finite positive duration is authoritative for seeking.

## Platform integrations

Planned platform integrations belong to these boundaries:

| Apple framework or system surface | Owning boundary |
| --- | --- |
| SwiftUI | Presentation |
| SwiftData | Library persistence |
| File importer and security-scoped resources | Library import; system multi-file selection and coordinated security-scoped reading are implemented |
| AVFoundation | Playback and metadata; Library validation/metadata adapters plus the single-song `AVAudioPlayer` and `AVAudioSession` adapters are implemented behind feature interfaces |
| MediaPlayer and remote commands | Playback |
| Background audio capability | Playback and app composition |

Changes to capabilities, entitlements, signing, deployment targets, or background modes require explicit approval as defined in `AGENTS.md`.

The app target declares only `audio` in `UIBackgroundModes` for Debug and Release. Together with the playback category and application-lifetime Playback owner, this supports continuation of already-started local audio while backgrounded or locked; it does not add background tasks, Now Playing metadata, remote commands, or relaunch restoration.

## Architectural decisions not yet made

The repository does not yet establish:

- Queue persistence and restoration semantics
- Full interruption, route-change, system media-control, and Now Playing policy
- Whether existing source-folder boundaries should later become Swift packages

Resolve these decisions when the corresponding product specification is written. Record decisions in this document when they change the system map; do not silently infer them from planned feature names.

## Keeping this document accurate

Update this document when a change:

- Adds, removes, or renames an architectural boundary
- Changes ownership of state, persistence, or a platform integration
- Introduces a new dependency direction or shared service
- Implements something currently described as planned or not implemented
- Resolves one of the undecided architectural questions above

Keep implementation details in code and task-specific plans. This document should remain a concise map of the system and its durable boundaries.
