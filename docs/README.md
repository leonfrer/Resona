# Documentation Guide

This directory separates product decisions, current technical facts, implementation plans, and delivery evidence so that each rule has one authoritative home.

## Document responsibilities

| Document | Owns | Must not own |
| --- | --- | --- |
| Product specifications | User outcomes, behavior, constraints, and acceptance criteria | Concrete types, algorithms, schemas, folder layouts, or implementation sequence |
| `ARCHITECTURE.md` | Current system map, durable boundaries, dependency direction, and implemented technology choices | Planned behavior or task progress |
| Engineering guidelines | Repository-wide coding conventions | Feature-specific behavior |
| Testing strategy | Required test layers, test design, fixtures, and quality gates | Product decisions or implementation progress |
| Delivery checklist | Definition of done and per-change verification | Long-term release policy |
| Release process | CI direction, release gates, distribution evidence, and rollback | Feature acceptance criteria |
| Execution plans | Temporary implementation decisions, sequencing, risks, and verification record for one delivery slice | New product behavior not approved by an owning specification |
| Technical-debt tracker | Known compromises, interest, owner, cleanup trigger, and closure evidence | Current architecture or unprioritized wish lists |
| `AGENTS.md` | Task-to-document routing and repository operating rules | Detailed feature or architecture documentation |

## Single-source rule

- State a product rule completely in its owning specification once.
- Other specifications link to that rule and describe only their additional responsibility.
- Cross-feature indexes summarize ownership; they do not restate full behavior.
- Architecture records an implementation choice only after it exists in the current system.
- Execution plans may cite an approved rule and explain how to implement it, but they do not become a second behavioral source of truth.
- Tests should name or link the acceptance criterion they prove when the relationship is not obvious.

When documents disagree, do not choose the most detailed statement automatically. Resolve the conflict in the authoritative document and replace the duplicate with a link.

## Change routing

- Behavior changes update the owning product specification before or with implementation.
- Boundary, ownership, schema, persistence technology, or platform-integration changes update `ARCHITECTURE.md` after implementation is verified.
- Implementation-only decisions stay in code or the active execution plan.
- Performance or capacity changes update `product-specs/quality-attributes.md`.
- Test-policy changes update `testing.md`; release-gate changes update `release-process.md` or `delivery-checklist.md`.

See `AGENTS.md` for the minimal reading set by task type, `execution-plans/README.md` for plan lifecycle rules, and `execution-plans/tech-debt-tracker.md` for tracked cleanup work.
