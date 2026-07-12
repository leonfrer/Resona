# Testing

## Requirements

- Every bug fix must include a regression test when technically practical.
- New business logic must include unit tests.
- Critical user journeys must have UI test coverage.

## Test design

- Production code must not depend directly on uncontrolled time, randomness, or network behavior.
- Use in-memory SwiftData containers by default in persistence tests.
- Use an isolated temporary on-disk container only when the behavior under test requires destroying and recreating the container, such as relaunch persistence or schema migration. Remove the temporary store after the test.
- Keep tests deterministic and independent of execution order.
