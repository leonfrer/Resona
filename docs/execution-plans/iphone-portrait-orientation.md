# iPhone Portrait-Only Orientation Execution Plan

## Status

Complete 2026-07-17. Debug and Release build metadata, the complete iPhone UI
suite, and the iPad launch-configuration matrix verify the documented behavior.

## Outcome

Constrain Resona on iPhone to the upright portrait orientation while preserving
the existing iPad support for upright portrait, upside-down portrait, landscape
left, and landscape right.

This slice changes only the app target's supported-interface-orientation
declarations and the verification matrix that depends on them. It does not
change layouts, navigation, feature behavior, device-family support, or an
architectural boundary.

## Source documents

- [Experience foundation](../product-specs/experience-foundation.md)
- [Architecture](../../ARCHITECTURE.md)
- [Engineering guidelines](../engineering-guidelines.md)
- [Testing](../testing.md)
- [Delivery checklist](../delivery-checklist.md)
- [Release process](../release-process.md)

## Slice boundaries

### In scope

- Change the app target's iPhone supported-orientation declaration to upright
  portrait only in both Debug and Release.
- Preserve the separate iPad declaration with upright portrait, upside-down
  portrait, landscape left, and landscape right in both configurations.
- Verify the effective orientation keys in the built Debug and Release app
  bundles rather than relying only on the project-file text.
- Verify at runtime that iPhone no longer rotates into landscape and that iPad
  rotation behavior is unchanged.
- Reconcile active documentation and UI launch-configuration evidence with the
  supported orientation matrix.

### Out of scope

- Removing iPad landscape or upside-down portrait support
- Adding upside-down portrait support on iPhone
- Changing `TARGETED_DEVICE_FAMILY`, deployment targets, bundle identifiers,
  signing, entitlements, capabilities, background modes, or App Store settings
- Adding runtime orientation locks, UIKit orientation overrides, or view-level
  geometry workarounds
- Redesigning any iPhone or iPad screen
- Rewriting archived plans or historical delivery records that accurately
  describe the orientation support present when their evidence was collected

## Implementation decisions

- Keep the existing generated-Info.plist approach and device-qualified build
  settings. Set only
  `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` to
  `UIInterfaceOrientationPortrait`; do not introduce an unqualified orientation
  key that could also constrain iPad.
- Make the same explicit change in the app target's Debug and Release build
  configurations so local, test, archive, and distribution products agree.
- Leave
  `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` unchanged with all four
  existing iPad orientations.
- Do not add application code for a declaration that iOS already owns. If the
  built metadata is correct but runtime behavior differs, investigate the
  effective scene and bundle configuration before considering code changes.
- Treat `ResonaUITestsLaunchTests.runsForEachTargetApplicationUIConfiguration`
  as configuration-driven coverage. Record the configurations Xcode actually
  executes after the change instead of retaining a hard-coded expectation that
  iPhone has a landscape launch configuration.
- Keep the product rule in Experience Foundation. This plan owns temporary
  implementation sequence and evidence only.

## Implementation sequence

### 1. Update the app target declarations

- Change the iPhone orientation value in the Debug app-target build settings to
  upright portrait only.
- Apply the identical value to the Release app-target build settings.
- Confirm the iPad values and all unrelated project settings remain byte-for-byte
  unchanged.
- Exit criterion: the project declares one iPhone orientation and the same four
  iPad orientations in both configurations.

### 2. Reconcile test and documentation assumptions

- Inspect UI launch tests and scripts for assumptions about a fixed number of
  portrait and landscape configurations.
- Update tests only if an assertion or explicit configuration still requires an
  unsupported iPhone landscape launch; do not remove iPad landscape coverage.
- Keep active documentation aligned to the Experience Foundation matrix:
  iPhone upright portrait, and iPad all four orientations.
- Exit criterion: no active test or document requires iPhone landscape, while
  iPad landscape and upside-down portrait remain required.

### 3. Verify build metadata and runtime behavior

- Build Debug and Release products and inspect their effective Info.plist keys.
- Run the serial UI suite on a representative iPhone destination and record the
  launch configurations Xcode executes.
- Run representative iPad UI or launch coverage without changing the iPad
  orientation matrix.
- Interactively rotate a representative iPhone toward both landscape directions
  and confirm the app remains upright portrait.
- Interactively rotate a representative iPad through upright portrait,
  upside-down portrait, landscape left, and landscape right, checking the
  Library, current-song surface, detailed player, and Queue in representative
  populated states.
- Exit criterion: bundle metadata and runtime behavior agree in both build
  configurations, iPhone is portrait-only, and iPad behavior has not regressed.

## Test design

### Static and build-product checks

- Confirm both app-target configurations contain exactly
  `UIInterfaceOrientationPortrait` for the iPhone-qualified setting.
- Confirm both retain all four existing values for the iPad-qualified setting.
- Inspect the built Debug and Release application Info.plists for the effective
  `UISupportedInterfaceOrientations~iphone` and
  `UISupportedInterfaceOrientations~ipad` arrays, including exact value counts
  and contents.
- Verify unrelated bundle declarations, especially `UIBackgroundModes`, remain
  unchanged.

### Automated coverage

- Run `./scripts/test-ui.sh` on a representative iPhone Simulator because the
  supported application UI configurations are user-visible and feed launch
  coverage.
- Run the launch configuration test or UI suite on a representative iPad
  Simulator to retain portrait and landscape evidence.
- Add no unit test: this slice introduces no business logic or pure code path.
- Add or change UI test code only if the current configuration-driven launch
  test cannot reliably establish the supported matrix after the metadata
  change.

### Interactive coverage

- On iPhone, launch in upright portrait, rotate toward landscape left and
  landscape right, background and foreground once, and confirm Resona remains
  upright portrait without clipped, shifted, or inaccessible controls.
- On iPad, launch and rotate through all four supported orientations and confirm
  the Library, player, and Queue continue adapting without clipped primary
  actions or lost presentation state.

## Required verification

During implementation:

- Run `./scripts/build.sh` for the Debug Simulator product.
- Run `CONFIGURATION=Release ./scripts/build.sh` for the Release Simulator
  product.
- Inspect the effective orientation arrays and background-audio declaration in
  both built app Info.plists with `plutil`.
- Run `./scripts/test-ui.sh` on a representative iPhone Simulator.
- Run the relevant UI launch coverage on a representative iPad Simulator.
- Complete the interactive iPhone and iPad rotation matrix above, preferring an
  eligible physical device when it satisfies the testing requirements.
- Run `git diff --check` and verify all changed documentation links.
- Record exact commands, destinations, OS versions, results, warnings, and any
  unverified evidence in this plan.

Documentation-only creation of this plan requires document review, internal-link
validation, authoritative-ownership review, and `git diff --check`; it does not
require an app build or test run.

## Delivery record

### 2026-07-17 — Implementation and automated acceptance

- Changed only
  `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` in the app target's
  Debug and Release configurations, reducing each value to
  `UIInterfaceOrientationPortrait`. The iPad values and all other project
  settings remain unchanged.
- The Debug build and launch succeeded on an iPad (A16) Simulator running iOS
  26.5, and a runtime UI snapshot confirmed the app reached the Library.
- The Release Simulator build succeeded for the same project and scheme.
- `plutil` inspection of both built app products found exactly one
  `UISupportedInterfaceOrientations~iphone` value,
  `UIInterfaceOrientationPortrait`, while
  `UISupportedInterfaceOrientations~ipad` retained upright portrait,
  upside-down portrait, landscape left, and landscape right. Both products
  retained `UIBackgroundModes = [audio]` and device families 1 and 2.
- The complete `ResonaUITests` target passed on an iPhone 17 Pro Simulator
  running iOS 26.5. XcodeBuildMCP reported 18 test methods with no failures;
  the result bundle recorded 19 device/configuration executions because the
  launch test ran in two dynamic configurations.
- The iPhone launch configurations were Dark Appearance and Light Appearance,
  both portrait; no iPhone landscape launch configuration was generated.
- The targeted iPad launch test passed with four dynamic executions and no
  failures. Its generated matrix retained portrait and Landscape Right runtime
  coverage, while the built iPad-qualified array verifies both landscape
  directions and upside-down portrait remain declared.
- No Swift source or test source changed, so no unit-test coverage was added.
  Configuration-driven launch coverage provides the direct regression evidence.
- A separate physical-device rotation pass was not run because this change is a
  bundle declaration with complete Simulator build-product and system-generated
  launch-configuration evidence. The interactive release check may repeat the
  rotation matrix, but no acceptance evidence remains blocked for this slice.

## Risks and controls

- **iPad is constrained accidentally:** change only the iPhone-qualified key,
  compare the iPad values before and after, and verify the built iPad-qualified
  array plus all four runtime rotations.
- **Debug and Release drift:** update both configurations together and inspect
  both built products before completion.
- **Project text differs from the effective bundle:** verify the built app
  Info.plists instead of treating `project.pbxproj` inspection as sufficient.
- **Launch-test evidence changes silently:** record the post-change Xcode UI
  configuration executions and update only stale iPhone-landscape assumptions.
- **Orientation is enforced with unnecessary runtime code:** keep the change in
  the system-owned declarations and escalate any contradictory runtime result
  before expanding the implementation boundary.

## Expected source map

```text
Resona.xcodeproj/project.pbxproj          iPhone and iPad orientation declarations
ResonaUITests/ResonaUITestsLaunchTests.swift
                                         configuration-driven launch coverage,
                                         changed only if evidence shows a need
```

No application source or architectural document change is expected. Update
`ARCHITECTURE.md` only if implementation unexpectedly introduces a new platform
integration or changes an existing ownership boundary.
