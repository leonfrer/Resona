# Delivery Checklist

## Verification

- On an eligible physical device, run the required `Resona` scheme test actions with XcodeBuildMCP or an equivalent physical-device destination.
- When Simulator is the selected destination, run `./scripts/check.sh` for the standard fast suite; its unit-test action builds the required targets.
- Run `./scripts/check-all.sh` when the change requires the full Simulator suite, including UI tests or a runtime matrix not covered by the physical device.
- Use `./scripts/build.sh`, `./scripts/test-unit.sh`, or `./scripts/test-ui.sh` when only targeted validation is required.
- Build the affected target after code changes.
- Run relevant unit tests when business logic changes.
- Run relevant UI tests when user-facing flows change and before release; skip them for unrelated changes.
- Verify affected performance and storage budgets when the change touches large collections, file processing, launch loading, or managed storage.
- Prefer an eligible physical iPhone or iPad as the primary validation destination. Use Simulator when device eligibility or test-isolation requirements are not met, and record why.
- Prefer XcodeBuildMCP for device or Simulator launches, UI inspection, screenshots, and runtime logs when it is available.
- Override the default Simulator with the `DESTINATION` environment variable when necessary.
- If verification cannot be completed, clearly report what was not verified and why.
- For documentation-only changes, verify internal links, status tables, authoritative ownership, and `git diff --check`; do not run app builds or tests.
- Apply the additional release-candidate gates in `release-process.md` only for release work.

## Definition of done

- The affected target builds without introducing new warnings.
- New behavior includes appropriate tests when it contains non-trivial logic.
- Documentation is updated when setup steps, externally visible behavior, or architecture changes.
- Product rules have one authoritative home; other documents link instead of redefining them.
- New persisted technical debt has an owner, cleanup trigger, and exit criteria.
- Generated build artifacts, user-specific Xcode data, secrets, and credentials are not committed.
