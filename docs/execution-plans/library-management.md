# Library Management Execution Plan

## Status

Complete

## Outcome

Implement the Library Management slice in which a user can remove an available
or unavailable song from Resona, understand the destructive consequences before
confirming, and rely on the removal remaining accepted across failure,
interruption, and relaunch.

This plan completes the removal subsets of Experience Foundation, Library
Foundation, and Music Library. It integrates removal with the implemented
single-song Basic Playback state without activating queues or any other Playback
Integration behavior.

## Source documents

- [Experience foundation](../product-specs/experience-foundation.md)
- [Library foundation](../product-specs/library-foundation.md)
- [Music library](../product-specs/music-library.md), Library Management stage
- [Basic playback](../product-specs/basic-playback.md)
- [Playback integration](../product-specs/playback.md)
- [Architecture](../../ARCHITECTURE.md)
- [Engineering guidelines](../engineering-guidelines.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)

## Slice boundaries

### In scope

- A native Remove action for every available and unavailable song row
- A destructive confirmation that identifies the song, managed resources, the
  unchanged original external file, and whether current playback will stop
- Immediate prevention of new playback selection for the identity while an
  accepted removal is being established
- Stopping and clearing the implemented current playback item when it matches
  the removed identity
- A durable pending-removal record that is not an active library song or a
  duplicate-import candidate
- Idempotent deletion of app-managed audio and artwork followed by final removal
  of the pending record
- Automatic pending-removal reconciliation at launch and before a library
  mutation
- Actionable Try Again feedback when managed-resource cleanup cannot finish
- A Re-import recovery action on unavailable song rows using the existing shared
  import presentation
- Additive schema migration, deterministic unit and integration coverage,
  critical UI coverage, previews, and interactive accessibility inspection

### Deferred

- Queue creation, queue removal, next, previous, shuffle, and repeat
- System Now Playing metadata, remote commands, restoration, and broader
  interruption or route-change policy
- Batch selection or batch removal
- Undo, Trash, Recently Deleted, or restoration of an accepted removal
- Removing a song from PlayerView or CurrentSongBar
- Album, artist, playlist, and search management
- Removing the retained scaffold `Item` model
- User-edited metadata and cross-device synchronization

The current runtime has no queue, so a removal has no queue occurrences to
clear. The implementation must introduce only a narrow playback invalidation
boundary for the current item and in-flight selection. It must not add queue
types, empty queue state, transport controls, or queue placeholders. Playback
Integration will extend the same boundary when queues become Active.

## Resolved removal semantics

- Present confirmation before beginning any mutation.
- Confirmation is not the durable acceptance point. A removal becomes accepted
  only when its pending-removal record is saved atomically with removal of the
  active song record.
- Before that transaction, reserve the shared mutation gate, then block new
  selection of the identity and invalidate any in-flight or current Basic
  Playback reference to it. If the gate is already busy, leave playback and the
  library unchanged.
- If the transaction cannot be saved, the removal was not accepted. Unblock the
  identity, keep the song in the library, and present a retryable failure. Do not
  claim that the song was removed.
- After the transaction succeeds, the removal has no Undo. The song stays absent
  from active fetches and duplicate matching even if audio or artwork cleanup is
  incomplete.
- Removing the current item stops the engine, deactivates the audio session,
  clears all current playback state, and dismisses its persistent current-song
  affordance. Removing any other item leaves current playback unchanged.
- Removing an unavailable song follows the same transaction. Missing managed
  audio or artwork is treated as already cleaned up, so cleanup remains
  idempotent.
- Re-importing content after its accepted removal creates a new identity because
  pending-removal records do not participate in duplicate recovery.
- Resona deletes only validated filenames under its managed Audio and Artwork
  directories. It never retains or deletes the original external URL.

## Architectural shape

```text
ResonaApp
  -> constructs repository, managed-media store, shared mutation gate,
     audio importer, removal service, PlaybackStore, and LibraryStore
  -> injects LibraryStore, PlaybackStore, and the existing import presentation

LibraryView
  -> exposes native Remove actions for all song rows
  -> exposes Re-import for unavailable rows
  -> owns item-driven confirmation presentation
  -> renders LibraryStore removal progress and retryable cleanup feedback

LibraryStore (@MainActor, @Observable)
  -> owns displayed songs plus transient removal presentation state
  -> coordinates the narrow playback-removal handshake
  -> calls LibraryRemovalService and refreshes the authoritative snapshot

PlaybackStore (@MainActor, @Observable)
  -> temporarily blocks selection of an identity being removed
  -> invalidates matching in-flight selection work
  -> stops and clears a matching current item
  -> does not gain queue state or Library persistence responsibility

LibraryRemovalService (actor)
  -> serializes removal and maintenance work through LibraryMutationGate
  -> begins the durable repository removal transaction
  -> removes app-managed resources idempotently
  -> finalizes tombstones or reports pending cleanup
  -> reconciles pending removals before general managed-storage cleanup

SwiftDataLibraryRepository (@ModelActor)
  -> atomically replaces an active LibrarySongRecord with a
     LibrarySongRemovalRecord
  -> excludes removal records from active fetch and duplicate lookup
  -> reports pending cleanup work and all still-owned resource references

ManagedMediaStore (actor)
  -> removes only validated managed audio and artwork filenames
  -> treats already-missing resources as successful cleanup
  -> preserves pending-removal resources during general reconciliation
```

SwiftData models, `ModelContext`, and filesystem URLs do not cross the Library
persistence and storage boundaries. Playback receives only stable identity
invalidation and never performs Library persistence or resource deletion.

## Persistence design

### Schema version

Add `ResonaSchemaV2` version 3.0.0 containing `Item`, `LibrarySongRecord`, and
`LibrarySongRemovalRecord`. Extend `ResonaMigrationPlan` with a lightweight
V1-to-V2 stage. Retain V0 and V1 so existing stores migrate through the complete
non-destructive chain.

Before adopting V2, add on-disk migration tests for every supported prior
schema. Open an actual V0 store through the complete V0-to-V1-to-V2 chain and an
actual populated V1 store through V2. Verify that existing `Item` and active
song records remain intact. If adding the removal model cannot migrate without
deleting or recreating data, stop and revise the plan; never use store deletion
as fallback.

### LibrarySongRemovalRecord

Persist the minimum information needed to prove intent, finish cleanup, and
identify a failure to the user:

| Field | Swift representation | Rules |
| --- | --- | --- |
| `id` | `UUID`, unique | The removed song identity; never reused as a new import. |
| `title` | `String` | Snapshot used only to identify pending cleanup feedback. |
| `managedAudioFilename` | `String` | Former managed relative filename; never an external or absolute URL. |
| `managedArtworkFilename` | `String?` | Former optional managed relative artwork filename. |

Do not copy fingerprints, artist, album, duration, availability, playback state,
or speculative audit timestamps into the removal record. They are unnecessary
for cleanup and would make the tombstone a second song model.

### Repository operations

Extend `LibraryRepository` with focused typed operations equivalent to:

- `beginRemoval(id:)`: fetch the active record, insert its removal record, delete
  the active record, and save once. Return the immutable removal value needed by
  cleanup. A missing active identity is a typed result rather than a successful
  second removal.
- `pendingRemovals()`: return deterministic immutable cleanup values without
  exposing SwiftData models.
- `finalizeRemoval(id:)`: delete the matching removal record after resource
  cleanup. Make a repeated finalization safe when the record is already absent.
- `resourceReferences()`: include resources owned by active song records and
  pending-removal records. General orphan reconciliation must not bypass removal
  failure reporting by deleting a tombstone's resources independently.

`fetchSongs`, `song(id:)`, and `duplicateCandidates` continue to query only
`LibrarySongRecord`, so pending removals are neither playable nor candidates for
Already Imported or unavailable-identity restoration.

When `beginRemoval` fails to save, roll back or discard the affected model
context changes before returning failure. Tests must verify that no tombstone or
partially deleted active record leaks from a failed transaction.

## Library mutation serialization

Import, removal, pending-removal retry, and managed-storage reconciliation share
the same repository and directories. Introduce a small actor-owned
`LibraryMutationGate` and inject it into `AudioImportService` and
`LibraryRemovalService`.

The gate records one active mutation token across awaited work. Beginning a
second mutation returns a typed busy result; it does not interleave file commits,
record changes, reconciliation, or playback invalidation for a removal that
cannot proceed. Removal reserves the token before invalidating playback and
holds it through the repository transaction and managed-resource cleanup. Token
release is guaranteed with `defer` on success, failure, and cancellation. Keep
the existing `AudioImportService` single-import protection; the shared gate adds
cross-service serialization rather than replacing import-session ownership.

Library presentation normally prevents simultaneous import and removal because
import progress is modal. The gate remains required for correctness across
programmatic calls, retry actions, launch preparation, and future presentation
changes.

## Removal transaction

For a confirmed song identity:

1. `LibraryRemovalService` reserves the shared mutation gate. If another
   mutation owns it, return Busy before changing Library or Playback state.
2. `LibraryStore` asks the playback-removal boundary to block that identity.
   `PlaybackStore` invalidates matching selection generation work and stops and
   clears the matching current item. An unrelated current item is unchanged.
3. The repository atomically inserts `LibrarySongRemovalRecord`, deletes the
   active `LibrarySongRecord`, and saves.
4. If step 3 fails, the service releases the gate and returns Not Accepted.
   `LibraryStore` removes the temporary playback block, refreshes the unchanged
   library, and presents Try Again.
5. After step 3 succeeds, `LibraryStore` may remove the temporary playback block:
   fresh playback lookup can no longer resolve the identity, and stale selection
   work has already been invalidated.
6. The service removes the managed audio and artwork using the immutable removal
   value. Missing files are success; invalid filenames or other filesystem
   failures leave the tombstone intact.
7. After resource cleanup succeeds, the repository deletes the removal record
   and saves. If this final save fails, keep reporting pending cleanup; a later
   retry safely repeats idempotent file removal and finalization.
8. Refresh the LibraryStore snapshot. A successful or pending-cleanup removal
   stays absent from the Songs List. Pending cleanup identifies the song and
   offers Try Again.

Once the repository transaction in step 3 commits, cancellation must not undo or
abandon the removal. Cooperative cancellation may stop presentation from waiting,
but cleanup remains represented durably and is retried during reconciliation.

## Playback invalidation

Add a narrow Library-to-Playback protocol rather than passing `PlaybackStore`
into persistence or file storage. The implemented PlaybackStore behavior must:

- reject `select(songID:)` while that identity is temporarily blocked;
- advance `selectionGeneration` and clear `pendingSelectionID` when a matching
  selection is in flight;
- call the existing engine stop and audio-session deactivation path when the
  current item matches;
- clear current item, phase, position, duration, failure, and active session so
  no current-song UI remains;
- leave an unrelated current item and engine session unchanged; and
- remove the temporary block after the repository accepts or rejects the
  transaction, relying on fresh repository lookup after acceptance.

Add deterministic race coverage in which item resolution completes after
removal begins. The stale result must not prepare audio or recreate the removed
current item.

This boundary represents only the current Basic Playback runtime. Future queue
work must extend its own authoritative state owner to remove all queue
occurrences before Library resources are deleted; this plan must not predict or
persist that queue representation.

## Launch reconciliation and retry

Library preparation runs in this order while holding the shared mutation gate:

1. Fetch all pending-removal values in deterministic UUID order.
2. For each value, retry idempotent audio and artwork cleanup.
3. Finalize each successfully cleaned tombstone.
4. Retain failed tombstones and return typed issues containing stable ID and
   display title.
5. Fetch resource references from remaining active and removal records.
6. Run the existing managed-store reconciliation for abandoned staging and
   genuinely unreferenced final files.
7. Fetch active songs for presentation.

The same preparation runs before a new import or removal mutation as applicable,
without recursively reacquiring the gate. A user-triggered Try Again targets the
selected removal record and then refreshes both cleanup issues and the active
song snapshot.

Do not represent cleanup failure as an unavailable active song. The active song
was already removed; feedback is a separate pending-removal issue. Do not expose
technical filesystem details in user-facing text.

## SwiftUI state and presentation

- `LibraryView` keeps the selected confirmation candidate in one item-driven
  local state value. Do not add separate booleans for available, unavailable, or
  currently playing confirmations.
- Add a trailing destructive swipe action with full-swipe disabled for every
  song. Expose the same Remove operation as a named accessibility action so it
  remains usable without a swipe gesture.
- Add Re-import for unavailable rows through a native row action and named
  accessibility action. Reuse `audioImportPresentation`; do not duplicate file
  picker, import session, fingerprint, or restoration logic.
- Confirmation names the song and states that Resona's managed audio and artwork
  will be deleted while the original file remains unchanged. When the identity
  is the current playback item at presentation time, also state that playback
  will stop. Recheck current identity when the user confirms.
- Disable repeated removal for the identity while its request is active. Do not
  block playback controls or unrelated rows during managed-resource cleanup.
- After durable acceptance, remove the song row through the refreshed
  authoritative `LibraryStore` snapshot. Do not optimistically mutate a private
  view copy of the list.
- Present a pending cleanup issue with the affected title, concise non-technical
  text, Try Again, and a dismiss action. If multiple launch failures exist, keep
  a deterministic issue queue so each affected song can be identified.
- If all active songs have been removed, preserve the existing offline-copy empty
  state and primary Choose Files action.

Add deterministic previews for:

- removal confirmation for a non-current song;
- removal confirmation that states current playback will stop;
- unavailable-row Re-import and Remove actions;
- removal in progress; and
- pending cleanup failure with Try Again.

All destructive and recovery controls need stable accessibility labels. Add
identifiers only where UI tests require them; keep user-visible text localization
ready and avoid assembling sentences from fragments.

## Failure mapping

| Failure boundary | User-visible result | Durable state |
| --- | --- | --- |
| Playback invalidation | Do not begin removal; keep the row and offer Try Again if the boundary cannot establish safety. | Active song remains. |
| Mutation already active | Leave playback unchanged, keep the row, and ask the user to try again after current work finishes. | No removal record. |
| Begin-removal persistence save | “Song Couldn’t Be Removed” with Try Again. | Active song remains; no tombstone. |
| Audio or artwork cleanup | Song stays absent; identify it and offer Try Again. | Tombstone remains. |
| Final tombstone save | Song stays absent; identify it and offer Try Again. | Tombstone remains; missing files make retry idempotent. |
| Launch reconciliation | Load active songs and separately report each retained cleanup issue when active records can still be read safely. | Failed tombstones remain for later retry. |
| Active library fetch | Use the existing Library Unavailable state. | No destructive fallback or store recreation. |

Errors remain typed below presentation. Never log original external paths,
metadata contents, or managed audio bytes.

## Test design

### Unit and integration tests with Swift Testing

| Area | Required coverage |
| --- | --- |
| V0/V1-to-V2 migration | An actual V0 store survives the complete migration chain, and an actual populated V1 store preserves existing `Item` and song records. |
| Repository transaction | Begin removal atomically creates one tombstone and removes one active record; save failure leaves the active record intact; missing and repeated identities are deterministic. |
| Repository filtering | Active fetch, stable-ID lookup, and duplicate candidates exclude tombstones; resource references include active and pending-removal files. |
| Managed cleanup | Audio and artwork delete together when present; either may already be missing; invalid filenames cannot escape managed roots; partial failure is safe to retry. |
| Mutation gate | Import, removal, retry, and reconciliation never interleave; release occurs after success, failure, and cancellation. |
| Removal service | Available and unavailable removals, begin failure, partial cleanup, finalization failure, explicit retry, and launch retry produce the documented outcomes. |
| Playback invalidation | Current removal stops and clears state; unrelated removal preserves playback; a busy mutation leaves playback unchanged; blocked selection is rejected; stale resolution cannot recreate a removed item; rejected persistence unblocks future selection. |
| LibraryStore | Confirmation execution, progress, authoritative refresh, empty transition, failure queue, and Try Again remain deterministic. |
| Presentation text | Current and non-current confirmations describe the correct consequences; cleanup failures map to non-technical actionable text. |

Use in-memory SwiftData containers for repository behavior and an isolated
on-disk container for migration and relaunch recovery. Use isolated temporary
managed-library roots for cleanup. Inject failures at repository, media-store,
and playback boundaries instead of changing real file permissions globally.

### UI tests

- Removing a non-current available song requires confirmation, leaves current
  playback unchanged, and removes only the selected row.
- Removing the current song uses the playback-specific confirmation, clears
  CurrentSongBar, and removes the row.
- Canceling confirmation changes neither library nor playback.
- An unavailable row cannot start playback and exposes Re-import and Remove.
- Removing the final active song returns to the existing empty state.
- A cleanup-failure scenario keeps the song absent, identifies it, and drives
  Try Again to completion.
- Remove, Cancel, Re-import, and Try Again remain discoverable through the
  accessibility hierarchy at an accessibility text size.

Use debug-only injected repositories, removal services, and playback adapters.
Production behavior must not branch on UI-test arguments outside `DEBUG`.

### Interactive verification

- Inspect confirmation and recovery presentation on current iPhone and iPad
  Simulators in portrait and landscape where supported.
- Inspect Dark Mode, Reduce Motion, VoiceOver order, and accessibility XXXL.
- Import a real supported file, remove it, verify its managed copy and artwork
  are gone, and verify the original external file is unchanged.
- Remove the current song while playing and confirm audio stops immediately and
  no player or current-song affordance retains the identity.
- Force or inject interrupted cleanup, relaunch, and verify the song never
  returns as playable while automatic retry converges.
- Re-import the previously removed bytes and verify a new stable identity is
  created.

## Verification commands

- Run targeted repository, storage, removal-service, PlaybackStore, and
  presentation tests while implementing each boundary.
- Run `./scripts/check.sh` after every business-logic milestone.
- Run `./scripts/check-all.sh` before declaring Library Management complete.
- Build and launch on current iPhone and iPad Simulators with the latest installed
  iOS runtime.
- Report any physical resource-cleanup or relaunch check that could not run and
  explain why.

## Implementation sequence

### 1. Domain, V2 schema, and repository transaction

- Add immutable pending-removal values and typed repository outcomes.
- Add `LibrarySongRemovalRecord`, V2 schema, V1-to-V2 migration, and migration
  coverage.
- Implement begin, pending, finalize, filtering, and owned-reference behavior.
- Add repository tests including injected save failures.
- Exit criterion: a committed intent cannot appear in active fetch, playback
  lookup, or duplicate matching, and a failed transaction leaves the active song
  intact.

### 2. Mutation serialization, cleanup, and reconciliation

- Add the shared mutation gate to import and removal composition.
- Add `LibraryRemovalService` transaction, idempotent resource cleanup, explicit
  retry, and ordered launch reconciliation.
- Extend storage and service fakes for deterministic partial failures.
- Exit criterion: every interruption after durable acceptance converges through
  retry without restoring an active song or losing cleanup ownership.

### 3. Basic Playback invalidation

- Add the narrow playback-removal protocol and temporary selection block.
- Clear matching current and in-flight state through existing engine and audio
  session ownership.
- Add state and race tests before wiring presentation.
- Exit criterion: no matching current or stale selection can survive the removal
  handshake, while unrelated playback remains unchanged.

### 4. Library presentation and recovery

- Add row removal and unavailable Re-import actions, item-driven confirmation,
  progress protection, cleanup feedback, and Try Again.
- Refresh through `LibraryStore` and preserve the final-song empty state.
- Add previews, localization-ready text, accessibility actions, and critical UI
  tests.
- Exit criterion: available, unavailable, current, final-song, cancel, failure,
  and retry flows are coherent on iPhone and iPad.

### 5. Delivery verification and documentation

- Run the required fast and full suites plus interactive Simulator checks.
- Update `ARCHITECTURE.md` with V2, removal ownership, mutation serialization,
  playback invalidation, and reconciliation flow.
- Update product-spec implementation statuses only for acceptance criteria that
  were actually verified.
- Record completed commands, device coverage, warnings, and unverified checks in
  this plan.
- Exit criterion: required builds and tests pass, documentation matches runtime,
  and removal is no longer described as deferred or nonexistent.

## Definition of ready for coding

- Experience Foundation, Library Foundation, and Music Library are Active and
  already resolve the behavior required by this slice.
- The cross-feature policy for removing the current item is resolved. No queue
  exists in the current runtime, so queue implementation is not a prerequisite.
- This plan fixes the durable intent model, migration direction, transaction
  boundary, cleanup ownership, playback handshake, UI feedback, and test layers.
- The schema change is additive and preserves `Item` and existing song data.
- No deployment target, bundle identifier, signing setting, capability,
  entitlement, background mode, or third-party dependency change is required.

Implementation may begin with sequence 1. Any discovery that requires deleting
the existing store, weakening accepted-removal durability, implementing queue
state, changing a capability, or touching the user's original external file must
stop for approval and update the owning product specification or architecture
document first.

## Implementation record

### 2026-07-14 — Persistence milestone

- Added immutable pending-removal domain values and typed begin-removal results.
- Added `ResonaSchemaV2` and `LibrarySongRemovalRecord` through the additive
  V0-to-V1-to-V2 migration chain.
- Added atomic begin-removal, deterministic pending-removal fetch,
  idempotent finalization, active-query filtering, and combined owned-resource
  references to `SwiftDataLibraryRepository`.
- Verified that injected begin-removal save failure rolls back both the active
  deletion and tombstone insertion, while finalization failure preserves the
  tombstone for retry.
- Verified actual V0-to-V2 and populated V1-to-V2 on-disk migrations.
- `./scripts/test-unit.sh`: passed on iPhone 17 Pro Simulator, iOS 26.5.
- `./scripts/check.sh`: passed on iPhone 17 Pro Simulator, iOS 26.5, after
  removing new concurrency warnings.

### 2026-07-14 — Mutation cleanup milestone

- Added `LibraryMutationGate` reservations shared by import, removal, retry, and
  reconciliation, including busy outcomes and release after success, failure,
  and cancellation.
- Added `LibraryRemovalService` with durable begin-removal coordination,
  idempotent audio and artwork cleanup, tombstone finalization, explicit retry,
  and typed pending-cleanup issues.
- Ordered launch and pre-import reconciliation so deterministic pending removals
  are retried before remaining resource references protect tombstone-owned files
  during general orphan cleanup.
- Composed the gate and removal service at app launch; initial Library loading
  now runs pending-removal reconciliation before fetching active songs.
- Added deterministic coverage for busy mutations, unavailable resources,
  begin and finalization failures, partial cleanup, explicit retry, launch order,
  cross-service import serialization, and cancellation before and after durable
  acceptance.
- `./scripts/build.sh`: passed for the generic iOS Simulator destination.
- `./scripts/test-unit.sh`: passed on iPhone 17 Pro Simulator, iOS 26.5.
- `./scripts/check.sh`: passed on iPhone 17 Pro Simulator, iOS 26.5.

### 2026-07-14 — Basic Playback invalidation milestone

- Added the narrow main-actor `PlaybackRemovalInvalidating` boundary without
  exposing `PlaybackStore` to Library persistence or managed storage.
- Added temporary stable-ID selection blocking, matching selection-generation
  invalidation, and matching current-item clearing through the existing engine
  stop and audio-session deactivation path.
- Preserved unrelated current playback and engine sessions while another song
  identity is blocked for removal.
- Added deterministic state and race coverage for current-item clearing,
  unrelated playback preservation, blocked and later unblocked selection, and a
  stale lookup completing after removal invalidation begins.
- `./scripts/test-unit.sh`: passed on iPhone 17 Pro Simulator, iOS 26.5.
- `./scripts/check.sh`: passed on iPhone 17 Pro Simulator, iOS 26.5.

### 2026-07-14 — Library presentation milestone

- Added row-level Remove for available and unavailable songs with full-swipe
  disabled, plus unavailable-row Re-import through the shared import
  presentation and equivalent named accessibility actions.
- Added one item-driven confirmation route with current-playback consequences,
  explicit managed-resource and original-file messaging, destructive Remove,
  and Cancel.
- Kept the pre-confirmation swipe action visually red without assigning the
  destructive button role, preventing List from briefly animating the row as
  deleted before confirmation. Removal text also replaces internal UUID or
  UUID-filename titles with the existing Unknown Title fallback.
- Publish the accepted-removal Library snapshot once and animate its stable-ID
  row change with a native leading-edge transition, so the confirmed song slides
  out without a duplicate-refresh flash.
- Extended `LibraryStore` to coordinate removal through `LibraryRemoving`,
  prevent repeated requests per identity, disable selection while removal is in
  progress, invoke playback invalidation, refresh from the authoritative
  repository after acceptance, and preserve the final-song empty state.
- Added deterministic request-failure and pending-cleanup feedback, including a
  stable launch issue queue, non-technical messages, Dismiss, and targeted Try
  Again without restoring a removed song.
- Added previews for current and non-current confirmation, removal progress,
  and pending cleanup, plus unit coverage for coordination, repeated-request
  protection, authoritative refresh, retry, and presentation text.
- Added UI coverage for current and non-current removal, cancellation,
  unavailable actions, final-song removal, cleanup failure and retry, and
  destructive/recovery controls at accessibility XXXL.
- `./scripts/test-unit.sh`: passed on iPhone 17 Pro Simulator, iOS 26.5.
- `./scripts/test-ui.sh`: passed 17 tests on iPhone 17 Pro Simulator, iOS 26.5.
- Targeted sequence 4 UI suite: passed 6 tests on iPad Pro 13-inch (M5)
  Simulator, iOS 26.5.

Implementation sequence 4 is complete. Sequence 5 has completed its automated
delivery suites and representative device launches; the targeted hands-on
checks recorded below remain.

### 2026-07-14 — Delivery verification in progress

- `xcodebuild` unit and integration testing passed 87 tests in 16 suites on
  Leon's iPhone running iOS 26.5.2 using the existing automatic signing
  configuration.
- `xcodebuild` UI testing passed 18 tests on the same physical iPhone: 14
  feature journeys plus four Light Mode, Dark Mode, portrait, and landscape
  launch checks. The journeys include current and non-current removal,
  cancellation, final-song removal, unavailable recovery actions, cleanup
  failure and retry, and accessibility text sizing.
- An ordinary non-test launch on the physical iPhone was inspected through
  iPhone Mirroring in Dark Mode. An existing managed song started playback and
  exposed the persistent current-song surface and Pause action. Existing user
  library data was preserved; no personal song was removed for this check.
- `./scripts/check.sh` passed 87 tests on the iPhone 17 Pro Simulator running
  iOS 26.5.
- `./scripts/check-all.sh` passed 87 unit and integration tests plus 18 serial
  UI tests on the iPhone 17 Pro Simulator running iOS 26.5.
- XcodeBuildMCP built, installed, launched, and inspected ordinary Debug builds
  on the iPhone 17 Pro and iPad Pro 13-inch (M5) Simulators running iOS 26.5.
  The iPhone presented a persisted song and current-song surface; the iPad
  presented the offline-copy empty state and reachable Choose Files action.
- Observed toolchain diagnostics did not fail validation: the UI runner logged
  a missing debugger-version snapshot, the Simulator runtime logged duplicate
  WebCore/WebKit accessibility loader classes, and targets without App Intents
  logged skipped metadata extraction. No application warning was identified.
- With Reduce Motion enabled on the iPhone 17 Pro Simulator, three targeted UI
  tests passed for current-song removal, cleanup failure and Try Again, and
  removal/recovery controls at accessibility XXXL. The setting was restored to
  its original disabled state after the run.
- The populated-library accessibility hierarchy was inspected in order. It
  exposed Import Audio, the Songs heading, and one combined element per song
  containing title, artist, and duration or Unavailable. Available songs
  exposed the named Remove action; the unavailable song exposed Remove and
  Re-import. A physical-iPhone VoiceOver session then confirmed logical
  top-to-bottom traversal without duplicate artwork focus. A representative
  row was spoken as title, artist, duration, button role, Starts Playback hint,
  and Actions Available, confirming that the combined row content and named
  Remove action are discoverable.
- A disposable external `supported-aac.m4a` fixture was copied to an isolated
  iCloud Drive folder and imported on Leon's physical iPhone. It appeared as
  Fixture Title by Fixture Artist, selected for playback, and reached natural
  end. The managed audio was created as
  `A40B43E2-8107-4249-97E2-AF01D525731C.m4a` and disappeared after confirmed
  removal. The fixture had no embedded artwork, so no managed artwork was
  created for this run.
- The external fixture retained SHA-256
  `5a583b4e455ae65cdfdc26cdd9ea0c426cbf193c37b6956bf00563a85bea7acc`,
  matching the repository fixture after removal. Re-importing the same bytes
  reported Imported rather than Restored and created the new identity
  `72C50EAF-A516-41BF-831E-2DDB9E7673C4`; its managed audio also disappeared
  after the second confirmed removal. The other ten managed audio files were
  unchanged throughout.
- A disposable MP3 with an embedded PNG cover was generated outside the
  repository and imported on the physical iPhone. The cover appeared in the
  Songs List, and the managed resources shared identity
  `ABD19463-C963-4010-8784-3B08F10EBF20` across the `.mp3` and `.png` files.
  Both disappeared after confirmed removal, the Artwork directory returned to
  empty, the other ten managed audio files were unchanged, and the external
  file retained SHA-256
  `ffaf7884940b1894d80886b816f99ca104adce3290cc2f90e23ea82c7cd83bbb`.
- A forced process interruption was not injected into the physical app because
  its sandbox contained personal library data and deterministic isolation was
  available. `cancellationAfterAcceptanceKeepsCleanupOwnership` verifies that
  cancellation after durable acceptance retains pending cleanup;
  `launchReconciliationRetriesInOrderBeforeOrphanCleanup` verifies relaunch
  ordering and convergence; the cleanup-failure UI journey verifies absent-song
  feedback and Try Again. This satisfies the delivery checklist's isolation
  rule without risking personal data.

Implementation sequence 5 and this execution plan are complete.
