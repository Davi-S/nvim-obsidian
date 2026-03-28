# nvim-obsidian V2: Project Context and Document Map

Created: March 28, 2026
Status: Phase 0 complete (DRY structure)
Architecture: Domain-Driven Design with Clean Architecture layering
Timeline: quality-prioritized

---

## Executive Summary

This is a greenfield rewrite of nvim-obsidian focused on clean boundaries, full core workflow parity with V1, and strict single-source documentation.

This document is the Phase 0 orchestration hub:
- It defines context, architectural framing, and decision history.
- It does not duplicate product policy text that is canonical elsewhere.
- It references all Phase 0 source files and their ownership scope.

Reference vault for examples:
- /home/davi/Documents/ObsidianAllInVault

---

## Section 1: Documentation Topology (Single Source of Truth)

### Canonical files and scope

1. docs/PRODUCT_CONTRACT.md
  - Canonical source for product rules, feature contracts, command scope, Omni semantics, link safety semantics, defaults, configuration, non-goals, performance requirements.

2. docs/UX_BEHAVIOR_CONTRACT.md
  - Canonical source for observable command behavior and user-facing notification semantics.
  - References product rules from PRODUCT_CONTRACT when needed.

3. docs/DOMAIN_OWNERSHIP_MAP.md
  - Canonical source for architectural ownership (domain/service/adapter responsibility map).

4. PHASE_0_REVIEW.md
  - Phase completion snapshot and changelog pointer.
  - Not a policy authority document.

### Topic ownership matrix

- Product rules and policy semantics: docs/PRODUCT_CONTRACT.md
- User-visible command behavior: docs/UX_BEHAVIOR_CONTRACT.md
- Ownership boundaries and responsibility: docs/DOMAIN_OWNERSHIP_MAP.md
- Historical rationale and accepted decisions: PROJECT_CONTEXT.md (this file)

---

## Section 2: V1 Findings Carried Forward

- V1 has feature completeness and useful command workflows.
- V1 has coupling issues from singleton-heavy composition.
- V1 patterns intentionally preserved in V2:
  - Omni search/create workflow quality.
  - Explicit placeholder registration model.
  - Journal per-type subdir model.
  - Dataview configurability.

---

## Section 3: Architecture Boundaries

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

Dependency rule:
Adapters -> Services -> Domains -> Shared

---

## Section 4: Architecture and Testing Plan

Phase 0 specification documents are complete and synchronized:
- docs/PRODUCT_CONTRACT.md
- docs/UX_BEHAVIOR_CONTRACT.md
- docs/DOMAIN_OWNERSHIP_MAP.md
- PHASE_0_REVIEW.md

Execution roadmap:
- docs/IMPLEMENTATION_PHASES.md

Current phase progression:
- Phase 0 completed
- Phase 1 completed (ADRs accepted)
- Phase 2 in progress

Phase 2 artifacts:
- docs/REPOSITORY_LAYOUT.md
- docs/COMPOSITION_ROOT.md
- docs/DEPENDENCY_RULES.md
- docs/PHASE_2_REVIEW.md

Phase 1 ADR baseline (Accepted):
- docs/adr/README.md
- docs/adr/ADR-001-layering-and-dependency-rules.md
- docs/adr/ADR-002-domain-boundaries-and-ownership.md
- docs/adr/ADR-003-public-api-and-command-surface-philosophy.md
- docs/adr/ADR-004-vault-sync-strategy.md
- docs/adr/ADR-005-testing-strategy.md

---

## Section 5: Decision Log Updates

Decision 6: No periodic reconcile loop in V2.0 baseline
- Status: Accepted

Decision 7: Omni-first creation UX; remove :ObsidianNew user command scope
- Status: Accepted

Decision 8: Placeholder registry-only model, no built-in placeholders
- Status: Accepted

Decision 9: Template inheritance out of scope
- Status: Accepted

Decision 10: V1/V2 not intended to run simultaneously
- Status: Accepted

Decision 11: Wikilink display alias does not affect target resolution
- Status: Accepted

Decision 12: Omni force-create allowed only for partial/no-match states
- Status: Accepted

---

Document Status: Updated to DRY single-source topology
Last Updated: March 28, 2026
