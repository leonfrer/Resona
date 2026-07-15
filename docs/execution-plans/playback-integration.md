# Playback Integration Execution Plan

## Status

Complete 2026-07-15. Implementation, automated iPhone Simulator verification,
iPhone physical-device system-integration acceptance, and representative iPad
layout and accessibility inspection are complete.

## Outcome

Extend the implemented Basic Playback runtime with one authoritative queue, next and previous navigation, shuffle and repeat modes, a readable queue presentation, iOS Now Playing and remote-command integration, interruption and route-change recovery, removal invalidation, and silent relaunch restoration.

This plan preserves the current `PlaybackStore`, stable Library identity boundary, `AVAudioPlayer` engine, Audio background mode, and existing single-song failure behavior. It does not change the deployment target, bundle identifier, signing configuration, entitlements, background modes, or SwiftData schema.

## Source documents

- [Playback integration](../product-specs/playback.md)
- [Basic playback](../product-specs/basic-playback.md)
- [Experience foundation](../product-specs/experience-foundation.md)
- [Library foundation](../product-specs/library-foundation.md)
- [Music library](../product-specs/music-library.md)
- [Quality attributes](../product-specs/quality-attributes.md)
- [Architecture](../../ARCHITECTURE.md)
- [Engineering guidelines](../engineering-guidelines.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
- [Apple: MPRemoteCommand](https://developer.apple.com/documentation/mediaplayer/mpremotecommand)
- [Apple: MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- [Apple: Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- [Apple: Responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)

## Slice boundaries

### In scope

- Snapshot the current visible library identity order when an available song is selected.
- Keep the selected item current while establishing base and traversal queue order.
- Implement Next, Previous, Repeat One, Repeat All, shuffle traversal, and deterministic shuffle history.
- Advance after natural end and skip unavailable or missing identities with a bounded traversal.
- Display current, upcoming, unavailable, shuffle, and repeat queue state without adding queue editing.
- Purge every queue and restoration reference when Library removal begins.
- Publish canonical current-item metadata and live transport values to system Now Playing surfaces.
- Handle Play, Pause, Toggle Play/Pause, Next, Previous, and Change Playback Position remote commands.
- Handle interruption begin and end plus external-route disconnection without false playing state.
- Restore approved queue and position state while remaining silent until a user transport command.
- Add deterministic domain, store, adapter, persistence, presentation, and critical UI coverage.
- Record physical-device evidence for Lock Screen, Control Center, headset commands, interruptions, route disconnection, and silent restoration.

### Deferred

- Queue editing, reordering, manual insertion, per-item removal, and arbitrary queued-item selection
- Playlists, albums, artists, search, streaming, and cross-device queue sources
- Skip intervals, playback rate, ratings, likes, dislikes, bookmarks, and language-option commands
- AirPlay-specific browsing, external queue management, and cross-device handoff
- Gapless playback, crossfade, preloading, audio effects, and equalization
- A new playback engine or migration from `AVAudioPlayer`
- New capabilities, background modes, entitlements, deployment-target changes, or third-party dependencies

## Architectural shape

```text
LibraryView
  -> sends selected stable ID plus the visible ordered identity snapshot
     to PlaybackStore

PlaybackStore (@MainActor, @Observable)
  -> remains the sole authoritative live playback owner
  -> owns current item, phase, position, queue, repeat and shuffle modes,
     selection generations, engine session, and removal blocks
  -> delegates pure navigation decisions to PlaybackQueue
  -> freshly resolves each playback candidate through PlaybackItemProviding
  -> publishes one state projection to app UI, Now Playing, remote commands,
     and the restoration writer

PlaybackQueue (pure Sendable domain value)
  -> owns stable base order, traversal order, current cursor,
     forward/back history, repeat mode, and shuffle state
  -> performs bounded candidate selection without Library or AVFoundation access

PlaybackRestorationStore (actor behind a protocol)
  -> atomically reads and writes one versioned playback snapshot
  -> stores stable identities and scalar state only
  -> never stores Library records, managed URLs, artwork bytes, or playing intent

NowPlayingController / RemoteCommandController
  -> isolate MediaPlayer singleton APIs
  -> render PlaybackStore projections and forward supported commands
  -> never mutate engine or queue state independently

AVAudioSessionController
  -> extends its typed event stream with interruption end and route changes
  -> maps system notifications without choosing transport policy
```

Playback remains an established source boundary inside the application target. It may consume immutable Library values through focused provider interfaces, but it must not access SwiftData records, `ModelContext`, `ManagedMediaStore`, or Library mutation implementation types.

## Domain and state decisions

### PlaybackQueue

- Store stable library IDs as one base order with no duplicates.
- Track current identity independently from array indexes so removal and restoration cannot silently retarget another item.
- Represent repeat as Off, One, or All and shuffle as an explicit mode plus stable traversal order.
- Preserve a forward/back traversal history so Previous and subsequent Next are deterministic under shuffle.
- Keep randomization injectable in tests. Production may use system randomness, but every generated order becomes explicit queue state and is persisted.
- Bound each navigation attempt to the number of remaining identities. The queue domain proposes candidates; `PlaybackStore` resolves availability and reports success or skip back to the queue.
- Leave current state unchanged when a manual boundary command has no candidate.
- At natural end, Repeat One proposes the current identity; otherwise ordinary traversal applies.

### Authoritative PlaybackStore

- Replace `select(songID:)` at the Library entry point with a command that also accepts the ordered visible identity snapshot. Retry continues to target only the current identity and must not rebuild the queue.
- Keep engine session IDs and selection generations as the stale-result boundary while candidate resolution may span several skipped identities.
- Do not prepare two `AVAudioPlayer` instances or claim gapless behavior. Natural advancement prepares the next resolved item only after the prior engine session finishes.
- Expose derived `canGoNext`, `canGoPrevious`, queue entries, repeat mode, and shuffle state for both presentation and system-command capability updates.
- Update Now Playing and restoration from authoritative state changes, not from SwiftUI lifecycle callbacks or duplicated view state.
- Coalesce position persistence so engine ticks do not write on every event. Force a snapshot after committed seeking, pause, current-item or queue changes, mode changes, and transition to inactive or background.

### Queue entry resolution

- Library selection supplies only ordered stable identities. Playback resolves canonical metadata and fresh resource availability through `PlaybackItemProviding`.
- Extend the provider only as needed for ordered batch hydration; do not pass `LibraryStore`, `LibrarySongRecord`, or `ModelContext` into Playback.
- Queue presentation may retain immutable canonical display values, but every transition to audible playback must resolve the selected identity again.
- Missing restored identities are purged. Unavailable identities remain visible and are skipped during traversal.

## Library removal coordination

- Extend the existing `PlaybackRemovalInvalidating` behavior rather than introducing a Library dependency on queue internals.
- `beginRemovalInvalidation(for:)` blocks new selection, invalidates matching in-flight resolution, removes every matching base-order, traversal, history, and persisted reference, and updates system command capabilities.
- If the removed identity is current, stop the engine, deactivate the audio session, clear current state and Now Playing information, and do not advance automatically.
- If it is not current, preserve current playback and the relative order of all remaining identities.
- Persist the invalidated queue before Library-owned managed resources are deleted. `endRemovalInvalidation(for:)` only removes the temporary selection block; it does not recreate queue references.
- Make the invalidation entry point asynchronous if needed to await the restoration flush; Library continues to depend only on the narrow invalidation protocol.
- Add regression coverage for current, next, previous-history, in-flight, repeated-callback, and final-item removal cases.

## System media integration

### NowPlayingController

- Add a focused MediaPlayer adapter owned for the application lifetime by app composition.
- Publish title, artist, album, artwork when available, duration, elapsed time, playback rate, queue index and count, and a stable external content identifier.
- Retain metadata with rate zero for paused, interrupted, stopped-at-end, and failed states; clear the info dictionary when current state is cleared.
- Load and decode artwork without blocking the main actor. Tag artwork work by current identity so a late result cannot overwrite a replacement item.
- Keep dictionary construction and state-to-rate mapping pure and unit-testable outside the singleton adapter.

### RemoteCommandController

- Register one application-lifetime handler for each approved command and explicitly disable unsupported commands.
- Forward commands to `PlaybackStore` on the main actor. The controller must not call `AudioPlaybackEngine` directly.
- Reflect `PlaybackStore` capability changes so Next, Previous, seek, and transport commands return an appropriate MediaPlayer status when unavailable.
- Remove registered targets during teardown and provide an isolated fake command surface for deterministic tests.
- Treat remote and in-app commands as the same store commands, including boundary, repeat, shuffle, failure, and stale-event rules.

## Audio-session integration

- Extend `AudioSessionEvent` with interruption end and a typed resumption recommendation, plus external-route disconnection.
- Preserve the current iOS 26 deployment target path for interruption notifications; do not adopt beta-only APIs or change the deployment target in this slice.
- Track whether the store was playing immediately before interruption. Resume only when that flag and the system recommendation both permit it.
- Pause active playback when the previous route contained headphones or another external output that became unavailable. Do not resume when a new route appears.
- Keep notification parsing in `AVAudioSessionController` and transport decisions in `PlaybackStore`.
- Ignore malformed, irrelevant, duplicated, or stale notifications without changing authoritative state.

## Restoration

- Add a versioned, Codable restoration payload containing base identities, current identity, position, repeat mode, shuffle mode, traversal order, and history. Do not persist engine session IDs, file URLs, metadata, failures, blocked selections, or playing intent.
- Store the payload atomically in a Playback-owned Application Support location behind an actor and injected protocol. This avoids a SwiftData schema change and keeps playback-session state out of Library persistence.
- Treat absent, malformed, unsupported-version, and partially stale snapshots as recoverable input. Sanitize identities against the Library provider and never fail app launch for restoration data.
- Restore a valid item by preparing it and seeking to a clamped finite position while leaving the audio session inactive. Use stopped-at-end when the restored position is at the playable end and paused otherwise, so the next Play preserves Basic Playback's restart behavior. If preparation or resolution fails, apply the approved bounded skip or actionable failure policy without audible playback.
- Clear persisted and system Now Playing state when no valid current identity remains.
- Initiate restoration once from application-lifetime composition before ordinary playback commands can race it. User selection supersedes unfinished restoration through the existing generation mechanism.

## SwiftUI presentation

- Add Previous, primary Play/Pause or Restart, and Next controls to `PlayerView` with independent accessible labels and identifiers.
- Add explicit shuffle and repeat controls whose label, value, symbol, and selected state do not rely on color alone.
- Present the read-only queue in a separate bottom sheet, distinguishing current, upcoming, and unavailable state without creating a second navigation stack or transport owner.
- Keep `CurrentSongBar` focused on compact current metadata, opening the player, and Previous, primary Play/Pause or Restart, and Next controls. Queue modes remain on the separate Queue surface.
- Pass the loaded Songs List's visible identity order with selection. Queue inspection, opening the player, and dismissing the player issue no transport commands.
- Verify layout with accessibility Dynamic Type, VoiceOver order, Dark Mode, Increased Contrast, Reduce Motion, and representative iPhone and iPad sizes.

## Test design

### Pure domain tests

- Base-order Next and Previous boundaries with Repeat Off and Repeat All
- Repeat One natural end versus manual navigation
- Shuffle enable and disable while retaining current identity
- Stable shuffle order, backward history, forward history, and Repeat All wrapping
- Identity removal from base order, traversal order, and history
- Bounded unavailable and missing-item traversal with zero, one, and all candidates invalid
- Restoration sanitization for duplicates, missing current identity, invalid positions, and inconsistent shuffle state

### PlaybackStore tests

- Selection establishes the visible-order queue and starts only the selected item.
- Natural end advances, repeats, skips, or stops according to queue mode.
- In-app and remote commands share identical state transitions.
- Candidate resolution and engine events remain protected by generations and session IDs.
- Interruption begins, recommended and non-recommended ends, repeated notifications, and route disconnection never produce false playing state.
- Current and non-current removal update engine, queue, Now Playing, and restoration consistently.
- Restoration prepares and seeks without activating the audio session or starting the engine, and restores end position as stopped-at-end.
- A user selection supersedes slow restoration without accepting stale results.

### Adapter and persistence tests

- Now Playing dictionaries map canonical metadata, playback rate, elapsed time, artwork identity, and queue position correctly and clear when current clears.
- Remote handlers register once, disable unsupported commands, forward approved commands, and remove targets on teardown.
- Audio-session notifications map interruption and route details into typed events while ignoring malformed input.
- Restoration round trips atomically, tolerates absent and corrupt data, rejects unsupported versions, and coalesces position writes.

### UI tests

- Selecting a populated-list song establishes the expected visible-order queue.
- Player controls expose Previous, Next, shuffle, repeat, and queue state with stable accessibility identifiers.
- Queue inspection and player presentation do not change transport state.
- Current and non-current removal update the visible queue according to policy.
- A debug restoration scenario launches paused at the restored item and position without a Play engine command.
- UI tests assert visible state and control availability, not timing-sensitive audible behavior or exact elapsed ticks.

### Interactive and physical-device validation

- Lock Screen and Control Center metadata, artwork, elapsed position, Play/Pause, Next, Previous, and seeking
- Supported wired or wireless headset commands
- Phone, Siri, alarm, and another audio app interruptions, recording whether the system recommends resumption
- Headphone and external-route disconnection pause behavior and no automatic resume on reconnection
- Background and locked-device queue advancement across natural end
- Terminate and relaunch restoration with no unexpected audible playback
- VoiceOver order and announcements plus accessibility text size on representative iPhone and iPad layouts

Simulator automation cannot establish system remote-command, real interruption, route, or audible background acceptance. Record the physical device, OS, route/accessory, exact scenario, and observed result for each required check.

## Implementation sequence

### 1. Queue domain and selection context — Implemented

- Add queue, repeat, shuffle, history, and injectable-randomness domain types.
- Extend the Library selection handoff with visible stable identity order.
- Integrate queue establishment, manual navigation, natural end, and bounded candidate resolution into `PlaybackStore`.
- Add exhaustive pure-domain and store tests before presentation changes.
- Exit criterion: deterministic tests cover every queue boundary and the store audibly prepares at most one resolved candidate at a time.

### 2. Queue presentation and removal invalidation — Implemented

- Add detailed-player transport, mode controls, and read-only queue presentation.
- Extend removal invalidation across base order, traversal, history, and persisted projection.
- Add preview states, accessibility semantics, and critical UI scenarios.
- Exit criterion: app UI exposes the approved queue behavior and removal leaves no live queued reference to a deleted identity.

### 3. Now Playing, remote commands, and audio-session policy — Implemented

- Add MediaPlayer adapters and application-lifetime composition.
- Extend audio-session notification mapping and store recovery policy.
- Add pure mapping, fake-command, notification, and store transition tests.
- Verify Lock Screen, Control Center, headset, interruption, route, and background advancement on an eligible physical device.
- Exit criterion: every supported system surface drives the same authoritative state and no system surface displays stale playback claims.

### 4. Silent restoration — Implemented

- Add the versioned atomic restoration store and sanitized launch coordination.
- Persist meaningful state transitions with bounded position-write frequency.
- Add relaunch persistence tests, corrupt-state recovery, selection-race coverage, and a debug UI restoration scenario.
- Exit criterion: a terminated app restores the approved logical state and position while remaining silent until explicit user intent.

### 5. Delivery verification and documentation — Automated verification complete

- During implementation, run targeted playback unit tests after each domain or adapter milestone.
- On Simulator, run `./scripts/check.sh` after business-logic milestones and `./scripts/check-all.sh` before completion because this is a user-facing flow change.
- Prefer an eligible physical iPhone or iPad for the equivalent automated test actions and every system-integration acceptance check; use Simulator only where deterministic isolation is required and record why.
- Update `ARCHITECTURE.md` only after implementation is verified, covering queue ownership, MediaPlayer adapters, restoration storage, audio-session events, runtime flow, and source map.
- Update product-spec and execution-plan status only for acceptance criteria actually verified.
- Record commands, destinations, counts, warnings, screenshots or logs where useful, physical accessories, and any unverified risk in this plan.
- Exit criterion: required automated and physical-device checks pass, current architecture matches runtime composition, and no deferred capability is claimed.

## Implementation record — 2026-07-14

Implemented:

- Added one pure queue value with base order, traversal, bounded history, shuffle, repeat, natural-end, removal, and sanitized-restoration rules. Library selection now supplies visible stable-ID order, while every audible transition still resolves fresh canonical Library values.
- Extended `PlaybackStore` as the sole authority for queue navigation, mode changes, removal purge and flush, typed interruption and route decisions, Now Playing projection, remote-command forwarding, and silent restoration races.
- Added MediaPlayer adapters for canonical Now Playing metadata and the approved Play, Pause, Toggle Play/Pause, Next, Previous, and Change Playback Position commands. Unsupported commands remain disabled and unavailable capabilities return a non-success status.
- Added a versioned atomic Application Support snapshot for queue, traversal, history, modes, current identity, and position. Initial writes remain gated until the old snapshot is read, explicit user selection supersedes unfinished restoration, and relaunch never restores a playing intention.
- Added detailed-player previous, next, shuffle, repeat, and read-only queue presentation plus deterministic unit, adapter, persistence, store, and UI coverage.
- Updated the current architecture map and product/execution indexes without changing SwiftData schema, deployment target, bundle identifier, signing, entitlements, background modes, or dependencies.

Verified on an iPhone 17 Pro Simulator running the latest installed iOS 26.5 runtime:

- `./scripts/check-all.sh` passed. The complete `ResonaTests` target passed, followed by 20 serial UI executions with 0 failures: 16 app scenarios and 4 launch configurations.
- A final `./scripts/test-unit.sh` run passed after tightening restoration write gating and its user-selection race assertion.
- The focused silent-restoration UI scenario passed, showing the restored item at `0:30` with a Play action and no automatic audible playback intent.
- `git diff --check` passed, and every internal link in the changed documentation resolves.
- Xcode emitted the existing skipped-AppIntents-metadata, Simulator debugger-version, and duplicate Web accessibility bundle diagnostics. No new application source warning was introduced.

Verified on an iPhone 17 Pro Max running iOS 26.5.2 with first-generation
AirPods Pro:

- Lock Screen and Control Center metadata, Play, Pause, Next, Previous, and seeking behaved consistently with in-app playback.
- AirPods Play, Pause, Next, and Previous commands worked, and disconnecting the AirPods paused playback without automatic resume.
- Phone and Siri interruptions paused and resumed playback according to the system recommendation.
- Starting playback in another music app paused Resona. Stopping that user-selected playback source left Resona paused, correctly preserving the newer user intent instead of automatically reclaiming playback.
- Background and locked-device natural advancement updated the queue and Now Playing state.
- Terminating and relaunching restored the approved logical state without audible playback until an explicit Play command.
- Interactive VoiceOver order, Dynamic Type, Light and Dark Mode, Reduce Motion, Reduce Transparency, and Increased Contrast passed on the iPhone.

Verified on an iPad Pro 11-inch (2nd generation) running iPadOS 27.0 Beta:

- Representative player and Queue layouts passed on iPad.
- VoiceOver, Dynamic Type, Light and Dark Mode, Reduce Motion, Reduce Transparency, and Increased Contrast passed on iPad.

All required automated, system-integration, restoration, visual, and
accessibility acceptance evidence is recorded. This plan is Complete and the
Playback Integration product specification is Implemented.

## Risks and controls

- **MediaPlayer singleton leakage:** register once, disable unsupported commands explicitly, and remove targets during adapter teardown and tests.
- **Non-main remote callbacks:** cross into the main actor before reading or mutating `PlaybackStore`; never touch the engine from callback threads.
- **Stale artwork or resolution:** tag asynchronous work by stable identity and generation before publishing results.
- **Queue scan loops:** bound every availability scan to one traversal and test all-invalid queues.
- **Persistence churn:** coalesce position writes and force snapshots only at meaningful lifecycle or transport boundaries.
- **Restoration races:** let explicit user selection invalidate unfinished restoration through one generation boundary.
- **Removal divergence:** purge live and persisted references before resource deletion and make repeated invalidation idempotent.
- **System-only evidence gaps:** keep deterministic policy tests but require physical-device verification for route, interruption, Lock Screen, Control Center, headset, and audible background behavior.

## Expected source map

The exact file split may tighten during implementation, but intended ownership is:

```text
Resona/Playback/
├── Domain/
│   ├── PlaybackQueue.swift
│   ├── PlaybackRepeatMode.swift
│   └── PlaybackRestorationSnapshot.swift
├── Engine/
│   ├── AudioSessionControlling.swift
│   └── AVAudioSessionController.swift
├── Integration/
│   ├── NowPlayingControlling.swift
│   ├── MPNowPlayingController.swift
│   ├── RemoteCommandControlling.swift
│   └── MPRemoteCommandController.swift
├── Library/
│   └── existing provider and removal-invalidation boundaries
├── Persistence/
│   ├── PlaybackRestoring.swift
│   └── FilePlaybackRestorationStore.swift
└── Presentation/
    ├── PlaybackStore.swift
    ├── PlayerView.swift
    └── existing playback presentation support
```

Do not create a separate Swift package or general-purpose media abstraction for this slice. Add files only when they express one of these concrete responsibilities.

## Definition of ready for coding

- Playback Integration is Active and its queue, interruption, route, unavailable-item, remote-command, repeat, shuffle, restoration, and removal policies are resolved.
- The plan fixes authoritative ownership, queue traversal shape, Library handoff, MediaPlayer isolation, restoration storage, lifecycle coordination, and required test layers.
- No SwiftData schema, migration, capability, entitlement, deployment-target, bundle-identifier, signing, or third-party dependency change is authorized or required.
- Any discovery that changes approved user-visible behavior or requires a deferred platform capability must pause implementation and return to the owning specification for approval.
