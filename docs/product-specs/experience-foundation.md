# Experience Foundation

## Status

Active

## Purpose

Define the cross-feature product experience that import, library, and playback must share without prescribing a pixel-perfect visual design.

## Information architecture

- The library is the primary app destination and the entry point for import and song selection.
- The library remains the root destination. Import and player presentation do not replace it with another root destination.
- The empty library presents import as its primary action and briefly explains that imported audio is copied into Resona for offline playback.
- When a current song exists, the library presents a persistent current-song affordance. Activating it presents the detailed player without starting or restarting playback.
- The detailed player uses a platform-standard sheet. Dismissing it returns to the same library context without changing playback.
- Import begins with the system file picker. After files are selected, progress and results remain in an import sheet over the library.
- Queue, album, and artist destinations are introduced only when their corresponding product stages are implemented; placeholder destinations are not shown.

## Feedback and errors

- User-facing messages use concise, non-technical language and identify the affected file or song when useful.
- Recoverable failures provide a relevant next action such as Try Again, Remove, or Choose Files.
- Cancellation is not presented as failure.
- A multi-file import reports the overall outcome and lets users identify individual failures without interrupting unrelated successes.
- Non-fatal metadata or artwork warnings do not compete visually with fatal audio-import failures.
- Destructive confirmation states both what Resona will remove and whether current playback will stop.
- Persistent unavailable-resource state is shown on the affected library item; transient playback failures do not silently mutate library state.

### Feedback contract

- Picker cancellation dismisses the picker and returns to the unchanged library without a message.
- User-requested cancellation during import is identified as cancellation in the import result; completed imports remain successful and canceled work is not labeled failed.
- A non-fatal metadata or artwork warning appears as secondary detail for the successfully imported file and does not block completion.
- A recoverable file-level failure identifies the file, explains the user-relevant cause, and presents the recovery action defined by Local Audio Import.
- An unavailable managed resource is represented persistently on its song row with Re-import and Remove actions.
- Destructive removal uses a confirmation alert. A failure to finish removal identifies the song and offers Try Again.
- Import feedback uses an overall summary plus per-file details when an operation has warnings, duplicates, failures, or cancellation. A fully successful single-file import may finish without a separate result summary.

## Navigation and motion

- Use platform-standard navigation, sheets, menus, alerts, and transitions unless a documented product need requires custom behavior.
- Motion communicates navigation or state change and must not delay direct playback controls.
- Interfaces respect Reduce Motion and do not rely on animation alone to communicate state.
- Import progress remains attached to the import flow; playback progress remains attached to the current player.

## Accessibility and adaptation

- Primary actions and failure recovery remain usable with VoiceOver and large Dynamic Type sizes.
- Color, artwork, and motion are not the sole indicators of availability or playback state.
- The same information architecture adapts to iPhone and iPad without making one device class a reduced-function version.

## Acceptance criteria

- A first-time user with an empty library can identify how to import music without opening another destination.
- A user can move from library to current player and back without losing playback state.
- Opening the detailed player from the current-song affordance does not issue a playback command.
- Fatal failures, non-fatal warnings, cancellation, and destructive actions have visibly distinct feedback behavior.
- All recoverable errors in the core import-to-playback journey offer a relevant next action.
- Core navigation and state changes remain understandable with Reduce Motion, VoiceOver, and large Dynamic Type enabled.

## Related documents

- [Product specifications](index.md)
- [Library foundation](library-foundation.md)
- [Local audio import](local-audio-import.md)
- [Music library](music-library.md)
- [Basic playback](basic-playback.md)
- [Playback integration](playback.md)
