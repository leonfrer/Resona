# Playback Integration

## Status

Implemented

## User outcome

Users can extend reliable basic playback with a queue, expected iOS system controls, background audio, interruption handling, and useful state restoration.

The queue, interruption, route, restoration, removal, and first-release remote-command behavior in this specification is approved for implementation.

## Depends on

- [Basic playback](basic-playback.md), which establishes the authoritative playback state and reliable foreground controls.
- [Library foundation](library-foundation.md), which provides stable song identities and managed audio-resource availability.
- [Experience foundation](experience-foundation.md), which defines system-consistent navigation, feedback, and motion behavior.

## In scope

- Extend playback with next and previous commands.
- Maintain and display a playback queue.
- Support shuffle and repeat behavior.
- Preserve Basic Playback's minimum background continuation while extending audio-session behavior to system integrations.
- Integrate with the Lock Screen, Control Center, headphones, and remote commands.
- Respond predictably to audio-session interruptions and route changes.
- Restore the agreed previous queue and playback position without automatically starting audible playback.

## Out of scope

- Streaming playback
- AirPlay-specific browsing or queue management
- Cross-device handoff or synchronization
- Audio effects, equalizers, or playback-speed controls
- Gapless playback and crossfade unless separately specified
- Queue reordering, manually adding or removing individual queue items, or jumping directly to an arbitrary queued item
- System rating, like, dislike, bookmark, playback-rate, and skip-interval commands

## User flows

### Start playback

1. The user selects an available song from the library.
2. Resona snapshots the identities in the current visible library order as the queue and makes the selected song current.
3. Playback begins or an actionable failure is shown.
4. The player UI and system Now Playing surfaces reflect the same state.

### Control playback

1. The user sends a transport command from Resona or a supported system surface.
2. The authoritative playback state processes the command.
3. All visible controls update consistently.

### Recover playback

1. Playback is interrupted, the route changes, or the app relaunches.
2. Resona applies the documented recovery policy.
3. The UI and system surfaces reflect the resulting state without claiming playback that is not occurring.

### Inspect the queue

1. The user opens the detailed player.
2. The user opens Queue, which rises from the bottom as a separate system sheet.
3. Resona shows the current queue in its active traversal order, distinguishes the current and unavailable items, and presents shuffle and repeat controls on this surface.
4. Inspecting, changing a queue mode, or dismissing Queue does not issue an unrelated transport command.

## Behavioral requirements

- Playback must have one authoritative state owner.
- App UI and system Now Playing information must reflect the same current item and playback state.
- Commands from different supported surfaces must produce consistent results.
- Playback errors must be reported without corrupting the queue or library.
- An unavailable queue item must not cause an endless retry or silent stall.
- Headphone disconnection and audio-session interruptions must follow documented platform-appropriate behavior.
- Basic Playback owns minimum continuation of already-started single-song playback in the background. This stage owns the additional interruption, route-change, remote-command, queue, and restoration behavior around it.
- Restoration must not automatically begin audible playback when platform expectations or user intent do not support it.
- The first release supports Play, Pause, Toggle Play/Pause, Next, Previous, and Change Playback Position from system remote-command surfaces. Unsupported commands remain disabled.

## Queue and transport policy

- Selecting an available song snapshots every identity in the current visible library order. Later sorting or filtering changes do not mutate that queue.
- The selected identity becomes current. Queue order uses stable library identities rather than copied media or persistence records.
- Without Repeat All, Next at the final playable item and Previous at the first playable item do nothing. With Repeat All, those commands wrap at the boundaries.
- Repeat One restarts the current item only after its natural end. Manual Next and Previous continue to navigate the queue.
- With shuffle off, traversal follows the queue's base order. Enabling shuffle keeps the current item current and establishes one stable shuffled traversal order.
- Shuffle Previous walks the actual traversal history. Moving forward after Previous follows that history before continuing through the existing shuffled order.
- A shuffled traversal order remains stable until the queue changes or shuffle is turned off. Repeat All wraps that same order instead of silently generating a new one.
- When playback advances, Resona searches no more than one complete traversal for a playable item. It skips unavailable or missing items and stops with an actionable error if no playable item remains.
- Natural end follows Repeat One first, then the active queue traversal. At the final playable item without Repeat All, playback stops at the end and retains that current item.

## Interruption and route policy

- When an audio-session interruption begins, Resona pauses and remembers whether playback was active immediately before the interruption.
- When the interruption ends, Resona resumes only when playback was active before it began and the system indicates that resumption is appropriate. Otherwise it remains paused.
- Disconnecting headphones or another external output route pauses active playback and never resumes it automatically.
- Connecting a new output route does not start, pause, or resume playback by itself.
- A user transport command received after an interruption or route change follows the ordinary queue and playback rules.

## Restoration and invalidation policy

- Resona restores the queue identities and base order, current identity, elapsed position, repeat mode, shuffle mode, shuffled traversal order, and traversal history across relaunches.
- Resona does not restore a playing intention. A restored valid current item remains non-playing at the restored position until the user explicitly starts playback. An item restored at its natural end retains Basic Playback's restart-from-beginning behavior.
- Restored identities that no longer exist in the library are discarded. Unavailable library items remain visible in the queue and follow the bounded skip policy.
- If restoration leaves no valid current item, Resona clears the current playback state and system Now Playing information.
- Beginning confirmed library removal removes every queued reference to that identity before library-owned resources are deleted.
- Removing the current item follows Music Library's existing policy: playback stops, the current item is cleared, and Resona does not automatically advance to another queue item.
- Removing a non-current item preserves the current item and the relative order and traversal history of all remaining identities.

## System Now Playing policy

- System Now Playing information reflects the current item's canonical title, artist, album, artwork when available, playable duration, elapsed position, playback rate, and queue position and count.
- Paused, interrupted, stopped-at-end, and failed states retain the current item's metadata with a non-playing rate.
- Replacing the current item updates system information to the replacement without exposing stale metadata or artwork.
- Clearing the current item clears system Now Playing information and disables commands that require a current item.

## Failure cases

- Audio resource is missing, inaccessible, corrupted, or unsupported.
- Audio session activation fails.
- Playback is interrupted by another app or system event.
- The output route changes or disappears.
- A queued song is removed from the library.
- Restored queue data references unavailable library items.
- Remote commands arrive while no valid current item exists.
- Persisted restoration data is missing, malformed, incompatible, or partially references deleted songs.

## Acceptance criteria

- Selecting an available song snapshots the current visible library order, makes the selected identity current, and does not let later sorting or filtering mutate that queue.
- A Queue action on the detailed player presents a separate bottom sheet containing the active traversal order, current and unavailable items, shuffle mode, and repeat mode; opening or dismissing it does not issue a transport command.
- The persistent current-song surface exposes Previous and Next alongside its primary transport control; those actions follow the same queue policy as the detailed player and system surfaces.
- Once activated, Next and Previous actions follow the approved queue policy and keep UI state consistent with audible playback.
- Play, Pause, Toggle Play/Pause, Next, Previous, and Change Playback Position from supported Lock Screen, Control Center, and headphone surfaces control the same playback state as in-app controls; unsupported commands remain disabled.
- Now Playing metadata matches the audible song and clears or updates when playback state requires it.
- Playback resumes after an interruption only when it was previously playing and the system recommends resumption; external-route disconnection pauses without automatic resume.
- Unavailable or missing items are skipped in at most one complete traversal, and an all-invalid queue stops with an actionable error instead of retrying indefinitely.
- Removing the current item stops and clears it without advancing; removing another item preserves current playback; neither case leaves a live or restored reference to the removed identity.
- Natural end, Previous, shuffle, Repeat One, and Repeat All follow the approved queue semantics without duplicating or silently losing valid queue items.
- Relaunching restores the approved queue, position, mode, traversal, and history state without audible playback; a position restored at natural end restarts from the beginning on the next Play.
- The critical start, control, interruption, and restoration journeys have automated coverage where technically practical.

## Related documents

- [Product specifications](index.md)
- [Experience foundation](experience-foundation.md)
- [Basic playback](basic-playback.md)
- [Library foundation](library-foundation.md)
- [Music library](music-library.md)
- [Architecture](../../ARCHITECTURE.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
