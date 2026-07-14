# Resona Agent Guide

Resona is an iOS application built with SwiftUI and SwiftData.

## Core rules

- Make the smallest change that fully satisfies the request.
- Do not modify unrelated files or reformat unrelated code.
- Preserve existing user changes in the working tree.
- Do not add third-party dependencies unless explicitly approved.
- Prefer Apple frameworks available in the deployment target.
- Ask before changing deployment targets, bundle identifiers, signing settings,
  entitlements, capabilities, background modes, or App Store configuration.
- Ask before deleting files or making destructive data-model changes.

## Documentation

Start with `docs/README.md`, then read every row below that applies to the
task. Do not read unrelated documents by default.

| Task | Required documents |
| --- | --- |
| User-visible behavior or acceptance criteria | The owning spec linked from `docs/product-specs/index.md`; also read `docs/product-specs/experience-foundation.md` for navigation, feedback, accessibility, or visual changes |
| Architecture, state ownership, persistence, or platform integration | `ARCHITECTURE.md` and `docs/engineering-guidelines.md` |
| Implementation or refactor within an existing boundary | `docs/engineering-guidelines.md`, the relevant sections of `docs/testing.md`, and `docs/delivery-checklist.md`; read the owning spec if behavior could change |
| Bug fix | The owning spec when user-visible behavior is involved, the relevant sections of `docs/testing.md`, `docs/delivery-checklist.md`, and affected code/tests |
| Test-only change | `docs/testing.md` and `docs/delivery-checklist.md` |
| Performance, capacity, or storage work | `docs/product-specs/quality-attributes.md`, the relevant sections of `docs/testing.md`, and `docs/delivery-checklist.md`; also read `ARCHITECTURE.md` if ownership or storage boundaries could change |
| Dependencies, project configuration, capabilities, or signing | `docs/engineering-guidelines.md`; also read the relevant platform-integration sections of `ARCHITECTURE.md` if a boundary could change, and `docs/release-process.md` for signing, distribution, or delivery configuration |
| Technical-debt cleanup | `docs/engineering-guidelines.md` and the relevant entry in `docs/execution-plans/tech-debt-tracker.md` when one exists; also read `docs/execution-plans/README.md` when the cleanup requires an execution plan |
| CI, release, or delivery work | `docs/release-process.md` and `docs/delivery-checklist.md` |
| Branches, commits, pushes, or GitHub pull requests | `docs/engineering-guidelines.md`, especially its Git workflow sections |
| Execution planning | `docs/execution-plans/README.md` plus every document mapped to the change being planned |
| Documentation-only change | `docs/README.md` and the documents being edited |

Document roles:

- Current system map and architectural boundaries: `ARCHITECTURE.md`
- User-visible behavior and acceptance criteria: the product specifications
  indexed by `docs/product-specs/index.md`
- Performance, capacity, and storage expectations: `docs/product-specs/quality-attributes.md`
- Engineering, Swift, and SwiftUI guidelines: `docs/engineering-guidelines.md`
- Test requirements and test design: `docs/testing.md`
- Verification and definition of done: `docs/delivery-checklist.md`
- Release and CI direction: `docs/release-process.md`

When a change affects documented behavior or architecture, update the relevant document.

## Validation

- Use `docs/testing.md` to select required evidence, test layers,
  environments, and commands when code or tests change. Use
  `docs/delivery-checklist.md` as the definition of done for every change, and
  apply `docs/release-process.md` gates only to release work.
- For documentation-only changes, do not run app builds or tests. Verify the
  changed documents, internal links, authoritative ownership, and
  `git diff --check` instead.
- Report every validation step that could not run and explain why.
