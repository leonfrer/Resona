# Basic Playback

## Status

Active

## User outcome

Users can start an available imported song, reliably control it in Resona, and continue already-started playback when the app moves to the background or the device locks.

## Depends on

- [Library foundation](library-foundation.md), which provides stable song identities and managed audio-resource availability.
- The songs-list stage of [Music library](music-library.md), which provides the first user-facing entry point for selecting a song.
- [Experience foundation](experience-foundation.md), which defines shared navigation and playback feedback behavior.

## In scope

- Start playback from an available library song.
- Play, pause, and seek within the current song.
- Display the current song, playback state, elapsed time, duration, and available artwork.
- Maintain one authoritative playback state.
- Report resource and playback failures without changing library data.
- Stop or replace the current song when the user selects another available song.
- Continue already-started playback when Resona moves to the background or the device locks.
- Stop cleanly when the current song reaches its natural end.

## Out of scope

- A multi-item playback queue
- Next, previous, shuffle, and repeat behavior
- Lock Screen, Control Center, headphones, and remote commands
- Audio-session interruption and route-change recovery beyond preventing false playback state
- Queue or playback-position restoration across relaunches
- Streaming playback

## User flow

1. The user selects an available song from the library.
2. Resona resolves its managed audio resource and establishes the authoritative playback state.
3. Playback begins, or an actionable error is shown without changing library data.
4. The user plays, pauses, or seeks within the current song.
5. The player UI reflects the state of audible playback.

The library's current-song affordance presents the detailed player in a sheet without issuing a playback command. Dismissing the sheet returns to the same library context without changing playback.

## Behavioral requirements

- Playback has one authoritative state owner.
- Selecting a song identifies it by stable library identity rather than by display metadata or filename.
- Visible playback state must not claim that audio is playing when startup or playback has failed.
- Selecting another available song replaces the current song and begins the newly selected song from its start.
- Play, pause, and seek commands are safe when no valid current song exists and must not create a false playing state.
- Playback failures must not modify or invalidate the library song.
- A missing, inaccessible, corrupted, or unsupported managed resource produces an actionable failure.
- A missing or inaccessible managed resource reports a localized equivalent of “Song Unavailable” and offers Re-import. It does not remove or otherwise modify the library song.
- A managed resource that can be opened but is corrupted, unsupported, or cannot be decoded reports a localized equivalent of “Song Can’t Be Played” and offers Re-import.
- A transient player or audio-session startup failure reports a localized equivalent of “Playback Couldn’t Start” and offers Try Again.
- If the current resource becomes unavailable or playback fails after starting, Resona stops playback, immediately stops claiming that audio is playing, retains the current song, and offers Re-import for a resource failure or Try Again for a transient playback failure.
- Relaunching the app does not automatically begin audible playback in this stage.
- Moving Resona to the background or locking the device does not pause valid ongoing playback.
- At the natural end of the current song, playback stops, the current song remains selected, and its position rests at the end. Pressing Play starts that song again from the beginning.
- Minimum background continuation must not be claimed as implemented until the required background-audio capability change is explicitly approved and verified.

## Seeking behavior

- Seeking is unavailable while playback is preparing or the playable duration is unknown. The player communicates the disabled state without presenting it as an error.
- Once a finite positive duration is known, the user can seek within the current song.
- A seek target is clamped to the inclusive range from zero through the known duration.
- Seeking to the natural end produces the same stopped-at-end state as natural completion; the next Play restarts the song from the beginning.
- A seek request that becomes stale because the current song was replaced is ignored and must not affect the replacement song.

## Failure cases

- The managed audio resource is missing or inaccessible.
- The audio resource cannot be opened or decoded.
- Playback startup fails.
- A seek target is outside the playable duration or duration is not yet available.
- The current audio resource becomes unavailable during playback.
- The app enters the background or the device locks while audio is playing.

## Acceptance criteria

- Selecting an available library song starts the correct audio or presents an actionable error.
- Selecting a different available song replaces the current song and starts it from the beginning.
- Play, pause, and seek keep visible state consistent with audible playback.
- A missing or unreadable managed resource does not change library data or leave playback claiming success.
- Missing, inaccessible, corrupted, and unsupported resource failures offer Re-import; transient startup and playback failures offer Try Again.
- Seeking is disabled while preparing or while duration is unknown, and an enabled seek is clamped to the known playable range.
- Repeated or temporarily invalid commands do not crash and leave the authoritative playback state consistent.
- Terminating and relaunching Resona does not unexpectedly start audible playback.
- Ongoing playback continues when the app enters the background or the device locks.
- Reaching the natural end stops playback, retains the current song at its end position, and makes the next Play restart from the beginning.
- Start, replacement, play, pause, seek, and failure behavior have deterministic automated coverage where technically practical.

## Resolved decisions

- Resource failures use Song Unavailable or Song Can’t Be Played feedback and offer Re-import; transient startup and playback failures offer Try Again.
- Seeking remains disabled while preparing or while duration is unknown, then clamps requests to the known playable range.
- Basic Playback owns minimum continuation of already-started single-song playback while the app is backgrounded or the device is locked. Queue behavior, system media controls, interruption and route-change recovery, and playback restoration remain owned by Playback Integration.

## Related documents

- [Product specifications](index.md)
- [Experience foundation](experience-foundation.md)
- [Library foundation](library-foundation.md)
- [Music library](music-library.md)
- [Playback integration](playback.md)
- [Architecture](../../ARCHITECTURE.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
