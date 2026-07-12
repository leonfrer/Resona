# Playback Integration

## Status

Proposed

## User outcome

Users can extend reliable basic playback with a queue, expected iOS system controls, background audio, interruption handling, and useful state restoration.

## Depends on

- [Basic playback](basic-playback.md), which establishes the authoritative playback state and reliable foreground controls.
- [Library foundation](library-foundation.md), which provides stable song identities and managed audio-resource availability.
- [Experience foundation](experience-foundation.md), which defines system-consistent navigation, feedback, and motion behavior.

## In scope

- Extend playback with next and previous commands.
- Maintain and display a playback queue.
- Support shuffle and repeat behavior.
- Continue playback in the background.
- Integrate with the Lock Screen, Control Center, headphones, and remote commands.
- Respond predictably to audio-session interruptions and route changes.
- Restore the agreed previous queue and playback position without automatically starting audible playback.

## Out of scope

- Streaming playback
- AirPlay-specific browsing or queue management
- Cross-device handoff or synchronization
- Audio effects, equalizers, or playback-speed controls
- Gapless playback and crossfade unless separately specified

## User flows

### Start playback

1. The user selects an available song from the library.
2. Resona establishes an authoritative playback state and queue.
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

## Behavioral requirements

- Playback must have one authoritative state owner.
- App UI and system Now Playing information must reflect the same current item and playback state.
- Commands from different supported surfaces must produce consistent results.
- Playback errors must be reported without corrupting the queue or library.
- An unavailable queue item must not cause an endless retry or silent stall.
- Headphone disconnection and audio-session interruptions must follow documented platform-appropriate behavior.
- Background playback must not be claimed as implemented until the required capability and entitlement changes are explicitly approved and verified.
- Queue, shuffle, repeat, and restoration semantics must be resolved before this specification becomes Active.
- Restoration must not automatically begin audible playback when platform expectations or user intent do not support it.
- Selecting a song from the songs list creates a snapshot queue in the list's displayed order and makes the selected song current without discarding valid earlier entries from that snapshot.
- At the natural end of a song, playback advances to the next available queue item. If no next item exists and Repeat All is off, playback stops on the final song at its end position; the next Play restarts that song from the beginning.
- Repeat One restarts the current song at its natural end. Repeat All wraps from the final available queue item to the first.
- Enabling shuffle keeps the current song playing, randomizes upcoming items without duplication, and preserves already-played history for Previous navigation.
- Previous restarts the current song when elapsed playback is at least three seconds; before three seconds it moves through playback history to the previous available item.

## Failure cases

- Audio resource is missing, inaccessible, corrupted, or unsupported.
- Audio session activation fails.
- Playback is interrupted by another app or system event.
- The output route changes or disappears.
- A queued song is removed from the library.
- Restored queue data references unavailable library items.
- Remote commands arrive while no valid current item exists.

## Acceptance criteria

- Next and previous actions follow the resolved queue policy and keep UI state consistent with audible playback.
- Supported Lock Screen, Control Center, and headphone commands control the same playback state as in-app controls.
- Now Playing metadata matches the audible song and clears or updates when playback state requires it.
- Playback responds correctly to interruptions and headphone disconnection according to the resolved policy.
- A bad or missing queue item does not prevent later valid items from being handled according to queue policy.
- Removing a queued song removes all of its queue occurrences; removing the current song stops playback and clears the current item before its library resources are deleted.
- Natural end, Previous, shuffle, Repeat One, and Repeat All follow the resolved queue semantics without duplicating or silently losing valid queue items.
- Relaunching restores the agreed queue and position state without unexpectedly starting audible playback.
- The critical start, control, interruption, and restoration journeys have automated coverage where technically practical.

## Open questions

- Which queue and playback-position state persists across relaunches?
- What interruption behavior is expected for calls, Siri, alarms, and other audio apps?
- What should happen after headphone or external-route disconnection?
- Should playback skip unavailable items automatically or stop with an error?
- Which system remote commands are supported in the first release?
- What minimum background-playback behavior defines the first releasable version?

## Related documents

- [Product specifications](index.md)
- [Experience foundation](experience-foundation.md)
- [Basic playback](basic-playback.md)
- [Library foundation](library-foundation.md)
- [Music library](music-library.md)
- [Architecture](../../ARCHITECTURE.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
