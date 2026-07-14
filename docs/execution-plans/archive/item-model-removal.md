# Item Model Removal Execution Plan

## Status

Complete

## Objective

Close [TD-001](../tech-debt-tracker.md#td-001--removed-scaffold-item) by
removing the unused scaffold `Item` entity from the current SwiftData schema
without deleting or recreating an existing store and without losing Library
songs or pending-removal records.

The approved cleanup intentionally discards historical scaffold `Item` rows.
Those rows contain only an unused timestamp and have no Library or Playback
meaning. Historical schema definitions remain available solely so supported
stores can migrate through the complete version chain.

## Scope

- Add `ResonaSchemaV3` as version 4.0.0 containing only
  `LibrarySongRecord` and `LibrarySongRemovalRecord`.
- Add a V2-to-V3 migration stage that removes the obsolete persisted entity.
- Keep the V0, V1, and V2 schema definitions and the historical `Item` model
  available only to migration code.
- Remove the standalone `Item.swift` source file.
- Verify actual on-disk V0, V1, and V2 stores migrate to V3 without losing
  Library records.
- Update the architecture map and close TD-001 with verification evidence.

No user-visible behavior, deployment target, signing setting, entitlement,
capability, bundle identifier, or third-party dependency changes are in scope.

## Guardrails

- Never delete or recreate the persistent store as a migration fallback.
- Do not transform scaffold rows into Library records.
- Preserve stable song identities, metadata, managed-resource references, and
  pending-removal cleanup ownership.
- Stop and revise this plan if the supported migration chain cannot open an
  actual prior store while preserving its Library data.

## Implementation sequence

1. Move the historical `Item` model definition beside the versioned schemas,
   add V3, and make V3 the production container schema.
2. Add on-disk migration fixtures for every supported prior schema and assert
   preservation of active songs and pending-removal records.
3. Remove `Item.swift`, update architecture and migration documentation, and
   close TD-001 after verification.

## Verification

- Run the focused `ResonaMigrationTests` suite while iterating.
- Run the equivalent `Resona` unit-test action on an eligible physical device.
  Migration tests use isolated temporary on-disk stores and never open the
  device's production Library store.
- Confirm `git diff --check` and verify the current schema contains no `Item`.

## Implementation record

### 2026-07-14 — Completed

- Added `ResonaSchemaV3` version 4.0.0 containing only
  `LibrarySongRecord` and `LibrarySongRemovalRecord`, then made it the
  production container schema.
- Added the lightweight V2-to-V3 stage. The migration intentionally discards
  scaffold `Item` rows while preserving the supported historical schemas and
  their migration-only model definition.
- Removed the standalone `Item.swift` file and added an assertion that the
  current schema excludes its model type.
- Added actual on-disk V0, populated V1, and populated V2 migration coverage.
  The V1 fixture preserved its active song; the V2 fixture preserved both its
  active song and pending-removal record. Core Data reported expected
  persistent-history truncation for the removed entity without deleting or
  recreating any store.
- Focused `ResonaMigrationTests`: 5 tests passed on Leon's physical iPhone 17
  Pro Max.
- Complete `ResonaTests`: 116 tests in 19 suites passed on the same physical
  device.
- UI tests were not run because this cleanup changes no user-visible flow.
