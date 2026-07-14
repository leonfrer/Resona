# Development Schema Simplification Execution Plan

## Status

Complete

## Objective

Keep one current SwiftData schema while Resona is in development and remove
the historical version and migration definitions. Compatibility with V0–V3
development stores is intentionally no longer guaranteed; developers may need
to remove the installed development app and recreate its local store.

## Scope

- Replace `ResonaSchemaV0` through `ResonaSchemaV3` with one unversioned
  `ResonaSchema.current` definition.
- Remove `ResonaMigrationPlan` and construct the production container without
  a migration plan.
- Remove the migration-only scaffold `Item` type.
- Remove historical migration tests while retaining current-schema and
  container-recreation persistence coverage.
- Update the current architecture and preserve earlier completed plans as
  historical records of the decisions that applied when they were delivered.

No automatic store deletion, user-visible flow, deployment target, signing,
entitlement, capability, bundle identifier, or dependency change is in scope.

## Verification

- Assert that the sole schema contains only `LibrarySongRecord` and
  `LibrarySongRemovalRecord`.
- Recreate a container over the same temporary store and verify song identity
  and metadata persist.
- Run the complete `ResonaTests` action on an eligible physical device.
- Run `git diff --check` and confirm no production or test code references a
  historical schema or migration plan.

## Implementation record

### 2026-07-14 — Completed

- Replaced the four `VersionedSchema` definitions with one
  `ResonaSchema.current` containing only the active song and pending-removal
  records.
- Removed `ResonaMigrationPlan`, every migration stage, the migration-only
  `Item` model, and historical migration fixtures.
- Replaced `ResonaMigrationTests` with `ResonaPersistenceTests`, covering the
  exact current model set and song persistence across container recreation.
- Focused persistence tests passed 2 of 2 cases on Leon's physical iPhone 17
  Pro Max running iOS 26.5.2.
- The complete physical-device unit and integration action passed all 113
  tests with no failures or skips.
- UI tests were not run because the persistence simplification changes no
  user-visible flow.
