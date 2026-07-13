# Basic Playback Execution Plan

> Historical completion record. This plan is not current behavioral or architectural guidance; use the owning product specifications and `ARCHITECTURE.md`.

## Status

Complete. The Basic Playback runtime, approved Audio background mode, automated suites, and physical-device background and lock-screen acceptance checks are implemented and verified.

## Outcome

Implement the first playback slice in which a user can select an available imported song, hear it play, control play, pause, and seek, inspect the current song in a native player sheet, and continue already-started playback when Resona moves to the background or the device locks.

This plan activates only single-song Basic Playback. It does not introduce a queue, next or previous commands, shuffle, repeat, system Now Playing metadata, remote commands, interruption recovery, route-change policy, or playback restoration.

## Source documents

- [Basic playback](../product-specs/basic-playback.md)
- [Experience foundation](../product-specs/experience-foundation.md)
- [Library foundation](../product-specs/library-foundation.md)
- [Music library](../product-specs/music-library.md), Songs List stage
- [Playback integration](../product-specs/playback.md)
- [Architecture](../../ARCHITECTURE.md)
- [Engineering guidelines](../engineering-guidelines.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
- [Apple: AVAudioPlayerDelegate](https://developer.apple.com/documentation/avfaudio/avaudioplayerdelegate)
- [Apple: AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Apple: Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)

## Slice boundaries

### In scope

- Select an available song from the Songs List by stable library identity.
- Resolve fresh canonical metadata and managed-resource availability at selection time.
- Replace any previous current song and start the selected song from its beginning.
- Maintain one authoritative current item, transport phase, elapsed position, playable duration, and failure state.
- Play, pause, seek, retry transient playback failures, and re-import after resource failures.
- Stop at natural end while retaining the current song at its end position; the next Play restarts it from the beginning.
- Show a persistent current-song affordance over the library after a current item is established.
- Present a detailed player in an item-driven SwiftUI sheet without issuing a playback command when the sheet opens or closes.
- Use the app-managed artwork and canonical Library metadata without re-reading source metadata.
- Configure a playback audio session and continue valid already-started audio in the background or while the device is locked.
- Add deterministic unit, adapter, presentation, and critical UI coverage plus interactive background verification.

### Deferred

- Multi-item queue creation or persistence
- Next, previous, shuffle, Repeat One, and Repeat All
- Lock Screen, Control Center, headphone, and other remote commands
- `MPNowPlayingInfoCenter` and other MediaPlayer integration
- Automatic interruption recovery or route-change policy
- Playback or position restoration across relaunches
- Library removal and pending-removal cleanup
- Album, artist, playlist, and search playback entry points
- Streaming, gapless playback, crossfade, equalization, and playback speed

The app must not display disabled placeholders for deferred transport commands. Relaunch creates no current item and never starts audible playback.

## Approval gate

Minimum background continuation requires the app target to declare the Audio background mode. Before implementation changes the Xcode target, obtain explicit approval to add the Background Modes capability with the `audio` value in `UIBackgroundModes` for Debug and Release.

This plan does not authorize changes to the deployment target, bundle identifier, signing team, unrelated capabilities, or entitlements. If approval for the audio background mode is not granted, foreground playback work may be developed and tested, but Basic Playback cannot be declared implemented because its background acceptance criteria would remain unmet.

## Architectural shape

```text
ResonaApp
  -> constructs Library repository, PlaybackItemProvider,
     AVAudioSessionController, AVAudioPlayerEngine, and PlaybackStore
  -> owns PlaybackStore for the application lifetime
  -> installs LibraryStore, PlaybackStore, and import dependencies
     in the SwiftUI environment

LibraryView
  -> renders the existing Songs List
  -> sends only an available song's stable ID to PlaybackStore
  -> keeps unavailable rows non-playable
  -> presents CurrentSongBar while PlaybackStore has a current item
  -> presents PlayerView with one item-driven sheet

CurrentSongBar / PlayerView
  -> render authoritative PlaybackStore state
  -> send transport commands to PlaybackStore
  -> never own a second player or derived transport state

PlaybackStore (@MainActor, @Observable)
  -> owns the authoritative current item, phase, position,
     duration, failure, and active playback generation
  -> resolves stable IDs through PlaybackItemProvider
  -> serializes selection and transport commands
  -> consumes tagged AudioPlaybackEngine events

LibraryPlaybackItemProvider
  -> resolves one LibrarySong by stable identity through LibraryRepository
  -> maps canonical Library metadata and fresh managed-resource
     availability into a PlaybackItem

AVAudioPlayerEngine
  -> owns one AVAudioPlayer and its delegate bridge
  -> prepares and controls one local managed audio URL
  -> reports position, natural end, decode failure, and unexpected stop

AVAudioSessionController
  -> configures category .playback with mode .default
  -> activates immediately before audible playback
  -> deactivates after pause, terminal stop, or failed startup
  -> reports interruption start only to prevent false playing state
```

Playback becomes a new source boundary under `Resona/Playback`. It may consume immutable Library-facing values through a focused provider, but it must not access SwiftData records, `ModelContext`, `ManagedMediaStore`, or import implementation types directly.

## Playback domain and authoritative state

### PlaybackItem

Introduce an immutable, `Sendable` `PlaybackItem` containing:

- Stable library song ID
- Canonical title, optional artist and album
- Optional artwork URL
- Fresh `SongAvailability`, including the managed audio URL when available
- Library duration as optional display information only

The audio engine's finite positive duration is authoritative for seeking. Preparing playback must not write a newly observed duration back to the Library in this slice.

### Playback phase

Represent transport as one mutually exclusive phase rather than independent booleans:

- `idle`: no current item
- `preparing`: a current item is resolving or its engine is preparing
- `playing`: audio is expected to be audible
- `paused`: a playable current item is stopped before its end
- `stoppedAtEnd`: the current item is retained at its known end
- `failed(PlaybackFailure)`: the current item is retained, audio is not playing, and typed recovery is available

`PlaybackFailure` uses typed cases rather than user-facing prose:

- `resourceUnavailable` -> Song Unavailable, Re-import
- `resourceInvalid` -> Song Can't Be Played, Re-import
- `startupFailed` -> Playback Couldn't Start, Try Again
- `playbackFailed` -> Playback Stopped, Try Again

Presentation maps those cases to localized complete strings. A failure never deletes, invalidates, or edits the Library song.

### Command rules

- `select(songID:)` cancels or supersedes any in-flight selection, stops the previous engine session, resolves the selected identity, establishes it as current in `preparing`, and starts it from zero.
- A rapid later selection wins. Completion or callbacks from an earlier selection must not alter the replacement item.
- `play()` is a no-op with no current item. From `stoppedAtEnd`, it seeks to zero before playing. From `failed`, recovery occurs only through the typed retry action.
- `pause()` is safe in every phase. While playing it records the engine position, pauses audio, and becomes `paused`.
- `seek(to:)` is unavailable during `preparing` or while duration is unknown. Otherwise it clamps the request to `0...duration`.
- Seeking to the duration produces `stoppedAtEnd` and leaves audio stopped. Seeking backward from `stoppedAtEnd` produces `paused` until Play is requested.
- Natural completion records the exact known duration and becomes `stoppedAtEnd` without clearing the current item.
- Dismissing or presenting the player sheet never calls a transport command.
- App relaunch does not restore `PlaybackItem`, phase, or position.

## Library-to-playback boundary

Extend `LibraryRepository` with a focused lookup by stable ID that returns one freshly resolved `LibrarySong`. `SwiftDataLibraryRepository` performs a predicate fetch and derives audio and artwork availability through its existing resource resolver, just as the list fetch does.

Add `PlaybackItemProviding` in the Playback boundary and implement it with `LibraryPlaybackItemProvider`. The provider maps the repository result into `PlaybackItem` and distinguishes:

- missing identity;
- retained identity whose managed audio resource is unavailable;
- available item with a managed local URL.

The UI passes only the UUID to `PlaybackStore`. It must not treat the URL cached in a previously rendered row as proof that the resource is still available.

Repository lookup coverage must include available, unavailable, and missing identities. Existing repository fakes and previews receive the new method without changing their unrelated behavior.

## Engine and audio-session adapters

### AVAudioPlayerEngine

Use `AVAudioPlayer` for this slice because the product plays one validated local managed file at a time and does not yet need queue semantics. Keep it behind `AudioPlaybackEngine` so PlaybackStore tests do not depend on audible output or wall-clock timing and a later queue stage can reconsider the engine without changing presentation state ownership.

The engine interface supports:

- prepare a local URL and return a tagged playback-session ID plus duration;
- play, pause, seek, query current position, and stop;
- an async event stream tagged with the playback-session ID;
- events for position updates, natural completion, decode failure, and unexpected stop.

Every prepared item receives a new session ID. PlaybackStore ignores events whose session ID is no longer active. This is required for deterministic rapid replacement and stale delegate callbacks.

The real adapter:

- constructs `AVAudioPlayer(contentsOf:)`, assigns a retained delegate bridge, and calls `prepareToPlay()`;
- treats a thrown initializer, failed preparation, or non-finite/non-positive duration as an invalid resource;
- treats `play()` returning `false` as startup failure;
- uses the delegate's finish and decode-error callbacks for terminal events;
- publishes position often enough for a responsive elapsed-time display without making the UI the clock source;
- stops position publication while paused or terminal and synchronizes from `currentTime` when resumed;
- releases the previous player and delegate state when a new session replaces it.

Position cadence is an adapter detail. Tests inject events directly and must not wait for real time.

### AVAudioSessionController

Keep `AVAudioSession.sharedInstance()` behind `AudioSessionControlling` so activation failure is deterministic in tests.

The production controller:

- sets category `.playback`, mode `.default`, and no mixing option;
- defers `setActive(true)` until immediately before Play so Resona does not interrupt other audio merely by launching or preparing;
- pauses the player before deactivating after user pause, natural end, decode failure, or startup failure;
- deactivates with `.notifyOthersOnDeactivation` when appropriate;
- observes interruption start and tells PlaybackStore to leave `playing` immediately;
- does not automatically resume after interruption and does not define route-change recovery in this slice.

If an interruption or other system event makes the real player stop unexpectedly, visible state must cease claiming playback. Full interruption and route recovery remains deferred to Playback Integration.

## SwiftUI presentation

### Songs List selection

- Convert only available `SongRow` instances into accessible buttons that call `PlaybackStore.select(songID:)`.
- Keep unavailable rows visibly labeled and non-playable.
- Do not use a `NavigationLink`; selection is a playback command and the Library remains the navigation root.
- Preserve stable row identifiers and add button traits and localized accessibility hints describing that selection starts playback.
- During preparation, prevent the same row from creating parallel work while still allowing a different song to replace it.

### CurrentSongBar

Add a persistent current-song surface using a bottom safe-area inset on the Library screen:

- Show artwork or the standard placeholder, title, artist fallback, and a non-color transport-state indication.
- The main affordance opens PlayerView and does not start, restart, pause, or seek.
- A separate labeled play/pause control may send the direct transport command.
- Keep both targets independently discoverable by VoiceOver.
- Adapt vertically rather than truncating essential controls at large Dynamic Type sizes.

The bar remains visible in paused, stopped-at-end, and failed phases because a current item still exists.

### PlayerView

Present one `PlayerView` with `.sheet(item:)` using a lightweight presentation destination keyed by the current song identity. The sheet reads the shared PlaybackStore from the environment and owns its dismissal action.

The player displays:

- Artwork or the standard placeholder
- Title, artist fallback, and album fallback
- Preparing, playing, paused, stopped-at-end, or failed status
- Elapsed and duration labels using monospaced digits
- A native Slider when duration is known and seeking is enabled
- A disabled progress presentation while preparing or duration is unknown
- One primary play/pause/restart control appropriate to the authoritative phase
- Inline actionable failure feedback with Try Again or Re-import

Do not add next, previous, queue, shuffle, repeat, or system-control placeholders. The transport control requires an accessibility label that describes its current action rather than its visual symbol.

### Re-import recovery

Extract the existing Files picker and import-session presentation into a small reusable Library-owned SwiftUI modifier or presentation helper. LibraryView continues to use it for normal imports, and PlayerView uses the same flow for the Re-import recovery action without duplicating import business logic.

Re-import opens the system picker and relies on the existing fingerprint policy to restore a matching unavailable identity. Picker cancellation remains silent. Import progress and results remain owned by `ImportSessionModel`; PlaybackStore does not become an import coordinator. After a successful restoration, retrying playback resolves the identity again through `PlaybackItemProvider`.

Add deterministic previews for:

- current song playing;
- paused and stopped-at-end states;
- preparing or unknown-duration state;
- resource failure with Re-import;
- transient failure with Try Again;
- CurrentSongBar at a large accessibility text size.

## Background capability and lifecycle

After explicit approval, add the Background Modes audio capability to the Resona app target and declare only `audio` in `UIBackgroundModes` for Debug and Release. Do not add a new entitlement file unless Xcode requires one for an independently justified setting; the audio background mode is represented in the generated Info.plist configuration.

The minimum contract is deliberately narrow:

- Audio that was already playing continues when Resona backgrounds or the device locks.
- Moving to the background never starts or resumes audio by itself.
- Paused, failed, idle, and stopped-at-end states remain silent.
- Returning to the foreground synchronizes elapsed position from the engine and does not create a second playback session.
- No background task API is used to keep UI work alive.
- No Now Playing metadata or remote commands are claimed in this slice.

## Test design

### Unit tests with Swift Testing

| Area | Required coverage |
| --- | --- |
| PlaybackStore selection | Available identity starts from zero; missing or unavailable identity fails without false playing; later selection wins; selecting another song replaces and stops the previous session. |
| Transport state | Play, pause, resume, temporarily invalid commands, and repeated commands preserve one consistent phase. |
| Seeking | Disabled while preparing or duration is unknown; negative and excessive targets clamp; seek-to-end stops; seek-back-from-end becomes paused. |
| Completion | Natural end retains current identity and exact end position; next Play seeks to zero before starting. |
| Failure mapping | Invalid resource and decode failure offer Re-import; activation, startup, and unexpected playback failure offer Try Again; Library data is not mutated. |
| Event isolation | Late position, completion, and failure events from a replaced playback-session ID are ignored. |
| Audio session | Activation happens only before audible playback; pause and terminal paths deactivate; activation failure never produces playing state. |
| Library provider | Stable-ID lookup maps canonical metadata and fresh available, unavailable, and missing resource states. |
| Presentation formatting | Elapsed and duration formatting, transport labels, failure messages, and recovery labels are deterministic and localization-ready. |

PlaybackStore tests use fake item providers, engines, audio sessions, and explicit engine events. They must not sleep for playback progress or depend on the Simulator's audio output.

### Adapter tests

- Prepare at least one small checked-in supported audio fixture with `AVAudioPlayerEngine` and verify a finite positive duration.
- Verify an invalid or corrupt fixture maps to resource-invalid preparation failure.
- Verify seeking and position query remain within the real engine duration without asserting wall-clock playback timing.
- Keep natural-end, decode-error, and activation-failure state-machine coverage in deterministic fakes rather than timing real audio.

### UI tests

- An available Songs List row is an accessible playback button; an unavailable row remains non-playable.
- Selecting a seeded available song shows the CurrentSongBar and the fake engine's playing state.
- Opening and dismissing PlayerView does not add a play command or change phase.
- Play, pause, seek, stopped-at-end restart, Try Again, and Re-import actions expose stable accessibility identifiers and drive injected fake state.
- The player and CurrentSongBar remain usable at an accessibility text size.
- Existing import and Library UI tests continue to pass after import-presentation reuse and row interactivity change.

Use debug-only injected PlaybackStore dependencies and engine events. Production playback must not branch on UI-test launch arguments outside `DEBUG`.

### Interactive validation

- Play each supported fixture family on an iPhone Simulator and confirm title, duration, seek, pause, resume, replacement, and natural end.
- Verify the player sheet and CurrentSongBar on iPhone and iPad in portrait and landscape where supported.
- Inspect Dark Mode, Reduce Motion, VoiceOver order, and accessibility XXXL sizing.
- Verify a real imported file continues after sending the app to the background and after locking a physical device when one is available.
- Confirm relaunch remains silent and has no restored current item.
- Confirm another app's audio is not interrupted until Resona actually begins playback.
- Report physical-device lock verification as unverified if no device is available; Simulator background checks alone must not be described as complete lock-screen proof.

## Implementation sequence

### 1. Domain and Library lookup

- Add PlaybackItem, phase, failure, event, and provider types.
- Add one stable-ID lookup to LibraryRepository and implement fresh resource resolution in SwiftDataLibraryRepository.
- Add repository and provider tests and update existing fakes and previews.
- Exit criterion: an ID resolves deterministically to canonical available, unavailable, or missing playback input without exposing persistence types.

### 2. Engine and audio-session adapters

- Add AudioPlaybackEngine, tagged engine events, and AudioSessionControlling interfaces.
- Implement AVAudioPlayerEngine and AVAudioSessionController.
- Add adapter tests using checked-in fixtures and deterministic session fakes.
- Exit criterion: one local supported resource can prepare and accept transport commands, while invalid input and session failure remain typed and testable.

### 3. Authoritative PlaybackStore

- Implement selection, replacement, play, pause, seek, completion, retry, failure, and stale-event rules.
- Add exhaustive deterministic state-transition tests before wiring views.
- Exit criterion: the store never claims playing without engine success and every command or event has one documented state transition.

### 4. Library and player presentation

- Make available rows actionable by stable identity.
- Add CurrentSongBar, item-driven PlayerView, controls, error recovery, accessibility, and previews.
- Extract and reuse import presentation for Re-import without moving import business logic into Playback.
- Add debug playback scenarios and critical UI tests.
- Exit criterion: select-to-play-to-current-bar-to-player-and-back works without changing playback state merely through presentation.

### 5. Background continuation — approval required

- Obtain explicit approval, then add only the Audio background mode to the app target.
- Verify deferred audio-session activation and minimum background/lock continuation.
- Exit criterion: already-started playback continues in the approved background scenarios, while idle and paused states remain silent.

### 6. Delivery verification and documentation

- Run `./scripts/check.sh` after each business-logic milestone.
- Run `./scripts/check-all.sh` before declaring the user-facing slice complete.
- Build and inspect on current iPhone and iPad Simulators; perform physical-device lock verification when available.
- Update `ARCHITECTURE.md` with the implemented Playback boundary, source map, runtime flow, dependency direction, state ownership, AVFoundation adapter, and background capability.
- Update product-spec implementation statuses only for acceptance criteria actually verified.
- Record completed commands, device coverage, warnings, and any unverified manual checks in this plan.
- Exit criterion: required builds and tests pass, the documented Basic Playback behavior is verified, and current architecture documentation matches runtime composition.

## Implementation record — 2026-07-13

Completed:

- Added the Playback domain, stable-ID Library provider, tagged `AVAudioPlayer` engine, audio-session controller, authoritative `PlaybackStore`, current-song bar, player sheet, and shared re-import presentation.
- Added deterministic coverage for repository lookup, provider mapping, selection races, stale events, transport state, seeking, completion, typed recovery, interruption start, audio-session failures, presentation formatting, and the real engine adapter.
- Added critical UI coverage for available and unavailable rows, select-to-play, presentation without transport side effects, pause, resume, typed recovery, and accessibility text sizing. Seek-to-end and restart remain deterministic `PlaybackStore` coverage rather than timing-sensitive UI automation.
- Added the explicitly approved Background Modes Audio capability with only `audio` in `UIBackgroundModes` for Debug and Release; no entitlement file, deployment-target change, bundle-identifier change, or unrelated capability was added.
- Kept preview-only support out of Release compilation and verified that both Debug and Release device builds compile successfully.
- Updated `ARCHITECTURE.md` to reflect the implemented Playback boundary and configured background capability.

Verified:

- XcodeBuildMCP Debug builds succeeded without source warnings on iPhone 17 Pro and iPad Pro 11-inch (M5) Simulators running iOS 26.5.
- XcodeBuildMCP unit suite: 57 passed, 0 failed.
- XcodeBuildMCP UI suite, run serially: 8 passed, 0 failed.
- Interactive semantic-tree and screenshot inspection confirmed the Library, independent CurrentSongBar targets, and Player sheet on both iPhone and iPad.
- Physical iPhone 17 Pro Max running iOS 26.5.2: Debug and Release device builds passed; the signed products each contain exactly `UIBackgroundModes = [audio]`.
- Physical iPhone 17 Pro Max running iOS 26.5.2: direct serial unit suite passed 57 tests with 0 failures (64 parameterized executions), and direct serial UI suite passed 8 tests with 0 failures (11 parameterized executions). These are the physical-device equivalents of `check.sh` and `check-all.sh`, whose scripts force unsigned Simulator testing.
- Physical iPhone 17 Pro Max hands-on acceptance passed with a real imported song: playback continued on the Home Screen and while locked, foreground return synchronized the advanced position, paused playback remained silent in the background and while locked, and terminating then relaunching Resona remained silent.

Additional non-blocking manual coverage:

- Audible interactive playback across every supported fixture family, Dark Mode, Reduce Motion, and a hands-on VoiceOver session remain manual checks; automated state, accessibility identifier, and accessibility text-size coverage passes.

## Expected source map

The exact split may tighten during implementation, but the intended ownership is:

```text
Resona/Playback/
├── Domain/
│   ├── PlaybackItem.swift
│   ├── PlaybackPhase.swift
│   └── PlaybackFailure.swift
├── Engine/
│   ├── AudioPlaybackEngine.swift
│   ├── AVAudioPlayerEngine.swift
│   ├── AudioSessionControlling.swift
│   └── AVAudioSessionController.swift
├── Library/
│   ├── PlaybackItemProviding.swift
│   └── LibraryPlaybackItemProvider.swift
└── Presentation/
    ├── PlaybackStore.swift
    ├── CurrentSongBar.swift
    └── PlayerView.swift
```

Do not create separate Swift packages or shared abstractions for this slice. The folders express ownership inside the existing application target.

## Definition of ready for coding

- Basic Playback was Active when coding began, and its failure, seek, natural-end, and minimum background behavior was resolved.
- This plan fixes the initial engine choice, authoritative state owner, Library lookup boundary, session activation policy, stale-event protection, presentation ownership, and test layers.
- No SwiftData schema change, migration, third-party dependency, deployment-target change, bundle-identifier change, or MediaPlayer integration is required.
- The only capability change is the Audio background mode, which was explicitly approved before it was added.
- Any discovery requiring queue persistence, automatic interruption recovery, new entitlements, destructive Library mutation, or behavior owned by Playback Integration must pause and update the owning specification or execution plan before implementation continues.
