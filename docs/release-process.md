# Release Process

This document defines Resona's release and CI direction. Resona currently has local validation scripts but no hosted CI workflow in the repository.

## Change validation

Every pull request should eventually run these required jobs in hosted CI:

| Job | Command or scope | Trigger |
| --- | --- | --- |
| Fast validation | `./scripts/check.sh` | Every pull request |
| Simulator build | `./scripts/build.sh` in Debug and Release | Every pull request |
| UI journeys | `./scripts/test-ui.sh`, serially | Changes to user-visible flows and merges to the release branch |
| Full validation | `./scripts/check-all.sh` | Release candidates |
| Documentation integrity | Check internal Markdown links and required status headings | Every pull request |

CI must pin the Xcode version and record the selected Simulator runtime. Dependency caches and DerivedData may improve speed but must not be required for correctness. Secrets, signing identities, and App Store credentials must be isolated to protected release jobs and must never run for untrusted pull requests.

Until hosted CI exists, the author records equivalent local commands and results in the pull request or execution plan. A green local run is evidence, not a claim that hosted CI exists.

## Release candidate gates

A release candidate requires:

- An explicit release scope and resolved product-spec status for included behavior.
- A clean Release build without new application warnings.
- Passing unit and critical UI suites on the pinned Xcode and iOS runtime.
- Migration verification from every supported persisted schema.
- Performance and storage evidence required by `product-specs/quality-attributes.md`.
- Interactive iPhone and iPad review of the affected journeys, Dark Mode, accessibility text sizing, and VoiceOver-critical controls.
- An eligible physical device is the primary release-candidate validation destination. Use Simulator additionally for device and runtime matrices or when a test's isolation requirements make the physical device ineligible.
- Physical-device verification for background audio, lock-screen behavior, audio routes, storage pressure, performance budgets, or other behavior that Simulator cannot establish.
- Release notes covering user-visible changes, known limitations, and any deferred manual checks.

Changing the marketing version or build number is release preparation. Changing signing, bundle identifiers, entitlements, capabilities, deployment targets, or App Store configuration still requires the explicit approval defined in `AGENTS.md`.

## Distribution sequence

1. Choose the release commit from a protected, fully validated branch.
2. Set the approved version and monotonically increasing build number.
3. Archive with the pinned Xcode version and validate the archive.
4. Verify bundle identity, supported devices, privacy metadata, capabilities, signing, and embedded provisioning information.
5. Upload to the approved distribution destination and retain the archive and validation log.
6. Use staged internal or TestFlight validation before public distribution when distribution is enabled.
7. Promote only after release-candidate gates pass; tag the exact shipped commit and publish release notes.

## Failure and rollback

- Do not ship from a different commit than the verified archive source.
- If a candidate fails, fix forward on a new build number and repeat the affected gates.
- Never downgrade or delete a user's persistent store as rollback.
- A data-model rollback requires a forward-compatible migration plan and explicit approval.
- For a production regression, document whether mitigation is a configuration change, hotfix, or release withdrawal, and preserve diagnostic evidence without collecting private media or metadata.

## CI adoption order

1. Add required pull-request unit and Simulator build jobs.
2. Add documentation-link validation.
3. Add serial critical UI tests on protected merges or a scheduled runner.
4. Add protected archive and distribution jobs only after signing ownership and secret management are approved.

The delivery checklist remains the per-change definition of done; this document owns release-wide gates and CI policy.
