# Resona Agent Guide

Resona is an iOS application built with SwiftUI and SwiftData.

## Core rules

- Make the smallest change that fully satisfies the request.
- Do not modify unrelated files or reformat unrelated code.
- Preserve existing user changes in the working tree.
- Do not add third-party dependencies unless explicitly approved.
- Prefer Apple frameworks available in the deployment target.
- Ask before changing deployment targets, bundle identifiers, signing settings, or entitlements.
- Ask before deleting files or making destructive data-model changes.

## Documentation

Start with `docs/README.md`, then read only the documents mapped to the task. Do not read every document by default.

| Task | Required documents |
| --- | --- |
| User-visible behavior or acceptance criteria | The owning spec linked from `docs/product-specs/index.md`; also read `experience-foundation.md` only for navigation, feedback, accessibility, or visual changes |
| Architecture, state ownership, persistence, or platform integration | `ARCHITECTURE.md` and `docs/engineering-guidelines.md` |
| Small implementation or refactor within an existing boundary | `docs/engineering-guidelines.md`; read the owning spec only if behavior could change |
| Bug fix | The owning spec, the relevant section of `docs/testing.md`, and affected code/tests |
| Test-only change | `docs/testing.md` |
| CI, release, or delivery work | `docs/release-process.md` and `docs/delivery-checklist.md` |
| Execution planning | The owning spec, relevant architecture sections, and `docs/execution-plans/README.md` |
| Documentation-only change | `docs/README.md` and the documents being edited |

Document roles:

- Current system map and architectural boundaries: `ARCHITECTURE.md`
- User-visible behavior and acceptance criteria: `docs/product-specs/index.md`
- Performance, capacity, and storage expectations: `docs/product-specs/quality-attributes.md`
- Engineering, Swift, and SwiftUI guidelines: `docs/engineering-guidelines.md`
- Test requirements and test design: `docs/testing.md`
- Verification and definition of done: `docs/delivery-checklist.md`
- Release and CI direction: `docs/release-process.md`

When a change affects documented behavior or architecture, update the relevant document.

## Validation

- For documentation-only changes, do not run app builds or tests. Verify the changed documents, internal links, and `git diff --check` instead.
- When XcodeBuildMCP is available, use it for physical-device or Simulator builds, tests, app launches, UI inspection, screenshots, and runtime logs.
- On an eligible physical device, run the equivalent `Resona` scheme unit or UI test actions with XcodeBuildMCP; the shell scripts force unsigned Simulator destinations.
- When Simulator is the selected destination, run `./scripts/check.sh` for the standard fast validation suite; the unit-test action builds its required targets.
- Run `./scripts/check-all.sh` on Simulator when a full validation including UI tests is required and the physical-device run does not cover the required device or runtime matrix.
- Use `./scripts/build.sh`, `./scripts/test-unit.sh`, or `./scripts/test-ui.sh` for targeted shell-based validation.
- Run UI tests for user-facing flow changes and before release; do not run them by default for unrelated changes.
- Prefer an eligible physical iPhone or iPad over Simulator for builds, tests, launches, UI inspection, and runtime validation. A device is eligible when it is connected and trusted, runs a supported OS, has working signing, can use isolated non-sensitive test data, and supports the behavior under test.
- Use Simulator when no eligible physical device is available or when deterministic seeded state, destructive test isolation, runtime matrices, or Simulator-only tooling is required. Prefer an already booted Simulator; otherwise use an available iPhone Simulator with the latest installed iOS runtime.
- Override the shell test destination when needed, for example: `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' ./scripts/test-unit.sh`.
- Report any validation step that could not run and explain why.
