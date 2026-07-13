# Testing

Testing provides evidence that product behavior, architectural boundaries, migrations, and quality budgets remain correct. Prefer the lowest test layer that proves the behavior reliably, then add UI coverage only for critical integration journeys.

## Required coverage by change

- Every bug fix must include a regression test when technically practical.
- New business logic must include unit tests.
- Critical user journeys must have UI test coverage.
- Persisted-schema changes must include migration tests from every supported prior schema and prove user data is preserved.
- File ownership, cleanup, and recovery changes must test success, partial failure, cancellation, interruption, and idempotent retry.
- Concurrency changes must cover cancellation and stale-result ordering deterministically.
- Accessibility behavior must be asserted where semantics are available and inspected interactively for critical journeys.
- Performance- or capacity-sensitive changes must include evidence against `product-specs/quality-attributes.md`.
- Capability, audio-session, background, route, or hardware-dependent changes require the relevant physical-device evidence when Simulator cannot establish the acceptance criterion.

When a test is technically impractical, record the missing evidence, reason, risk, and manual or lower-layer substitute in the delivery report.

## Test layers

| Layer | Use for | Avoid |
| --- | --- | --- |
| Pure unit | Domain rules, reducers, formatting, sorting, state transitions, failure mapping | Apple framework behavior |
| Boundary or adapter | SwiftData repositories, file storage, AVFoundation adapters, migration, dependency contracts | Repeating UI presentation assertions |
| Presentation state | Observable stores, async coordination, stale results, action availability | Pixel-level layout claims |
| UI test | Critical end-to-end app journeys, navigation, system-facing presentation, accessibility identifiers | System Files automation and timing-sensitive media assertions |
| Interactive or device | Visual quality, VoiceOver order, real file handoff, background/lock audio, route changes, performance | Logic that can be deterministic in automated tests |

## Test environment priority

Use an eligible physical iPhone or iPad as the primary destination when it can satisfy the test's isolation, data, OS, signing, and observability requirements. This applies to builds, automated tests, app launches, UI inspection, performance measurements, and runtime validation—not only to checks that are impossible on Simulator.

A physical device is eligible when it:

- Is connected, trusted, available for the duration of the run, and uses a supported OS version.
- Has valid development signing without changing project signing settings.
- Can run with isolated, non-sensitive fixtures and can be returned to a known state without risking personal data.
- Supports every framework, capability, logging, and inspection requirement needed by the test.
- Has enough free storage and power for the planned workload.

Use Simulator instead when no eligible device exists, or when the test requires deterministic seeded state, disposable stores, destructive failure injection, multiple OS/device configurations, unsupported host automation, or other isolation that the physical device cannot provide. Record the chosen destination and, when Simulator is used despite an available device, the requirement that made the device ineligible.

Physical-device priority does not eliminate Simulator coverage. Release work still covers representative iPhone and iPad layouts and supported runtime configurations that one device cannot represent.

## Test design

- Production code must not depend directly on uncontrolled time, randomness, or network behavior.
- Inject clocks, UUID generation, randomness, file access, media adapters, and failure points when control is needed.
- Use in-memory SwiftData containers by default in persistence tests.
- Use an isolated temporary on-disk container only when the behavior under test requires destroying and recreating the container, such as relaunch persistence or schema migration. Remove the temporary store after the test.
- Keep tests deterministic and independent of execution order.
- Run UI tests serially on the selected Simulator. `scripts/test-ui.sh` disables parallel testing so Xcode does not create competing cloned Simulators for the launch-configuration matrix.
- Assert observable outcomes and owned side effects rather than private implementation details.
- Use explicit async synchronization or controllable fakes. Do not stabilize tests with arbitrary sleeps.
- Keep locale and calendar fixed when asserting exact localized order or formatting.
- Make each test arrange its own state and clean up temporary files with `defer`.

## Persistence and migration

- Test domain-value round trips and unavailable-resource derivation through the repository boundary.
- Migration fixtures must be created with the actual prior schema, reopened with the current migration plan, and inspected for both preserved records and newly supported records.
- Never make store deletion or recreation the success path of a migration test.
- Additive changes still require a migration test when the production container is versioned.
- Test save failures and verify the in-memory context does not leak a partially accepted mutation.

## Files, import, and media

- Use temporary directories for managed-storage tests and assert both expected files and absence of orphaned files.
- Cover invalid paths, missing files, partial cleanup, already-missing cleanup targets, and containment boundaries.
- Keep the smallest legally generated audio fixtures that exercise supported container and codec families. Document fixture generation in `ResonaTests/Fixtures/README.md`.
- Keep large performance files generated or sparse; do not add multi-gigabyte fixtures to the repository.
- Test system file-picker integration at Resona's handoff boundary. Verify real Files selection interactively because automating another app is not a stable UI-test contract.

## Playback

- Model playback as deterministic state transitions driven by controllable engine and audio-session events.
- Tag or otherwise control stale events so replacement, cancellation, natural end, failure, and retry races can be reproduced.
- Adapter tests may use real local fixtures, but audible playback, lock behavior, route changes, and system remote commands require interactive or physical-device evidence when introduced.
- UI tests should assert controls and visible state, not elapsed-time precision that belongs in state tests.

## UI and accessibility

- Use debug-only seeded scenarios and injected dependencies. Production behavior must not branch on UI-test arguments outside `DEBUG`.
- Assign stable accessibility identifiers to critical controls and state, while keeping VoiceOver labels user-oriented.
- Cover the empty state, primary happy path, actionable failure, and recovery path for each critical journey.
- Exercise an accessibility text size and verify primary actions remain visible and hittable.
- Interactively inspect VoiceOver order, Dark Mode, Increased Contrast when relevant, Reduce Motion, and representative iPhone and iPad layouts before release.

## Performance and storage

- Performance tests use Release builds on an eligible physical device and record device, OS, dataset, sample count, and measurement tool. Simulator measurements are diagnostic only and do not satisfy release budgets.
- Do not place fragile wall-clock thresholds in the ordinary unit suite. Use deterministic signposts or counters in CI and record device budgets during release qualification.
- Maintain generated 1,000- and 10,000-record library datasets.
- Measure launch-to-usable time, list hitching, peak memory during large-file processing, cancellation latency, free-space failure, and cleanup convergence when those paths change.

## Fixtures and naming

- Name a test for the behavior and expected outcome, not the method it calls.
- Keep fixtures minimal, documented, immutable, and outside the production target when possible.
- Prefer builders and focused fakes over a shared mutable global test environment.
- A quarantined or skipped test must link to an owner and removal condition; silently ignoring flaky coverage is not acceptable.

## Commands

- On an eligible physical device, use XcodeBuildMCP or an equivalent `xcodebuild` destination to run the `Resona` scheme's required unit and UI test actions.
- `./scripts/check.sh`: standard fast Simulator suite; currently runs unit and integration tests.
- `./scripts/check-all.sh`: full Simulator suite including serial UI tests.
- `./scripts/build.sh`, `./scripts/test-unit.sh`, and `./scripts/test-ui.sh`: targeted validation.
- Override `DESTINATION` to validate a relevant iPhone or iPad Simulator.

The active execution plan maps feature acceptance criteria to the required test layers. The delivery report records exact commands, destinations, results, warnings, and unverified checks.
