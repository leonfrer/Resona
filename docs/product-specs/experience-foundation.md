# Experience Foundation

## Status

Active

## Purpose

Define the cross-feature product experience that import, library, and playback must share without prescribing a pixel-perfect visual design.

## Information architecture

- The library is the primary app destination and the entry point for import and song selection.
- The library remains the root destination. Import and player presentation do not replace it with another root destination.
- The empty library presents import as its primary action and briefly explains that imported audio is copied into Resona for offline playback.
- When a current song exists, the library presents a persistent Liquid Glass current-song affordance. It shows compact artwork and metadata plus Previous, Play/Pause or Restart, and Next controls inside one glass surface. It omits routine playback-status text, and activating its metadata region presents the detailed player without starting or restarting playback.
- The detailed player occupies the full app surface as an immersive media view rather than appearing as a task sheet. Pulling it downward dismisses it and returns to the same library context without changing playback; it does not show a Done button.
- The playback queue is a separate system sheet that rises from the bottom of the detailed player. Shuffle and repeat controls belong to this queue surface, and opening or dismissing it does not change transport state.
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
- The detailed player expands from the compact artwork inside the persistent current-song surface and contracts back into that artwork on dismissal. The artwork's position, size, and corner shape remain visually continuous while the rest of the detailed player appears or disappears around it, including when the current song changes while the player is open. Reduce Motion replaces this zoom with the ordinary full-screen presentation transition.
- Starting playback from the detailed player enlarges the artwork slightly with a brief spring response; pausing returns it to its resting size. Reduce Motion preserves the size change without the spring animation.
- Interfaces respect Reduce Motion and do not rely on animation alone to communicate state.
- Import progress remains attached to the import flow; playback progress remains attached to the current player.

## Visual direction

Resona uses a content-first, recognizably native Apple-platform aesthetic. Artwork and song information provide the visual character; controls remain calm, legible, and subordinate to listening.

- Use system typography, semantic colors, standard control shapes, and platform materials as the baseline. Custom chrome requires a documented usability or identity need.
- Prefer clear hierarchy and generous spacing over dense decoration. A screen should have one visually dominant task or content region.
- Artwork is the primary visual anchor for a song. Missing artwork uses one consistent neutral placeholder that remains recognizable in Light Mode, Dark Mode, Increased Contrast, and grayscale.
- Accent color identifies actionable and selected states but never becomes the only state indicator. Destructive, warning, unavailable, and playback states retain semantic labels or symbols.
- The Songs List prioritizes title, then artist, then supporting duration or availability. Secondary metadata must not compete with the primary title.
- The current-song surface feels persistent but lightweight; the detailed player may give artwork more prominence without obscuring transport controls or progress.
- The current-song surface uses native Liquid Glass as a floating functional layer over Library content. Glass is not used as decoration throughout the player content layer.
- The current-song surface uses a compact, fully rounded capsule with small inset rounded-square artwork and places Previous, primary transport, and Next controls inside the same glass shape. The primary transport symbol communicates routine playing or paused state without a separate status label.
- Detailed-player transport and Queue actions use transparent, symbol-led controls without persistent gray button backgrounds. Play and Pause remain distinguishable by symbol and accessible action label rather than visible button text.
- Routine Playing and Paused labels are omitted from the detailed player because the primary transport symbol communicates that state. Preparing, unavailable, failed, and other states that require explanation retain explicit feedback.
- Playback progress uses a thumb-free capsule scrubber that expands while interacting, preserves a comfortable touch target, and provides complete accessibility adjustment behavior.
- iPhone favors a focused single-column hierarchy. iPad uses available space for comfortable width and spacing rather than merely stretching phone rows; feature availability remains equivalent.
- Standard sheets, alerts, menus, and transitions establish visual consistency. Avoid ornamental animation, gradients, shadows, or custom materials unless a future visual-system decision defines them.

Every new major screen or reusable component must provide representative previews for empty, populated, loading, failure, Dark Mode, and accessibility text-size states when those states apply. A visual design system or custom brand language can supersede these defaults only through an updated Experience Foundation decision.

## Accessibility and adaptation

- Primary actions and failure recovery remain usable with VoiceOver and large Dynamic Type sizes.
- Color, artwork, and motion are not the sole indicators of availability or playback state.
- The same information architecture adapts to iPhone and iPad without making one device class a reduced-function version.
- On iPhone, Resona supports the upright portrait orientation only. Rotating the device to either landscape orientation does not rotate the app interface.
- On iPad, Resona supports upright portrait, upside-down portrait, and both landscape orientations so the interface continues to adapt across the full existing iPad orientation range.

## Acceptance criteria

- A first-time user with an empty library can identify how to import music without opening another destination.
- A user can move from library to current player and back without losing playback state.
- Opening the detailed player from the current-song affordance does not issue a playback command.
- The detailed player fills the app surface, has no Done button, and returns to the unchanged Library context through a downward dismissal gesture.
- Opening and dismissing the detailed player uses the compact current-song artwork as a stable shared transition source; changing songs inside the player does not break the return animation to the current artwork.
- The queue rises from the bottom as a separate surface and owns shuffle and repeat controls without issuing a transport command when it opens or closes.
- The current-song affordance uses native Liquid Glass, while detailed-player buttons remain visually transparent and expose unambiguous VoiceOver labels.
- The current-song affordance keeps compact artwork and independently accessible Previous, primary transport, and Next actions inside one glass surface without routine Playing or Paused text.
- Replacing the selected song does not make the persistent current-song affordance disappear and reappear while the replacement is being prepared.
- The detailed player communicates routine Play and Pause state through the primary transport symbol without a redundant status label or visible Play/Pause text.
- The Play and Pause symbols transition in place, respecting Reduce Motion, rather than abruptly replacing the entire control.
- The detailed-player artwork becomes slightly larger while playback is active, responds with a brief spring when Play is selected, and changes size without spring motion when Reduce Motion is enabled.
- The scrubber remains precise, seekable, and accessible without a visible thumb; pressing the track holds the current position regardless of touch location, while horizontal dragging adjusts from that held position, previews progress locally, and commits the seek when interaction ends. A tap or hold without a drag does not seek.
- Fatal failures, non-fatal warnings, cancellation, and destructive actions have visibly distinct feedback behavior.
- All recoverable errors in the core import-to-playback journey offer a relevant next action.
- Core navigation and state changes remain understandable with Reduce Motion, VoiceOver, and large Dynamic Type enabled.
- Major screens follow the native, content-first hierarchy in Light Mode and Dark Mode without clipped primary actions or color-only state communication.
- On iPhone, the app launches and remains in upright portrait when the device is turned to either landscape orientation.
- On iPad, the app continues to launch and rotate correctly in upright portrait, upside-down portrait, landscape left, and landscape right.

## Related documents

- [Product specifications](index.md)
- [Library foundation](library-foundation.md)
- [Local audio import](local-audio-import.md)
- [Music library](music-library.md)
- [Basic playback](basic-playback.md)
- [Playback integration](playback.md)
