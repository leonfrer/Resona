# Playback Integration

## Status

Proposed

## User outcome

Users can extend reliable basic playback with a queue, expected iOS system controls, background audio, interruption handling, and useful state restoration.

This specification is Proposed. Its requirements describe the problem boundary, but queue, interruption, route, restoration, and remote-command behavior is not approved for implementation until the open questions are resolved and the status becomes Active.

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
- Basic Playback owns minimum continuation of already-started single-song playback in the background. This stage owns the additional interruption, route-change, remote-command, queue, and restoration behavior around it.
- Queue, shuffle, repeat, and restoration semantics must be resolved before this specification becomes Active.
- Restoration must not automatically begin audible playback when platform expectations or user intent do not support it.
- Library removal and playback queues must use one resolved invalidation policy without leaving references to deleted songs. The exact queue behavior remains an open question in this Proposed specification.

## Failure cases

- Audio resource is missing, inaccessible, corrupted, or unsupported.
- Audio session activation fails.
- Playback is interrupted by another app or system event.
- The output route changes or disappears.
- A queued song is removed from the library.
- Restored queue data references unavailable library items.
- Remote commands arrive while no valid current item exists.

## Acceptance criteria

- Once activated, Next and Previous actions follow the approved queue policy and keep UI state consistent with audible playback.
- Supported Lock Screen, Control Center, and headphone commands control the same playback state as in-app controls.
- Now Playing metadata matches the audible song and clears or updates when playback state requires it.
- Playback responds correctly to interruptions and headphone disconnection according to the resolved policy.
- Bad, missing, or removed queue items follow the approved invalidation and unavailable-item policies without corrupting the queue or library.
- Natural end, Previous, shuffle, Repeat One, and Repeat All follow the approved queue semantics without duplicating or silently losing valid queue items.
- Relaunching restores the agreed queue and position state without unexpectedly starting audible playback.
- The critical start, control, interruption, and restoration journeys have automated coverage where technically practical.

## Open questions

- Which queue and playback-position state persists across relaunches?
- What interruption behavior is expected for calls, Siri, alarms, and other audio apps?
- What should happen after headphone or external-route disconnection?
- Should playback skip unavailable items automatically or stop with an error?
- Which system remote commands are supported in the first release?
- What queue is created when a user selects a song from a sorted or filtered library view?
- How do Repeat One, Repeat All, shuffle history, and Previous interact at boundaries?
- How are current and queued references invalidated when a library song is removed?

## Related documents

- [Product specifications](index.md)
- [Experience foundation](experience-foundation.md)
- [Basic playback](basic-playback.md)
- [Library foundation](library-foundation.md)
- [Music library](music-library.md)
- [Architecture](../../ARCHITECTURE.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
