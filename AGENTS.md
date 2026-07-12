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

Read the documents relevant to the task before making changes:

- Current system map and architectural boundaries: `ARCHITECTURE.md`
- User-visible behavior and acceptance criteria: `docs/product-specs/index.md`
- Engineering, Swift, and SwiftUI guidelines: `docs/engineering-guidelines.md`
- Test requirements and test design: `docs/testing.md`
- Verification and definition of done: `docs/delivery-checklist.md`

When a change affects documented behavior or architecture, update the relevant document.

## Validation

- When XcodeBuildMCP is available, use it for Simulator builds, tests, app launches, UI inspection, screenshots, and runtime logs.
- Run `./scripts/check.sh` for the standard fast validation suite; the unit-test action builds its required targets.
- Run `./scripts/check-all.sh` when a full validation including UI tests is required.
- Use `./scripts/build.sh`, `./scripts/test-unit.sh`, or `./scripts/test-ui.sh` for targeted shell-based validation.
- Run UI tests for user-facing flow changes and before release; do not run them by default for unrelated changes.
- Prefer an already booted Simulator for interactive validation. Otherwise, use an available iPhone Simulator with the latest installed iOS runtime.
- Override the shell test destination when needed, for example: `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' ./scripts/test-unit.sh`.
- Report any validation step that could not run and explain why.
