# Music Library

## Status

Proposed

## User outcome

Users can browse the music they imported into Resona and reliably identify and open a song for playback.

## Depends on

- [Library foundation](library-foundation.md), which owns durable song identity, metadata, availability, and removal consistency.
- [Local audio import](local-audio-import.md), which provides the first user-facing source of library songs.
- [Experience foundation](experience-foundation.md), which defines the library's role in navigation, empty-state behavior, and feedback.

## In scope

- Display all successfully imported songs.
- Show available title, artist, album, duration, and artwork information.
- Provide fallbacks for missing metadata.
- Browse all songs in a deterministic, accessible list.
- Preserve the library across app launches.
- Remove an imported song from the Resona library with clear consequences.

## Delivery stages

### Songs list

- Display all successfully imported songs with metadata fallbacks.
- Sort songs deterministically.
- Expose stable song identity and resource availability when the user selects a song.
- Preserve the list across app launches.

### Library management

- Remove a song after its interaction with the current playback item and queue has a resolved policy.
- Keep persisted records and app-managed files consistent when removal succeeds or fails.

The songs list must be independently testable before library management is considered complete.

## Out of scope

- Streaming or cloud-based music libraries
- Social, recommendation, rating, or review features
- Editing embedded metadata in source files
- Playlists and smart playlists
- Cross-device synchronization
- Album and artist browsing in the first delivery slice
- Search in the first delivery slice

## User flows

### Browse songs

1. The user opens the library.
2. Resona shows imported songs in a deterministic order.
3. The user browses the songs list.
4. The user selects a song to begin or prepare playback.

### Empty library

1. A first-time user or a user who removed every song opens the library.
2. Resona explains that no music has been imported yet and that imported files are copied into Resona for offline playback.
3. A primary Choose Files action starts local audio import.
4. Canceling the picker returns to the unchanged empty state without showing an error.

### Remove a song

1. The user chooses to remove a song from Resona.
2. Resona communicates whether its managed audio copy will also be deleted.
3. The user confirms the destructive action.
4. The song disappears from the library and can no longer be selected for new playback.

## Behavioral requirements

- Only successfully imported songs may appear as playable library items.
- Library contents and normalized metadata must persist across app launches.
- Missing metadata must use consistent, localized display fallbacks.
- Songs with identical display metadata must remain distinguishable internally.
- The first delivery slice sorts songs by localized display title, with stable identity used as the deterministic tie-breaker.
- Library screens must support iPhone, iPad, Dark Mode, Dynamic Type, and VoiceOver.
- Removing a library item must not modify the user's original external file.
- Removal must clean up the app-managed audio copy and related app-owned data.
- If an audio resource becomes unavailable, the item must not silently behave as though playback succeeded.
- Removing the current song stops playback, clears the current item, removes all occurrences from the queue, and then removes the library song and its app-owned resources.
- Removing a queued but non-current song removes all of its queue occurrences before deleting its library data.
- The removal confirmation states when the action will stop current playback.

## Failure cases

- The persisted audio resource is missing or inaccessible.
- Metadata is incomplete, malformed, or changes after import.
- Artwork cannot be decoded.
- A persisted library record cannot be loaded or migrated.
- Removal succeeds only partially across the database and managed file storage.

## Acceptance criteria

### Songs list

- Imported songs remain visible after terminating and relaunching the app.
- An empty library provides a clear explanation and a primary Choose Files action.
- Every song has a usable display title, including songs with missing title metadata.
- Users can browse all imported songs using accessible controls.
- Selecting an available song hands the correct stable library identity to playback.
- An unavailable song remains visibly marked as unavailable, cannot start playback, and offers Remove and Re-import actions.
- The primary library journey is usable with VoiceOver and large Dynamic Type sizes.

### Library management

- Removing a song requires confirmation and leaves database and app-managed storage consistent.
- Removing a song never deletes or modifies the user's original external file.
- Removing the current song stops playback and leaves no current or queued reference to the removed identity.

## Open questions

- What terminology and fallback strings are used for unknown title, artist, and album?
- Is removal immediately destructive, or does Resona offer an undo period?
- When should album browsing, artist browsing, and search enter the delivery sequence?

## Related documents

- [Product specifications](index.md)
- [Experience foundation](experience-foundation.md)
- [Library foundation](library-foundation.md)
- [Local audio import](local-audio-import.md)
- [Basic playback](basic-playback.md)
- [Playback integration](playback.md)
- [Architecture](../../ARCHITECTURE.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
