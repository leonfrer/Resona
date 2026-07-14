# Delivery Checklist

## Verification

- Select the required evidence, test layers, environment, and commands using
  `testing.md`.
- Build the affected target after code changes.
- Run relevant unit tests when business logic changes.
- Run relevant UI tests when user-facing flows change and before release; skip them for unrelated changes.
- Verify affected performance and storage budgets when the change touches large collections, file processing, launch loading, or managed storage.
- Record the commands, destinations, results, and new warnings. If verification
  cannot be completed, report what was not verified and why.
- For documentation-only changes, verify internal links, status tables, authoritative ownership, and `git diff --check`; do not run app builds or tests.
- Apply the additional release-candidate gates in `release-process.md` only for release work.

## Definition of done

- The affected target builds without introducing new warnings.
- New behavior includes appropriate tests when it contains non-trivial logic.
- Documentation is updated when setup steps, externally visible behavior, or architecture changes.
- Product rules have one authoritative home; other documents link instead of redefining them.
- New persisted technical debt has an owner, cleanup trigger, and exit criteria.
- Generated build artifacts, user-specific Xcode data, secrets, and credentials are not committed.
