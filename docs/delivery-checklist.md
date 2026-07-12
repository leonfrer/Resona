# Delivery Checklist

## Verification

- Run `./scripts/check.sh` for the standard fast suite; its unit-test action builds the required targets.
- Run `./scripts/check-all.sh` when the change requires the full suite, including UI tests.
- Use `./scripts/build.sh`, `./scripts/test-unit.sh`, or `./scripts/test-ui.sh` when only targeted validation is required.
- Build the affected target after code changes.
- Run relevant unit tests when business logic changes.
- Run relevant UI tests when user-facing flows change and before release; skip them for unrelated changes.
- Prefer XcodeBuildMCP for Simulator launches, UI inspection, screenshots, and runtime logs when it is available.
- Override the default Simulator with the `DESTINATION` environment variable when necessary.
- If verification cannot be completed, clearly report what was not verified and why.

## Definition of done

- The affected target builds without introducing new warnings.
- New behavior includes appropriate tests when it contains non-trivial logic.
- Documentation is updated when setup steps, externally visible behavior, or architecture changes.
- Generated build artifacts, user-specific Xcode data, secrets, and credentials are not committed.
