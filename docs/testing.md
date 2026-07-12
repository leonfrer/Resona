# Testing

## Requirements

- Every bug fix must include a regression test when technically practical.
- New business logic must include unit tests.
- Critical user journeys must have UI test coverage.

## Test design

- Production code must not depend directly on uncontrolled time, randomness, or network behavior.
- Use in-memory SwiftData containers in persistence tests.
- Keep tests deterministic and independent of execution order.
