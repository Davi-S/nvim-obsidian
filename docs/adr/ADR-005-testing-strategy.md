# ADR-005: Testing Strategy (Unit, Integration, E2E)

## Status

Accepted

## Date

March 28, 2026

## Context

V2 architecture is layered and domain-oriented. Testing strategy must reflect this structure so behavior remains stable while implementation evolves.

Phase 0 requirements include correctness, non-crashing failures, and responsive UX. Those goals require explicit test ownership at each layer.

## Decision Drivers

- Catch regressions early with fast feedback.
- Validate user workflows end-to-end.
- Keep tests aligned with architecture boundaries.
- Prevent over-reliance on slow integration-only tests.

## Selected Approach

Layer-aligned test strategy (unit + integration + e2e).

## Decision

Adopt explicit ownership:

Unit tests:
- Domain logic, parser logic, ranking logic, classifier behavior, and pure transformations.
- No direct Neovim runtime dependency where avoidable.

Integration tests:
- Adapter-service-domain wiring.
- Watcher/index flows and command orchestration behavior.
- Dataview parse/execute/render integration paths.

E2E tests:
- Critical user workflows from product contract.
- Command behavior parity for Omni, journal navigation, follow, backlinks, search, template insert, dataview render, reindex.

## Test Policy

- New feature behavior requires at least one unit or integration test, and when user-visible, an e2e path check.
- Bug fixes require a regression test at the lowest meaningful layer.
- Performance-sensitive paths should include bounded-cost or responsiveness assertions where practical.

## Consequences

### Positive

- Fast and actionable feedback loop.
- Strong confidence in command-level workflows.
- Better alignment between architecture and quality gates.

### Negative

- Initial setup and maintenance cost across three test layers.
- Requires careful fixture strategy to avoid brittle tests.

## Enforcement

- PR checklist must specify affected test layer(s).
- Missing coverage for user-visible behavior blocks merge unless explicitly waived.

## Related Documents

- ../PRODUCT_CONTRACT.md
- ../UX_BEHAVIOR_CONTRACT.md
- ../DOMAIN_OWNERSHIP_MAP.md
- ../PROJECT_CONTEXT.md
