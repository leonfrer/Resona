# Resona Architecture

This document is the authoritative map of Resona's current system boundaries,
dependency direction, and state ownership. Product behavior belongs in the
[product specifications](docs/product-specs/index.md); delivery progress and
verification evidence belong in [execution plans](docs/execution-plans/README.md).

## Product and repository boundary

Resona is an offline-first local music player for iPhone and iPad. It imports
user-selected audio into app-managed storage and provides a persistent library,
local playback, queue controls, system media controls, and silent playback-state
restoration. Accounts, subscriptions, streaming catalogs, and server-side
services are outside the product boundary.

The repository contains one iOS application target, one unit-test target, and
one UI-test target. `Library` and `Playback` are established source boundaries
inside the application target; they are not separate Swift packages.

## System overview

```text
ResonaApp (composition root)
├── Presentation
│   ├── ContentView / Library views
│   ├── LibraryStore / ImportSessionModel
│   └── PlaybackStore / Playback views
├── Library
│   ├── Domain and repository interfaces
│   ├── Import and removal services
│   ├── SwiftData persistence
│   └── Managed media storage
└── Playback
    ├── Domain and queue behavior
    ├── Library-facing interfaces
    ├── AVFoundation and MediaPlayer adapters
    └── File-backed restoration
```

`ResonaApp` constructs long-lived dependencies and installs presentation
dependencies in the SwiftUI environment. `ContentView` owns the root
`NavigationStack`, initiates silent playback restoration, and coordinates
scene-phase persistence without becoming a feature-state owner.

## Boundary ownership

| Boundary | Owns | Does not own |
| --- | --- | --- |
| App composition | Construction and lifetime of shared services, stores, adapters, and the model container | Library or playback decisions |
| Library domain and persistence | Stable song identity, normalized library values, availability, duplicate candidates, active records, and pending-removal records | SwiftUI presentation or playback transport state |
| Library services and storage | Import, removal, mutation serialization, managed audio and artwork, staging, and reconciliation | Durable UI state or playback internals |
| Library presentation | Library snapshots, load state, import progress, removal progress, and retryable feedback | Persisted library truth |
| Playback domain and store | Current item, transport phase, queue, traversal, history, shuffle, repeat, engine-session identity, and removal-selection blocks | SwiftData records or managed-file mutation |
| Playback adapters and persistence | Audio engine, audio session, Now Playing projection, remote commands, and the versioned restoration snapshot | Authoritative transport decisions |
| SwiftUI views | Short-lived presentation state and user-action forwarding | Durable library state or authoritative playback state |

`PlaybackStore` is the sole live owner of playback and queue state. Library
presentation reads only immutable Library values, and SwiftUI views reflect
feature state without creating a second source of truth.

## Dependency direction

```text
                         ResonaApp
                    (constructs and injects)
                      /       |       \
                     v        v        v
              Presentation  Library  Playback
                    |          ^         ^
                    v          |         |
             feature stores    +--- explicit interfaces ---+
                               ^
                               |
                    Apple-framework adapters
```

- Presentation depends on feature-facing stores, immutable values, and
  interfaces; feature behavior does not depend on SwiftUI views.
- SwiftData, file coordination, AVFoundation, and MediaPlayer details remain
  behind the boundary that owns their integration.
- Playback reads Library values only through `PlaybackItemProviding`.
- Library removal affects live Playback state only through
  `PlaybackRemovalInvalidating`.
- Cross-feature communication uses explicit interfaces rather than direct
  access to another feature's persistence, storage, or implementation types.
- Shared abstractions are introduced only after a real shared responsibility
  exists.

## Current source map

```text
Resona/
├── ResonaApp.swift                Application entry point and composition
├── ContentView.swift              Navigation root and scene coordination
├── Library/
│   ├── Coordination/              Shared Library mutation serialization
│   ├── Domain/                    Song, identity, availability, and sorting values
│   ├── Import/                    Source access and import coordination
│   ├── Metadata/                  Audio validation and metadata normalization
│   ├── Persistence/               Current schema, records, and repository
│   ├── Presentation/              Library state and SwiftUI presentation
│   ├── Removal/                   Removal, retry, and reconciliation
│   └── Storage/                   Managed media staging and storage
├── Playback/
│   ├── Domain/                    Playback state, queue, and restoration values
│   ├── Engine/                    Playback and audio-session adapters
│   ├── Integration/               Now Playing and remote-command adapters
│   ├── Library/                   Cross-feature provider and invalidation interfaces
│   ├── Persistence/               File-backed playback restoration
│   └── Presentation/              PlaybackStore and SwiftUI presentation
└── Assets.xcassets                App icons, accent color, and visual assets

ResonaTests/                       Unit and integration tests by feature
ResonaUITests/                     End-to-end user journeys
```

The folder structure communicates ownership but does not by itself create a
module boundary. Concrete types and protocols remain implementation details
unless they enforce a dependency or ownership rule documented here.

## Critical flows

### Launch and restoration

1. `ResonaApp` creates the current SwiftData container, managed-media store,
   Library repository and services, Playback adapters, and shared stores.
2. `LibraryStore` runs pending-removal reconciliation before its first fetch,
   then publishes a fresh Library snapshot from the repository.
3. `PlaybackStore` loads its separate file-backed snapshot, resolves current
   Library values through `PlaybackItemProviding`, sanitizes missing identities,
   prepares a valid resource, and restores without activating audio or playing.

### Import

1. The system file importer supplies user-selected URLs to
   `ImportSessionModel` and `AudioImportService`.
2. `AudioImportService` holds the shared `LibraryMutationGate` reservation while
   it coordinates source access, stages and fingerprints bytes, validates audio,
   and normalizes metadata.
3. `ManagedMediaStore` commits accepted resources before
   `LibraryRepository` persists their Library records.
4. Presentation refreshes from the repository after committed results; it does
   not mutate the durable Library snapshot directly.

### Removal

1. `LibraryStore` asks `PlaybackRemovalInvalidating` to block and purge live and
   persisted Playback references for the selected identity.
2. `LibraryRemovalService` holds the shared mutation reservation and atomically
   replaces the active record with durable pending-removal intent.
3. The service removes managed resources idempotently and finalizes the pending
   record. Failed cleanup remains represented by the pending record for retry.
4. Library presentation refreshes active songs from the repository after
   durable acceptance.

### Playback and system controls

1. A Library selection supplies the stable identity and visible Library order
   to `PlaybackStore`.
2. Playback resolves fresh immutable items through `PlaybackItemProviding` and
   prepares one tagged engine session.
3. `PlaybackStore` owns transport and queue decisions; the audio engine and
   audio-session adapters report typed events without owning that state.
4. MediaPlayer adapters project store state to Now Playing and forward accepted
   remote commands back to the store.
5. Playback persists its versioned snapshot independently of SwiftData.

## State and persistence

### Library database

The disk-backed SwiftData container uses the single `ResonaSchema.current`
schema. It contains only `LibrarySongRecord` and
`LibrarySongRemovalRecord`. `SwiftDataLibraryRepository` owns all
`ModelContext` access and exposes immutable Library values; SwiftData records do
not cross the persistence boundary.

The repository does not compile historical development schemas or guarantee
compatibility with stores created by them. An incompatible installed
development store requires a manual app-data reset; the app does not silently
delete or recreate it.

### Managed media

`ManagedMediaStore` owns Audio, Artwork, and Staging under the versioned
`ManagedLibrary/v1` root in Application Support. Audio and artwork are durable
user data; Staging is temporary recovery state. Reconciliation uses the
repository's combined active and pending-removal references so it cannot treat
tombstone-owned resources as orphans.

Capacity, backup, free-space, and responsiveness expectations are defined by
[Quality Attributes](docs/product-specs/quality-attributes.md).

### Playback restoration

`FilePlaybackRestorationStore` owns a versioned file snapshot under
`Application Support/Resona/Playback`. The snapshot contains Playback-owned
queue, traversal, history, mode, current identity, and position state. It is
independent of SwiftData and never persists an intention to resume playing.

## Platform integrations

| Apple framework or system surface | Owning boundary | Current use |
| --- | --- | --- |
| SwiftUI | Presentation and app composition | Scenes, navigation, views, environment injection, and file-import presentation |
| SwiftData | Library persistence | Active songs and pending-removal intent behind the repository |
| Security-scoped access and file coordination | Library import | Coordinated reads of user-selected external files |
| AVFoundation | Library metadata and Playback | Validation and metadata adapters, local audio engine, and audio-session events |
| MediaPlayer | Playback | Now Playing projection and remote-command forwarding |
| Background audio mode | Playback and app composition | Continuation of already-started local playback while backgrounded or locked |

The app declares only `audio` in `UIBackgroundModes` for Debug and Release.
Changes to capabilities, entitlements, signing, deployment targets, or
background modes require explicit approval under `AGENTS.md`.

## Open architectural question

The repository does not yet establish whether the Library and Playback source
boundaries should become Swift packages. Revisit modularization only when a
concrete isolation, build-time, reuse, or ownership need justifies the added
boundary. Record the decision here after the change is implemented; use an
execution plan if the work crosses existing boundaries or requires staged
delivery.

## Keeping this document accurate

Update this document when a change:

- Adds, removes, or renames an architectural boundary
- Changes ownership of state, persistence, or a platform integration
- Introduces a new dependency direction or shared service
- Changes a durable storage or restoration boundary
- Resolves the open modularization question

Keep algorithms, user-visible behavior, task progress, and verification detail
in their owning code, product specification, or execution plan. This document
should remain a concise map of the current system and its durable boundaries.
