# Local Audio Import

## Status

Active

## User outcome

Users can select supported audio files from the Files app and add them to a local Resona library that remains available offline.

## Depends on

- [Library foundation](library-foundation.md), which defines the stable song identity, normalized metadata, managed-resource ownership, and consistency rules that import must produce.
- [Experience foundation](experience-foundation.md), which defines shared import feedback and recovery behavior.

## In scope

- Select one or more audio files with the system file picker.
- Validate selected files before adding them to the library.
- Copy successfully imported audio into app-managed storage for durable offline access.
- Read available embedded metadata and artwork.
- Create library records for successful imports.
- Report failures without discarding unrelated successful imports.

## Out of scope

- Streaming services and remote catalogs
- Cloud synchronization
- DRM-protected media
- Editing metadata embedded in the original file
- Importing folders as a hierarchy

## User flow

1. The user starts an import from the library.
2. Resona presents the system file picker.
3. The user selects one or more files or cancels the picker.
4. Resona validates and imports each selected file.
5. Successfully imported songs appear in the library.
6. Resona reports files that could not be imported with an actionable explanation.

## Behavioral requirements

- Importing must not modify or delete the user's original file.
- Canceling the picker must leave the library unchanged and must not be presented as an error.
- Unsupported or unreadable files must not create valid library records.
- Failure to import one file must not roll back unrelated successful imports.
- A successful import must remain playable offline after the source file is no longer directly available to Resona.
- Import succeeds only after a complete app-managed audio copy and its valid library song are committed.
- Missing metadata must not prevent import when the audio itself is supported and readable.
- Resona must use the title, artist, album, and artwork fallbacks defined by Library Foundation.
- Interrupted imports must not leave incomplete library records or unmanaged partial files.
- Import compares each selected file's complete content with existing and same-operation imports. The comparison mechanism is an implementation decision.
- When an exact byte-identical song with an available managed resource already exists or succeeded earlier in the same operation, Resona skips the duplicate, keeps the existing song unchanged, and reports that the file was already imported.
- When exact byte-identical content matches an unavailable library song, re-import restores its managed audio resource and canonical metadata while preserving its stable identity.
- Matching filenames or display metadata alone do not make two files duplicates.
- Import validates audio and obtains the canonical title, artist, album, and duration before presenting a song as complete. Artwork processing must not invalidate otherwise supported audio; a placeholder may appear while artwork is unavailable.

## Progress and cancellation

- After the picker returns one or more files, Resona presents an import sheet for that operation.
- The sheet shows the number of files completed out of the total and identifies the file currently being handled when useful.
- The sheet remains presented while work is active and cannot be dismissed interactively as an alternative to cancellation.
- Cancel stops pending work and cooperatively cancels in-progress work at a safe cleanup boundary. Files already committed remain imported; canceled and partial files create no active song or unmanaged partial resource.
- If the app is suspended or terminated before an import finishes, completed files remain imported and launch reconciliation removes incomplete state. Resona does not report unfinished files as successful or resume access to external files without valid access.
- The result summary counts imported, restored, already imported, failed, and canceled files separately. Per-file details identify non-success outcomes by source filename when available.

## Failure feedback and recovery

| Outcome | Feedback | Primary next action |
| --- | --- | --- |
| Unsupported container, codec, protected media, or video-only file | The file is not supported and no song is created. | Choose Files |
| Corrupted or persistently unreadable audio | The file could not be read as valid audio and no song is created. | Choose Files |
| External access was lost or temporarily failed | The file could not be accessed and no song is created. | Try Again when access remains valid; otherwise Choose Files |
| Insufficient local storage | The file was not imported and the message tells the user to free device storage. | Try Again |
| Duplicate of an available song | The file is reported as Already Imported; this is informational, not a failure. | Done |
| Matching unavailable song restored | The existing song is reported as restored and keeps its identity. | Done |
| Metadata or artwork warning | The audio import succeeds; fallback presentation is used for unreadable optional values. | Done |
| User cancellation | Completed imports remain and unfinished selections are reported as canceled, not failed. | Choose Files |

Try Again retries only the affected file; it does not repeat unrelated successful imports.

## Failure cases

- Unsupported audio format
- Corrupted or unreadable file
- Insufficient local storage
- File access revoked or lost during import
- Audio metadata or artwork cannot be read; this is a non-fatal warning when the audio itself remains supported and readable.
- Duplicate content is selected
- Import is interrupted by cancellation, termination, or a background transition

## Acceptance criteria

- Selecting a supported audio file creates a library item that remains after relaunching the app.
- The imported item remains available offline without modifying the original file.
- Selecting multiple files can produce both successes and failures in the same operation.
- An unsupported file creates no valid library item and is reported as unsupported with an action to choose a different file.
- Files with missing optional metadata can still be imported and displayed with fallbacks.
- Canceling the picker produces no error and no library change.
- Canceling active import work preserves already committed songs and leaves no active song or partial managed resource for unfinished files.
- A failed or interrupted import leaves no incomplete record or orphaned managed file.
- Re-importing an exact byte-identical file whose existing song remains available creates no second song and reports that it was already imported.
- Re-importing content for a matching unavailable song restores that song without changing its stable identity.
- Different files with identical filenames or display metadata can be imported as distinct songs.
- Every failed file is identifiable in the result and offers the recovery action defined for its failure category.
- Import progress, result counts, cancellation, and per-file recovery follow the defined import-flow contract.

## Related documents

- [Product specifications](index.md)
- [Experience foundation](experience-foundation.md)
- [Library foundation](library-foundation.md)
- [Music library](music-library.md)
- [Architecture](../../ARCHITECTURE.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
