# Library Foundation

## Status

Active

## Purpose

Define the minimum durable meaning of an imported song so import, library presentation, and playback share one stable product model without coupling to each other's implementation details.

This specification describes product-level ownership and consistency rules. It does not prescribe SwiftData schemas, service types, folder layouts, or other implementation structure.

## In scope

- Assign a stable internal identity to every successfully imported song.
- Persist normalized display metadata and the location of an app-managed audio resource.
- Distinguish song identity from title, artist, album, filename, or file location.
- Report whether the managed audio resource is available.
- Provide consistent creation and removal semantics for library songs and app-owned resources.
- Preserve valid library songs across app launches.
- Define the normalized metadata contract shared by import, library presentation, and playback.
- Define the first-release supported audio-format policy.

## Out of scope

- File-picker interaction and import progress
- Songs, albums, or artists user interfaces
- Playback state and queue behavior
- Playlists, ratings, and user-edited metadata
- Cross-device synchronization
- A specific persistence schema or migration implementation

## Behavioral requirements

- A library song exists only after its required persisted data and complete managed audio file are available.
- Every library song has a stable identity that does not change when display metadata changes.
- Songs with identical metadata or filenames remain independently identifiable.
- Resona owns an app-managed audio copy for every successfully imported song.
- The managed copy remains independent of the original external file after import succeeds.
- Normalized metadata and the relationship to the managed audio resource persist across app launches.
- Missing optional metadata does not make an otherwise valid song invalid.
- Resource availability is determined from the managed resource and must not be inferred from the presence of a database record alone.
- A song whose managed resource is missing remains identifiable in the library as unavailable, cannot be selected for playback, and offers Remove and Re-import recovery actions.
- Successfully re-importing the same content for an unavailable song restores its managed resource under the existing stable song identity rather than creating a second song.
- Creation and removal must recover to a consistent state after failure or interruption, without presenting partial records as playable songs or leaving unmanaged partial files.
- Removing a library song never modifies or deletes the original external file.

## Stable identity

- A new song receives an opaque, app-assigned identity during creation.
- The identity persists and never changes during metadata updates, resource recovery, or app relaunches.
- The identity is not derived from filename, metadata, file location, or audio content and is not presented as user-facing metadata.
- Duplicate-detection evidence is separate from song identity. It must distinguish different file contents reliably enough that Resona never suppresses a distinct song merely because names or metadata match.
- The algorithm and persisted representation used for identity and duplicate evidence are implementation decisions recorded in the active execution plan and current architecture.
- Re-importing a song that the user previously removed is a new import with a new identity. Identity preservation applies only while the unavailable song still belongs to the library.

## Minimum song information

The product model must be able to represent:

- Stable song identity
- Managed audio-resource identity or location
- Display title
- Optional artist and album metadata
- Duration when it can be determined
- Optional artwork or a reference to managed artwork
- Resource availability

The exact persisted fields and representation remain architecture and implementation decisions.

## Metadata responsibility

- Library Foundation owns the canonical metadata meanings, optionality, and display fallbacks.
- Import owns reading untrusted embedded metadata and mapping it into the canonical contract.
- Playback and presentation consume canonical library metadata and must not independently reinterpret the source file as a second metadata authority.
- Title is required for display. Import uses a non-empty embedded title when available, otherwise the source filename without its extension, otherwise the localized fallback “Unknown Title.”
- Missing artist and album values use localized “Unknown Artist” and “Unknown Album” display fallbacks without persisting those fallback strings as source metadata.
- Missing or unreadable artwork uses a standard artwork placeholder and does not invalidate a song.
- Duration is derived from the validated managed audio resource and is not accepted from untrusted text metadata.

## Artwork ownership

- Successfully extracted artwork is retained as optional app-managed data associated with the stable song identity.
- Artwork can be replaced or re-derived without changing song identity or audio-resource availability.
- Missing, unreadable, or lost managed artwork falls back to the standard placeholder and does not make the song unavailable.
- Removing a song also removes its app-managed artwork. Failure to clean up artwork follows the same retry rules as other app-owned resources.

## Consistency and recovery

- Creation is not exposed as a playable song until its required durable data and complete managed audio are available.
- Failed, canceled, or interrupted creation leaves no playable partial song or abandoned app-owned partial data after recovery.
- Recovery runs when the library opens and before another library mutation when needed.
- A removal accepted under the [Music Library removal policy](music-library.md#removal-policy) has no Undo and never reappears as a playable or duplicate-matching song while cleanup is pending.
- Incomplete cleanup is retried automatically and exposes the affected song and a Try Again action when user intervention remains useful.
- Recovery converges without claiming that a missing resource is playable and without treating cleanup bookkeeping as an active song.

## Supported audio policy

The first release accepts unprotected, locally readable audio in these container and codec families:

- MP3 audio
- M4A or MP4 audio containing AAC or Apple Lossless audio
- WAV audio containing supported PCM audio
- AIFF audio containing supported PCM audio

File extensions and picker content types are initial filters, not proof of validity. Import must validate that the actual media can be opened and that it contains a supported audio track. DRM-protected, unsupported-codec, corrupted, and video-only resources are not valid library songs.

## Acceptance criteria

- A successfully created song retains the same stable identity after terminating and relaunching the app.
- Two files with different byte content remain separate library songs even when their display metadata is identical.
- A song with missing optional metadata remains valid and can use product-defined display fallbacks.
- Every valid song conforms to the supported audio policy and canonical metadata contract.
- No library song is exposed as playable before its complete managed audio resource is available.
- A missing managed audio resource is reported as unavailable rather than as successful playback.
- Re-importing content that satisfies the Local Audio Import duplicate policy restores an unavailable song without changing its stable identity.
- Failed or interrupted creation and removal recover without a playable partial record or an unmanaged partial audio file.
- Relaunch reconciliation removes abandoned creation state and resumes accepted removal cleanup without restoring a playable deleted song.
- Removing a song removes its app-owned data according to the resolved removal policy and never changes the original external file.

## Related documents

- [Product specifications](index.md)
- [Experience foundation](experience-foundation.md)
- [Local audio import](local-audio-import.md)
- [Music library](music-library.md)
- [Basic playback](basic-playback.md)
- [Playback integration](playback.md)
- [Architecture](../../ARCHITECTURE.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
