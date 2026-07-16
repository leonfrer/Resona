# Player Interface Refresh Execution Plan

## Status

Active. Implementation, manual acceptance, full automated verification, and
representative iPhone and iPad visual and accessibility inspection are complete
for the currently documented scope. Additional player-interface ideas remain to
be documented and delivered before this plan can close.

## Outcome

Refresh Resona's current-song bar and detailed player into a content-first iOS 26 media experience. The Library keeps a lightweight Liquid Glass current-song bar, the detailed player occupies the full app surface and dismisses downward, and Queue becomes a separate bottom sheet that owns shuffle and repeat controls.

This slice changes presentation and navigation plus the transient selection state needed to keep the persistent current-song surface stable while a replacement resolves. It preserves `PlaybackStore` as the sole transport and queue authority and does not change audible playback, queue traversal, restoration, system controls, persistence, capabilities, signing, or the deployment target.

## Source documents

- [Experience foundation](../product-specs/experience-foundation.md)
- [Basic playback](../product-specs/basic-playback.md)
- [Playback integration](../product-specs/playback.md)
- [Architecture](../../ARCHITECTURE.md)
- [Engineering guidelines](../engineering-guidelines.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
- [Apple: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Apple: GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [Apple: Modality](https://developer.apple.com/design/human-interface-guidelines/modality)

## Slice boundaries

### In scope

- Replace `CurrentSongBar`'s rectangular material strip with a native Liquid Glass floating surface over the Library.
- Reduce its artwork prominence and vertical footprint, use a fully rounded capsule, remove routine playback-status text, and place Previous, primary transport, and Next controls inside the same glass surface.
- Present the detailed player as a full-surface media destination instead of a task sheet.
- Remove the top-right Done action and support a downward interactive dismissal back to the unchanged Library context.
- Remove routine Playing and Paused text from the detailed player.
- Render Play, Pause, Restart, Previous, Next, and Queue as symbol-led controls with transparent backgrounds and stable accessible labels.
- Move Queue into a separate system sheet that rises from the bottom.
- Move shuffle and repeat controls from the detailed player into Queue.
- Replace the standard large-thumb `Slider` presentation with a thumb-free capsule media scrubber that expands during interaction and retains a comfortable interaction area and full accessibility behavior.
- Adjust only the transient selection and phase gating in `PlaybackStore` needed to keep the current-song surface stable and prevent transport commands during replacement.
- Adapt the refreshed surfaces to representative iPhone portrait and iPad portrait and landscape sizes, Light and Dark Mode, Increased Contrast, Reduce Transparency, Reduce Motion, VoiceOver, and accessibility Dynamic Type.
- Update previews and critical UI coverage for the new presentation hierarchy.

### Out of scope

- Playback, queue traversal, shuffle, repeat, interruption, route, restoration, or failure-policy changes
- Queue reordering, direct queue-item selection, or adding and removing individual queue entries
- New artwork processing, color extraction, gradients, custom shadows, or a broader visual design system
- Changes to playback ownership, queue or restoration policy, persistence payloads, SwiftData schemas, MediaPlayer adapters, audio capabilities, signing, bundle identifiers, or deployment targets
- Third-party UI or gesture dependencies

## Implementation decisions

### Current-song Liquid Glass surface

- Keep the bar in Library's bottom safe-area region, but inset it from screen edges so it reads as a floating control layer rather than a full-width content row.
- Use native iOS 26 Liquid Glass APIs instead of a custom blur. Apply the glass effect after layout and appearance modifiers and use one coherent container when separate glass shapes need to render together.
- Use one coherent glass shape around compact artwork, metadata, and the full transport cluster. Keep the metadata region, Previous, primary transport, and Next as separate accessible hit targets inside that surface.
- Omit routine Playing and Paused text from the bar. Its primary transport symbol communicates that state, while preparation and failure remain available through the detailed player.
- Remove the existing `.regularMaterial` background, divider, and gray bordered-button treatment. Artwork and metadata remain the content anchor; glass remains the functional layer.
- The project already targets iOS 26, so this slice does not add a lower-OS fallback and must not change the deployment target.

### Full-surface player and dismissal

- Keep `LibraryView` as the Library root and owner of the transient `PlayerDestination`.
- Replace the current item-driven task sheet with a full-screen presentation layer above Library. The player remains a presentation of shared `PlaybackStore` state and does not become another navigation or transport owner.
- Remove the navigation title bar and Done button. Provide a small, non-button drag affordance immediately below the top safe area without introducing gray chrome.
- Isolate transient drag state in the presentation wrapper rather than invalidating the full player tree. Lock the gesture axis once after the drag threshold; a committed downward distance or velocity dismisses, an incomplete gesture returns the player to rest, and upward or initially horizontal drags do not dismiss.
- Use the compact artwork inside the persistent current-song surface as one stable matched-transition source so presentation grows from that artwork and every dismissal contracts back into it. Keep the transition ID independent of the song identity so the reverse transition remains available after the song changes while the player is open.
- Filter dismissal to vertical intent so horizontal scrubber interaction is not stolen. Disable the player dismissal gesture while Queue is presented.
- Respect Reduce Motion by falling back from the matched zoom to the ordinary full-screen transition and avoiding decorative scale, blur, or spring effects while preserving direct dismissal. Add the accessibility escape action and restore focus to the current-song affordance after dismissal so VoiceOver users are not required to perform the visual drag gesture.
- Hide the underlying Library from hit testing and accessibility while the player is active. Dismissal never issues a playback command.

### Detailed-player composition and controls

- Preserve the content order of artwork, title and supporting metadata, progress, primary transport, secondary transport, failure recovery, and Queue entry, while adapting spacing and artwork size to the available viewport.
- Remove the routine status `Label` for `.playing` and `.paused`. Keep explicit preparation progress and actionable failure feedback; do not hide states that require explanation.
- Make the primary transport control icon-only in the visible layout. Its symbol switches between Pause, Play, and Restart as the authoritative phase changes, while its accessibility label continues to name the current action.
- Use transparent/plain visual styling for every button on the detailed player. Preserve at least a 44-point hit region, disabled-state communication, pressed feedback, stable identifiers, and semantic labels even when the visible glyph has no text.
- Remove shuffle, repeat, and the inline queue list from `PlayerView`. Add one transparent Queue action that presents the Queue sheet without changing playback.
- Extract focused subviews only where they own an independent presentation responsibility, such as the scrubber, transport cluster, and Queue surface. Do not introduce a presentation view model or duplicate transport state.

### Low-profile scrubber

- Add a focused `PlaybackScrubber` that reads authoritative position, duration, and seek availability and sends seek requests through the existing action.
- Draw a slim semantic track and progress fill with no thumb. Expand the capsule while interacting; an invisible expanded hit region keeps seeking comfortable.
- Hold the current position when the track is pressed, then apply horizontal movement relative to that held position instead of jumping to the touch location. Preview the dragged position in scrubber-local state and commit one engine seek when a drag ends; a tap or hold without a drag does not seek.
- Clamp drag and accessibility adjustments to the known finite duration. Preserve the existing disabled and preparing presentation when duration is unavailable.
- Expose the control as an adjustable accessibility element with an understandable label and elapsed-time value. Support VoiceOver increment and decrement without depending on the visual drag gesture.
- Keep elapsed and duration labels in monospaced digits and do not make the view a second clock or position owner.

### Queue sheet

- Add a local, item-driven Queue presentation from `PlayerView` using a system sheet that rises from the bottom and provides a visible drag affordance.
- Move the existing read-only traversal list, current and unavailable indicators, loading state, and reload recovery into `PlayerQueueView`.
- Move shuffle and repeat controls into the Queue header. Keep their text and symbol state available to VoiceOver and do not rely on tint alone; their visible button surfaces remain transparent.
- Preserve stable identifiers on Queue controls and rows without placing an identifier on an ancestor that would mask descendant identifiers.
- Queue dismissal is owned by the Queue surface, does not issue a transport command, and returns focus to the Queue action on the detailed player.

## Implementation sequence

### 1. Presentation shell and Liquid Glass bar

- Convert the current-song bar to the native Liquid Glass floating treatment.
- Reduce bar artwork and add Previous and Next around the existing primary transport action without duplicating queue state.
- Replace the task-sheet player entry with the full-surface presentation and downward dismissal behavior.
- Preserve selection, player opening, dismissal, Play/Pause, and restoration behavior in focused UI coverage.
- Exit criterion: the player fills the app surface, has no Done button, dismisses downward without changing playback, and the compact Library bar uses one native Liquid Glass surface with separate Previous, primary transport, Next, and open-player actions.

### 2. Player control hierarchy and scrubber

- Remove routine phase text and visible Play/Pause labels.
- Apply transparent symbol-led styling to all detailed-player buttons.
- Add the low-profile scrubber and its drag, disabled, and accessibility-adjustment behavior.
- Add representative populated, preparing, stopped-at-end, failure, Dark Mode, and accessibility-text previews.
- Exit criterion: primary state is legible from the transport symbol, every icon-only control remains discoverable, and seeking is precise without a visually dominant thumb.

### 3. Queue extraction

- Add the Queue action and bottom sheet.
- Move queue modes, list states, and reload recovery out of the detailed player.
- Update UI tests to open Queue before asserting shuffle, repeat, current item, or unavailable item state.
- Exit criterion: Queue is independently presentable and dismissible, owns shuffle and repeat, and never changes transport merely by opening or closing.

### 4. Adaptive and delivery verification

- Run the targeted playback UI scenarios while iterating, then run the complete required suite.
- Inspect the player and Queue in representative iPhone portrait and iPad portrait and landscape layouts, including accessibility text sizes.
- Inspect Light and Dark Mode, Increased Contrast, Reduce Transparency, Reduce Motion, VoiceOver order and escape behavior, and Liquid Glass legibility over representative artwork and Library content.
- Record exact commands, destinations, screenshots where useful, warnings, and any unverified evidence in this plan.
- Exit criterion: automated checks pass, interactive visual and accessibility checks are recorded, and product-spec lifecycle status reflects only verified behavior.

## Test design

### UI automation

- Opening the current-song affordance reveals the full-surface player without changing playback and without exposing `player.done`.
- The current-song affordance omits routine status text; its Previous and Next availability matches queue boundaries, and every transport action remains independently accessible.
- A downward dismissal returns to the same Library context while playback state remains unchanged.
- The primary transport exposes Pause while playing and Play while paused through its accessibility label even though visible Play/Pause text is absent.
- Play and Pause symbols transition in place, with the animation disabled when Reduce Motion is enabled.
- A replacement selection keeps the existing current-song surface visible until resolution completes, avoiding removal-and-insertion flicker.
- Queue opens from its dedicated action; shuffle, repeat, current item, unavailable item, loading, and reload states exist only on the Queue surface.
- Opening and dismissing Queue leaves current item, position, and transport state unchanged.
- Pressing the scrubber track holds its current position regardless of touch location; horizontal dragging starts from that held position and commits one seek when the drag ends, while a tap or hold without a drag does not seek.
- Accessibility Dynamic Type keeps primary transport, Queue, dismissal affordance, and failure recovery usable.

### Focused lower-layer coverage

- Add unit coverage only for new pure scrubber mapping or gesture-threshold helpers if those are extracted. Do not duplicate existing `PlaybackStore` and queue-domain tests for a presentation-only change.
- Keep seek clamping authoritative at the existing Playback boundary; presentation tests cover value-to-geometry mapping and accessibility increments when implemented as pure helpers.

### Interactive visual and accessibility inspection

- Verify Liquid Glass shape, legibility, interaction response, Reduce Transparency, and Increased Contrast on a current iOS 26 device or Simulator.
- Verify the player fills the viewport, follows the downward drag, cancels cleanly below threshold, and dismisses above threshold without fighting horizontal scrubbing.
- Verify the Queue sheet rises from the bottom, scrolls long queues, and returns focus correctly.
- Verify VoiceOver order, icon-only action names, adjustable scrubber behavior, accessibility escape dismissal, and focus restoration.
- Verify representative iPhone portrait and iPad portrait and landscape sizes, plus Light Mode, Dark Mode, and Reduce Motion.

## Required verification

During implementation:

- Run the focused playback UI tests after each presentation milestone.
- Run `./scripts/check.sh` after adding any pure gesture or scrubber logic.
- Run `./scripts/check-all.sh` before completion because the change affects a critical user-facing playback journey.
- Prefer an eligible physical iPhone or iPad when it supports the required signing, isolation, and inspection. Use Simulator for deterministic launch scenarios and the layout matrix, recording why each destination was selected.
- Run `git diff --check` and verify all changed documentation links.

Documentation-only creation of this plan requires only document review, internal-link validation, authoritative-ownership review, and `git diff --check`; it does not require an app build or test run.

## Delivery record

### 2026-07-15 — Implementation and manual acceptance

- Implemented the full-screen player, downward dismissal, shared artwork transition, Liquid Glass current-song surface, Queue sheet, symbol-led controls, and relative-drag scrubber.
- Kept `PlaybackStore` as the sole transport authority while retaining the current item during replacement preparation and rejecting overlapping navigation commands.
- `./scripts/build.sh` completed successfully for a generic iOS Simulator destination.
- The targeted scrubber UI regression passed on an iPhone 17 Pro Simulator running iOS 26.5.
- `./scripts/test-ui.sh` passed 21 tests with no failures on the same Simulator after stabilizing Queue sheet dismissal and restoring deterministic queue mode before navigation assertions.
- The user completed manual playback-page acceptance, including the revised scrubber interaction.
- Physical-device checks, the representative layout matrix, and complete VoiceOver, Increased Contrast, Reduce Transparency, and Reduce Motion inspection remain required before this plan can close.

### 2026-07-15 — Full automated verification

- `./scripts/check-all.sh` passed on an iPhone 17 Pro Simulator running iOS 26.5.
- The complete `ResonaTests` unit and integration target passed with 116 tests and no failures. Parameterized cases produced 123 device/configuration executions in the result bundle.
- The serial `ResonaUITests` run passed 21 executions with no failures: 17 app scenarios and 4 Light/Dark portrait/landscape launch configurations.
- Xcode emitted the existing skipped-AppIntents-metadata, Simulator debugger-version, and duplicate Web accessibility bundle diagnostics. No new application source warning was introduced.
- Automated verification completed before the physical-device, representative-layout, and interactive accessibility and visual evidence recorded below.

### 2026-07-15 — iPhone visual and accessibility acceptance

- Verified on an iPhone 17 Pro Max running iOS 26.5.2.
- VoiceOver order and actions, accessibility Dynamic Type, and Light and Dark Mode passed for the current-song surface, full-screen player, scrubber, and Queue.
- Reduce Motion removed the matched zoom and decorative control, artwork, scrubber, and dismissal-reset animations without preventing transport, seeking, Queue presentation, or downward dismissal.
- Reduce Transparency and Increased Contrast preserved legible metadata, symbols, disabled states, scrubber progress, Liquid Glass treatment, and Queue state, both independently and together.

### 2026-07-15 — iPad visual and accessibility acceptance

- Verified on an iPad Pro 11-inch (2nd generation) running iPadOS 27.0 Beta.
- Representative current-song, full-screen player, scrubber, and Queue layouts passed on iPad.
- VoiceOver, Dynamic Type, Light and Dark Mode, Reduce Motion, Reduce Transparency, and Increased Contrast passed on iPad.
- All automated, manual, device, visual, and accessibility evidence required by the currently documented scope is recorded. Additional player-interface work remains to be defined, so this plan remains Active.

## Risks and controls

- **Dismissal and scrubber gesture conflict:** require vertical intent for dismissal, keep scrubbing horizontal, test diagonal starts and cancellation, and disable player dismissal while Queue is active.
- **VoiceOver dependence on a visual gesture:** add accessibility escape dismissal, stable labels, focus restoration, and an interactive VoiceOver pass.
- **Icon-only ambiguity:** keep familiar system symbols, current-action labels, disabled semantics, and non-color mode labels.
- **Liquid Glass overuse or poor contrast:** limit glass to the floating current-song functional layer, use native APIs, and verify Reduce Transparency and Increased Contrast.
- **Custom scrubber accuracy:** keep an expanded invisible hit region, clamp values, expose adjustable semantics, and test zero, midpoint, end, unavailable-duration, and stopped-at-end cases.
- **Large queue performance:** retain stable identities and lazy row construction; do not add artwork decoding or duplicated queue state to presentation.
- **iPad presentation drift:** verify the full-surface player and bottom Queue sheet explicitly on iPad instead of accepting phone behavior stretched to a wider canvas.

## Implemented source map

The implemented presentation remains grouped in the existing source boundary:

```text
Resona/Library/Presentation/
├── LibraryView.swift                 full-surface player presentation owner
└── CurrentSongBar.swift              Liquid Glass floating current-song surface

Resona/Playback/Presentation/
└── PlayerView.swift                  player composition, dismissal, controls,
                                      scrubber, and Queue sheet

ResonaUITests/ResonaUITests.swift      refreshed player and Queue journeys
```

No new architectural boundary is expected. Update `ARCHITECTURE.md` only if implementation changes presentation ownership or dependency direction beyond this plan.
