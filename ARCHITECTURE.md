# Resona Architecture

This document is the system map for Resona.

## Product boundary

Resona is an offline-first local music player for iPhone and iPad. Its core product boundary is media that the user imports and keeps available locally. Accounts, subscriptions, streaming catalogs, and server-side services are outside that boundary.

The product direction is described in `README.md`. A feature listed there is planned, not implemented, unless it also appears in the current system map below.

## Current implementation

The repository is in its foundation stage and currently contains a single iOS application target, a unit-test target, and a UI-test target.

The application is still the initial SwiftUI and SwiftData scaffold:

- `ResonaApp` is the composition root.
- It creates a disk-backed SwiftData `ModelContainer` containing the `Item` schema.
- It injects that container into `ContentView` through the SwiftUI environment.
- `ContentView` queries, inserts, and deletes `Item` records directly through SwiftData.
- `Item` contains only a timestamp.
- No audio import, media library, metadata extraction, playback, queue, background audio, or system media-control functionality exists yet.

### Current runtime flow

```text
ResonaApp
  -> creates ModelContainer(Item)
  -> presents ContentView
  -> injects ModelContext through the SwiftUI environment

ContentView
  -> reads Item values with @Query
  -> inserts and deletes Item values with ModelContext

SwiftData
  -> persists Item values on device
```

### Current source map

```text
Resona/
├── ResonaApp.swift       Application entry point and dependency composition
├── ContentView.swift     Entire current user interface and persistence interaction
├── Item.swift            Entire current persisted schema
└── Assets.xcassets       App icons, accent color, and visual assets

ResonaTests/              Unit-test target
ResonaUITests/            UI-test target
```

There are no established feature modules or service layers yet. New code must not claim an existing layer or abstraction merely because it appears in the target architecture below.

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

External files and metadata are untrusted boundary inputs. They must be validated before becoming domain data. The persistence schema must not be designed until the first library feature and its migration requirements are specified.

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

The existing `Item` model is scaffold data, not an approved music-library schema. Replacing it becomes a destructive schema change once real user data can exist and therefore requires an explicit migration decision.

## Platform integrations

Planned platform integrations belong to these boundaries:

| Apple framework or system surface | Owning boundary |
| --- | --- |
| SwiftUI | Presentation |
| SwiftData | Library persistence |
| File importer and security-scoped resources | Library import |
| AVFoundation | Playback and metadata, behind their respective interfaces |
| MediaPlayer and remote commands | Playback |
| Background audio capability | Playback and app composition |

Changes to capabilities, entitlements, signing, deployment targets, or background modes require explicit approval as defined in `AGENTS.md`.

## Architectural decisions not yet made

The repository does not yet establish:

- The music-library data model or migration plan
- The concrete playback engine and its public interface
- Queue persistence and restoration semantics
- Feature folder or Swift package boundaries
- Dependency-injection mechanics beyond SwiftUI environment values

Resolve these decisions when the corresponding product specification is written. Record decisions in this document when they change the system map; do not silently infer them from planned feature names.

## Keeping this document accurate

Update this document when a change:

- Adds, removes, or renames an architectural boundary
- Changes ownership of state, persistence, or a platform integration
- Introduces a new dependency direction or shared service
- Implements something currently described as planned or not implemented
- Resolves one of the undecided architectural questions above

Keep implementation details in code and task-specific plans. This document should remain a concise map of the system and its durable boundaries.
