# Engineering Guidelines

`ARCHITECTURE.md` is the source of truth for the current system map and durable architectural boundaries. This document defines implementation conventions within those boundaries.

## Technical direction

- Build the UI with SwiftUI.
- Use SwiftData for local persistence.
- Prefer Apple frameworks already available in the deployment target.
- Introduce UIKit only when SwiftUI cannot reasonably provide the required behavior.

## Swift style

- Follow the Swift API Design Guidelines.
- Prefer clear names over abbreviations.
- Use access control deliberately; default implementation details to `private`.
- Avoid force unwraps, force casts, and implicitly unwrapped optionals unless justified by an invariant.
- Keep one primary type per file, except for small, tightly coupled helper types.
- Use `// MARK:` sections only when they improve navigation.

## SwiftUI views

- Keep views declarative and move non-trivial business logic out of `body`.
- Extract a subview when it has an independent responsibility or is reused; do not split views solely to reduce line count.
- Keep view state private unless another type genuinely owns it.
- Provide a working `#Preview` for new reusable views and major screens.
- Keep user-facing text ready for localization; do not assemble sentences from fragmented strings.
- Provide accessibility labels for icon-only interactive controls.

## State management

- Use local `@State` for view-owned transient state.
- Use the Observation framework for shared mutable presentation state.
- Pass immutable data and actions explicitly where practical.
- Do not introduce a view model unless the screen has meaningful presentation logic, asynchronous coordination, or independently testable state.

## Persistence

- Keep SwiftData models focused on persisted data and relationships.
- Do not expose `ModelContext` outside the persistence or feature boundary without a clear need.
- Use in-memory model containers in previews and persistence tests.
- Treat schema changes as migrations: do not rename or remove persisted properties without considering existing user data.

## Concurrency

- Use structured concurrency with `async`/`await`.
- Keep UI state mutations on `@MainActor`.
- Do not use detached tasks unless isolation from the current task is intentional.
- Handle cancellation in work that may outlive a screen or be restarted.
- Avoid `@unchecked Sendable` unless its safety is documented.

## Error handling

- Do not silently discard errors.
- Present recoverable user-facing failures with an actionable message.
- Reserve `fatalError` and force unwraps for programmer errors or provably valid invariants.
- Do not log sensitive user data.

## Branch names

Use the format `<type>/<short-kebab-case-description>`.

Commonly used types:

- `feature` — a new feature or user-visible behavior change.
- `fix` — a bug fix.
- `test` — test coverage or test stability work.
- `docs` — documentation only.
- `chore` — delivery, build scripts, CI, tooling, or project configuration.
- `refactor` — code changes that do not alter user-visible behavior.
- `release` — release preparation.
- `hotfix` — an urgent production fix.

Rules:

- Use lowercase words separated by hyphens.
- Describe the change's scope or outcome rather than its author or tool.
- Prefer three to six descriptive words and omit redundant context.
- Include a work-item identifier after the type when one exists, for example `fix/123-import-cancellation`.
- Do not add an author or agent prefix unless repository automation explicitly requires one.

Examples: `feature/basic-playback`, `fix/import-cancellation`, and `chore/import-songs-delivery`.

### Creating a branch

When asked to create a branch, use the latest remote default branch as its base unless another base is explicitly requested:

1. Run `git switch main`.
2. Run `git pull --ff-only origin main`.
3. Run `git switch -c <branch-name>`.

Do not create a new branch from the currently checked-out feature branch by default.

## Commit messages

Follow the [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) specification.

Subject format: `<type>[optional scope][optional !]: <description>`

An optional body and footer may follow the subject as defined by the specification.

Commonly used types:

- `feat` — a new feature or user-visible behavior change.
- `fix` — a bug fix.
- `refactor` — code change that neither fixes a bug nor adds a feature.
- `docs` — documentation only.
- `test` — adding or updating tests.
- `chore` — build scripts, CI, tooling, or project config.
- `style` — formatting, whitespace, or code style (no logic change).

Rules:

- Keep the subject line under 72 characters.
- Use the imperative mood in the description (`add`, not `added`).
- Use a scope when the change is clearly limited to one area, e.g. `feat(playback): add repeat mode`.
- Add `BREAKING CHANGE:` in the footer or `!` after the type/scope for breaking changes.

## GitHub workflow

- Prefer the `gh` CLI for GitHub operations, including pull requests, issues, checks, and workflow inspection.
- Run `gh` in the host-machine environment so it can use the user's keychain authentication and normal network access. Use another GitHub integration only when the host `gh` CLI is unavailable or the user explicitly requests it.
- Verify host authentication with `gh auth status` before a GitHub mutation.
- Create pull requests as ready for review by default. Create a draft PR only when the user explicitly requests a draft.
