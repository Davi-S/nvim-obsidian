# nvim-obsidian V2: Complete Project Context

Created: March 28, 2026
Status: Phase 0 complete (revised after clarification pass)
Architecture: Domain-Driven Design with Clean Architecture layering
Timeline: quality-prioritized

---

## Executive Summary

This is a greenfield rewrite of nvim-obsidian focused on clean boundaries and full core workflow parity with V1.

Revised clarification highlights:
- Primary note entry flow is :ObsidianOmni (search/create).
- Time travel commands (:ObsidianToday/:ObsidianNext/:ObsidianPrev) all open or create.
- No periodic automatic reconciliation loop in V2.0 baseline.
- Placeholder model is explicit registration (no built-in placeholder set).
- Journal layout requires one directory per note type.
- Template inheritance is out of scope.
- V1 and V2 are not intended to be enabled together.
- Wikilink resolution is case-sensitive and uses only the link target (left side); display alias does not resolve targets.
- Omni searchable corpus is ordered title, aliases, relpath.
- Omni supports force-create for partial/no-match states; full matches only open existing notes.
- Omni creation routing is journal-classifier-first, else standard new_notes_subdir.
- Omni display follows v1 policy with configurable separator token (default ->).

Reference vault for examples:
- /home/davi/Documents/ObsidianAllInVault

---

## Section 1: V1 Findings Carried Forward

- V1 has feature completeness and useful command workflows.
- V1 has coupling issues from singleton-heavy composition.
- V1 patterns to preserve:
  - Omni search/create experience.
  - Explicit placeholder registration philosophy.
  - Journal per-type subdir model.
  - Dataview configurability.

---

## Section 2: Revised Product Decisions

### Command Model
Kept in V2.0:
- :ObsidianOmni
- :ObsidianToday
- :ObsidianNext
- :ObsidianPrev
- :ObsidianFollow
- :ObsidianBacklinks
- :ObsidianSearch
- :ObsidianReindex
- :ObsidianInsertTemplate [type|path]
- :ObsidianRenderDataview

Not part of primary V2.0 end-user workflow:
- :ObsidianYesterday
- :ObsidianTomorrow
- :ObsidianNew (not part of primary user workflow)
- :ObsidianNewFromTemplate (not part of primary user workflow)

### Case Sensitivity Policy
- Canonical identity is case-sensitive.
- Search and completion matching are case-insensitive.
- Resolution order:
  1. wikilink resolution uses case-sensitive match against the link target token only
  2. display alias in [[target|alias]] is ignored for resolution
  3. ambiguity only when multiple canonical targets match the same token (for example duplicated basename in different paths)

### Link Safety Policy
- Valid link + missing note: create and open.
- Valid link + missing heading/block: open note and warn.
- Invalid/non-wikilink text under cursor: no-op.

### Sync Policy
- Watchers/events are primary update mechanism.
- No periodic auto reconciliation loop in V2.0 baseline.
- Manual :ObsidianReindex is explicit recovery/rebuild path.

### Template Policy
- User-registered placeholders only.
- No fixed/default placeholder set.
- No template inheritance/includes in V2.0.

### Omni Creation Policy
- Full match: open existing note (no create action).
- Partial/no match: create path available.
- Force-create keybinding supported for partial/no match states.
- Search corpus order: title, aliases, relpath (all use fuzzy matching).
- Create routing: journal classifier first, else standard new_notes_subdir.
- Display: title -> relpath, or matched_alias -> relpath when alias-only hit.
- Display separator is configurable (default ->).

### Journal Layout Policy
- Daily/weekly/monthly/yearly each have dedicated configured subdir.
- No flat mixed-layout mode.

---

## Section 3: Domain Boundaries

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

## Section 4: Defaults and Config Alignment

Shipped defaults should align with V1 current defaults unless user overrides:
- locale: en-US
- new_notes_subdir: vault_root
- force_create_key: <S-CR>
- dataview.enabled: true
- dataview.render.when: on_open, on_save
- dataview.render.scope: event
- dataview.render.patterns: *.md
- dataview.placement: below_block
- dataview.messages.task_no_results.enabled: true
- dataview.messages.task_no_results.text: Dataview: No results to show for task query.

Current user profile example:
- vault_root: /home/davi/Documents/ObsidianAllInVault
- locale: pt-BR
- journal directories and title formats from active user config

---

## Section 5: Clarification on Ambiguous Wikilinks

Ambiguous target means multiple canonical notes match the same case-sensitive target token.

Example:
- Both vaultroot/bar/foo and vaultroot/baz/foo exist.
- Link [[foo]] is ambiguous.
- System prompts disambiguation; user can use [[vaultroot/baz/foo]] to disambiguate.

---

## Section 6: Performance Priority

Top priority: no UI lag.

Implications:
- expensive work async/non-blocking
- picker remains responsive
- dataview triggers and scope are configurable
- explicit user control via command-driven full reindex

---

## Section 7: Architecture and Testing Plan

The 10-phase implementation plan remains valid structurally, with revised Phase 0 assumptions reflected in docs:
- docs/PRODUCT_CONTRACT.md
- docs/DOMAIN_OWNERSHIP_MAP.md
- docs/UX_BEHAVIOR_CONTRACT.md

Next milestone remains Phase 1 ADR authoring.

---

## Section 8: Decision Log Updates

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

Document Status: Updated after user clarification pass
Last Updated: March 28, 2026
