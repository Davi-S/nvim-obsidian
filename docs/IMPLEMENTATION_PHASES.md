# V2 Implementation Phases

Status: Active roadmap
Last Updated: March 28, 2026

This document is the execution roadmap for V2. It captures phase goals, deliverables, and verification criteria so progress remains explicit and traceable.

## Current Progress Snapshot

- Phase 0: Completed
- Phase 1: Completed and approved (ADRs accepted)
- Phase 2: Completed
- Phase 3: Completed
- Phase 4: Completed
- Phase 5: Completed
- Phase 6: Completed
- Phase 7: Completed
- Phase 8: In progress (Part 1 complete)

---

## Phase 0: Product Contract and Boundaries

Goal: Define exactly what V2 is and is not.

Deliverables:
1. V2 feature contract:
   - Must-have features (journal, links, templates, dataview, search, completion).
   - Explicit non-goals.
2. UX behavior contract:
   - Command behavior.
   - Error and notification behavior.
3. Ubiquitous language glossary:
   - Note, vault, journal note, link target, query block, render placement, etc.
4. Domain map with ownership.

Verification:
1. Every feature maps to one owning domain.
2. No feature has shared ownership ambiguity.
3. Non-goals are explicit to avoid scope creep.

---

## Phase 1: Architecture and ADR Baseline

Goal: Freeze the foundational architecture before coding.

Deliverables:
1. ADR-001 Layering and dependency rules.
2. ADR-002 Domain boundaries and ownership.
3. ADR-003 Public API philosophy.
4. ADR-004 Sync strategy (full scan + incremental watcher model).
5. ADR-005 Testing strategy (unit/integration/e2e split).

Verification:
1. One-way dependency graph approved.
2. No domain depends on adapters.
3. All critical decisions have rationale and consequences documented.

---

## Phase 2: Repository Skeleton and Composition Root

Goal: Create the empty but strict structure that enforces architecture.

Deliverables:
1. Repository layout (core, use cases, adapters, app bootstrap, tests, docs).
2. Composition root/container wiring pattern.
3. Static dependency rules documented.
4. Minimal plugin entrypoint scaffolding.

Verification:
1. Structure compiles/loads with placeholder modules.
2. Boundary rules are visible and enforceable by convention and tests.
3. No direct Neovim API usage outside adapter folders.

---

## Phase 3: Domain Contracts (No Implementations Yet)

Goal: Define stable interfaces and data models.

Deliverables:
1. Contracts for:
   - Vault Catalog
   - Journal
   - Wiki Link
   - Template
   - Dataview
   - Search Ranking
2. Shared data model primitives:
   - Note identity
   - Link target
   - Query result
   - Domain error types
3. Use-case contracts:
   - Ensure/open note
   - Follow link
   - Reindex/sync
   - Render query blocks

Verification:
1. Contracts are deterministic and side-effect expectations are explicit.
2. Inputs/outputs are fully typed by shape (Lua table schemas).
3. Cross-domain communication only via contracts.

---

## Phase 4: Test Strategy and Harness First

Goal: Build test infrastructure before real code.

Deliverables:
1. Unit harness for pure domain modules.
2. Integration harness for adapter interactions.
3. E2E harness for command-level behavior in headless Neovim.
4. Golden behavior scenarios derived from current plugin edge cases.

Verification:
1. Test pyramid is clear:
   - Many unit tests
   - Fewer integration tests
   - Minimal but meaningful e2e tests
2. First failing tests exist for each domain contract.
3. Deterministic fixtures for vault and markdown content are in place.

---

## Phase 5: Implement Core Domains (Pure Logic)

Goal: Implement all domain modules without Neovim coupling.

Order:
1. Journal
2. Template
3. Search Ranking
4. Wiki Link
5. Vault Catalog
6. Dataview

Deliverables:
1. Domain implementations passing unit tests.
2. Domain invariants documented.
3. Domain-specific error semantics finalized.

Verification:
1. Domain tests pass with no adapter dependencies.
2. Contract tests pass for each domain.
3. Mutation scenarios covered (especially for Vault Catalog and Dataview).

---

## Phase 6: Implement Use-Case Layer

Goal: Orchestrate domain behaviors into plugin actions.

Deliverables:
1. Ensure note workflow.
2. Follow link workflow.
3. Reindex/sync workflow.
4. Dataview render workflow.
5. Search/open/create workflow.

Verification:
1. Use-case tests pass with mocked ports/adapters.
2. Happy path and failure paths verified for each use case.
3. No adapter-specific code in use cases.

Status notes (March 2026):
1. All five Phase 6 workflows are implemented and unit-tested:
   - Ensure note workflow
   - Follow link workflow
   - Reindex/sync workflow
   - Dataview render workflow
   - Search/open/create workflow
2. Contract-alignment gaps identified during review were patched:
   - Omni create path routes through journal classification when applicable.
   - Follow-link ambiguous targets support disambiguation picker flow.
   - Full reindex enforces atomic catalog replacement via required hook.

---

## Phase 7: Implement Adapters

Goal: Attach Neovim, filesystem, and plugin ecosystem integrations.

Deliverables:
1. Neovim command adapter.
2. Telescope picker adapter.
3. Completion source adapter.
4. Buffer/window navigation adapter.
5. Notification adapter.
6. File IO and watcher adapter.
7. Parser adapters (frontmatter/markdown extraction).

Verification:
1. Integration tests validate adapter-to-use-case wiring.
2. No business rules introduced in adapters.
3. Adapter failures produce normalized domain/app errors.

Status notes (March 2026):
1. All seven Phase 7 adapter deliverables are implemented:
   - Neovim command adapter
   - Telescope picker adapter
   - Completion source adapter
   - Buffer/window navigation adapter
   - Notification adapter
   - File IO and watcher adapter
   - Parser adapters (frontmatter/markdown extraction)
2. Strict-cleanup pass completed to satisfy architecture checks:
   - Command orchestration for backlinks/search/template is delegated to use cases.
   - Adapter failure paths were normalized to structured domain/app errors.
3. Verification evidence is green:
   - Unit suite passes.
   - Adapter wiring integration tests pass.
   - E2E command smoke test passes.

---

## Phase 8: Public API and Config Schema

Goal: Finalize external contract for users.

Deliverables:
1. V2 setup API.
2. Config schema with validation rules.
3. Sensible defaults and strict invalid-input behavior.
4. Command set and user-facing docs.

Verification:
1. API contract tests pass.
2. Invalid config cases fail with clear messages.
3. Setup is deterministic and idempotent.

Status notes (March 2026):
1. Part 1 completed: setup API and config schema foundations.
   - setup now validates required config through app/config normalization.
   - setup is deterministic and idempotent for repeated calls with equal options.
   - plugin load no longer performs implicit setup; setup is explicit/user-driven.
2. Config schema baseline implemented with clear validation failures:
   - `vault_root` is required and must be absolute.
   - sensible defaults are applied for locale/log level/dataview/force-create key.
   - `new_notes_subdir` defaults deterministically when omitted.
3. Verification evidence is green:
   - New API/config unit specs pass.
   - Existing unit, integration, and e2e suites remain green.

---

## Phase 9: Hardening and Quality Gates

Goal: Ensure production-grade reliability.

Deliverables:
1. Performance checks:
   - Cold index
   - Incremental updates
   - Dataview execution on large vaults
2. Reliability checks:
   - Rename/delete/create watcher scenarios
   - Concurrent event bursts
3. Failure-mode tests:
   - Corrupt frontmatter
   - Broken links
   - Missing dependencies

Verification:
1. Quality gate checklist all green.
2. E2E critical workflows pass consistently.
3. No flaky tests accepted.

---

## Phase 10: Release Preparation

Goal: Prepare V2 as an independent release.

Deliverables:
1. Complete docs:
   - Architecture overview
   - API reference
   - Config guide
   - Troubleshooting
2. Release checklist.
3. Versioning and changelog policy for V2 onward.

Verification:
1. New contributor can understand architecture from docs alone.
2. Install/setup works from scratch with documented steps.
3. Release artifact validated in clean environment.
