# ADR-004: Vault Sync Strategy (Scan + Watcher + Manual Reindex)

## Status

Accepted

## Date

March 28, 2026

## Context

The plugin depends on a correct in-memory vault index for discovery, wikilink resolution, backlinks, and completion. Phase 0 decided against periodic automatic reconciliation in V2.0 baseline due to UI responsiveness concerns.

A clear sync strategy is required to balance correctness with performance.

## Decision Drivers

- Keep UI responsive under normal and large vaults.
- Maintain index correctness for all user workflows.
- Provide deterministic recovery path for drift.
- Avoid hidden background loops with unpredictable cost.

## Selected Approach

Startup full scan + watcher-driven incremental updates + manual full reindex.

## Decision

1. Full asynchronous vault scan at startup.
2. Watcher/event-driven incremental index updates for create/modify/delete/rename.
3. No periodic automatic reconciliation in V2.0 baseline.
4. Explicit manual full rebuild command via :ObsidianReindex.

## Operational Rules

- Reindex replaces in-memory index atomically.
- Event processing must avoid UI thread blocking.
- Rename handling must maintain canonical path consistency.
- Reindex completion/failure should produce user-visible status.

## Consequences

### Positive

- Strong responsiveness profile.
- Clear and deterministic failure recovery path.
- Lower background activity and simpler runtime behavior.

### Negative

- Manual intervention needed in rare index drift scenarios.
- Watcher reliability remains an operational dependency.

## Enforcement

- Do not add periodic reconcile loops without a superseding ADR.
- Any sync model change must update product contract and this ADR.

## Related Documents

- ../PRODUCT_CONTRACT.md
- ../UX_BEHAVIOR_CONTRACT.md
- ../PROJECT_CONTEXT.md
