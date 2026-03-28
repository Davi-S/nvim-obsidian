# ADR-002: Domain Boundaries and Ownership

## Status

Accepted

## Date

March 28, 2026

## Context

Phase 0 introduced six core domains and three application services, plus adapters for Neovim, filesystem, and parsing. Ownership is documented in the Domain Ownership Map, but Phase 1 must lock those boundaries as architecture decisions.

If ownership remains informal, implementation may reintroduce mixed concerns and ambiguous responsibility for critical workflows such as Omni creation routing, wikilink resolution, and dataview rendering.

## Decision Drivers

- Remove ambiguity in feature ownership.
- Ensure a single owner per rule-level concern.
- Reduce integration defects from duplicated responsibility.
- Support clear implementation sequencing in later phases.

## Selected Approach

Explicit ownership by domain/service/adapter (single owner per rule).

## Decision

Adopt explicit ownership boundaries as defined in the Domain Ownership Map.

Core domains:
1. Vault Catalog
2. Journal
3. Wiki Link
4. Template
5. Dataview
6. Search Ranking

Application services:
1. Note Lifecycle Service
2. Sync Service
3. Query Render Service

Adapters:
1. Neovim Adapter
2. Filesystem Adapter
3. Parser Adapter

Ownership rule:
- Every feature rule has exactly one primary owner entry in the ownership map.
- Cross-domain workflows must be orchestrated by services, not by direct cross-domain coupling.

## Boundary Rules

- Vault Catalog owns canonical note indexing and identity semantics.
- Journal owns date classification and journal routing logic.
- Wiki Link owns parsing/resolution semantics and ambiguity detection.
- Template owns placeholder registration and rendering behavior.
- Dataview owns query parsing/execution semantics.
- Search Ranking owns ranking/matching behavior for discovery.

Service orchestration:
- Note Lifecycle coordinates create/open flows across domains.
- Sync Service coordinates startup scan, watcher updates, and reindex orchestration.
- Query Render Service coordinates dataview rendering lifecycle.

## Consequences

### Positive

- Clear ownership and reduced overlap.
- Better maintainability for feature evolution.
- More predictable integration behavior.

### Negative

- Requires discipline to keep ownership map current.
- Some boundary decisions may need revisiting as implementation learns emerge.

## Enforcement

- Any ownership change must update Domain Ownership Map in the same PR.
- New feature rules are incomplete unless ownership is assigned.

## Related Documents

- ../DOMAIN_OWNERSHIP_MAP.md
- ../PROJECT_CONTEXT.md
- ../PRODUCT_CONTRACT.md
