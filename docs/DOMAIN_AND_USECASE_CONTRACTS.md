# Phase 3 Contracts Reference

This document indexes Phase 3 contract artifacts.

## Shared primitives

- lua/nvim_obsidian/core/shared/primitives.lua
- lua/nvim_obsidian/core/shared/errors.lua

## Domain contracts

- lua/nvim_obsidian/core/domains/vault_catalog/contract.lua
- lua/nvim_obsidian/core/domains/journal/contract.lua
- lua/nvim_obsidian/core/domains/wiki_link/contract.lua
- lua/nvim_obsidian/core/domains/template/contract.lua
- lua/nvim_obsidian/core/domains/dataview/contract.lua
- lua/nvim_obsidian/core/domains/search_ranking/contract.lua

## Use-case contracts

- lua/nvim_obsidian/use_cases/ensure_open_note.lua
- lua/nvim_obsidian/use_cases/follow_link.lua
- lua/nvim_obsidian/use_cases/reindex_sync.lua
- lua/nvim_obsidian/use_cases/render_query_blocks.lua
- lua/nvim_obsidian/use_cases/search_open_create.lua

## Contract policy

- These files define interface and shape contracts only.
- Business implementations are deferred to later phases.

## Phase 5 Domain Invariants

This section captures the runtime invariants introduced by Phase 5 domain implementations.

### Journal

- Classification output is deterministic: one of `daily|weekly|monthly|yearly|none`.
- Title generation is canonical by kind:
	- daily: `YYYY-MM-DD`
	- weekly: `YYYY-Www` (ISO week)
	- monthly: `YYYY-MM`
	- yearly: `YYYY`
- Adjacent date computation is deterministic for `next|prev|current`.

### Template

- Placeholder registration accepts only `table<string, function>`.
- Rendering is deterministic for the same `content + context + registry`.
- Unknown or failing placeholder resolvers remain unresolved and are reported once per name.

### Search Ranking

- Candidate ranking precedence is deterministic and stable.
- Tie-breaking is deterministic (alphabetical title, then relpath).
- Display label policy is deterministic for alias-vs-title selection.

### Wiki Link

- Cursor parsing returns target only when cursor is inside a wikilink span.
- Resolution uses target token semantics (display alias is non-resolving).
- Resolution status is always one of `resolved|missing|ambiguous`.
- Ambiguous matches are deterministically sorted by normalized path.

### Vault Catalog

- Path is canonical identity for upsert/replace/remove.
- `find_by_title_or_alias` applies case-sensitive exact matching first, then case-insensitive fallback.
- Match ordering is deterministic (normalized path order).

### Dataview

- Only supported query kinds in Phase 5 are `TASK` and `TABLE WITHOUT ID`.
- Block parsing is deterministic and fails fast on malformed query clauses.
- Query execution output shape is deterministic (`task|table`, `rows`, `rendered_lines`).
- `FROM` filtering is deterministic for path and tag forms (`FROM "path"`, `FROM #tag`).

## Phase 5 Domain Error Semantics

Error codes are centralized in `lua/nvim_obsidian/core/shared/errors.lua` and used consistently in domain implementations.

- `invalid_input`:
	- Invalid argument shapes or types.
	- Seen in Template, Wiki Link, Vault Catalog, Dataview.
- `not_found`:
	- Missing canonical identity on removal.
	- Seen in Vault Catalog `remove_note`.
- `parse_failure`:
	- Malformed Dataview blocks/clauses or unsupported query kinds.
	- Seen in Dataview parsing/execution boundaries.

Semantics contract:

- Domain functions return structured error objects (`code`, `message`, optional `meta`) instead of raising runtime exceptions for expected failures.
- Deterministic non-error outcomes use canonical status/result fields defined by each domain contract.

## Phase 6 Use-Case Invariants

This section captures orchestration invariants introduced by Phase 6 use-case implementations.

### Ensure/Open Note

- Title/token validation is enforced before any catalog or filesystem interaction.
- Single match opens existing note; multiple matches return `ambiguous_target` (error-code based).
- Missing note honors `create_if_missing`; disabled creation returns `not_found`.
- Journal origin uses journal-aware pathing behavior; non-journal origin uses default note pathing.

### Follow Link

- Cursor-not-on-link is a no-op success with `invalid` status (non-crashing behavior).
- Resolution status is deterministic: `resolved|missing|ambiguous` from wiki link domain.
- Missing targets delegate to `ensure_open_note` with create enabled and `origin = "link"`.
- Ambiguous targets require disambiguation picker support; cancel preserves `ambiguous` status.
- Heading/block anchors degrade to `missing_anchor` with warning when unresolved.

### Reindex/Sync

- Full reindex (`startup|manual`) rebuilds note set then atomically swaps catalog state.
- Atomic full reindex requires replacement hook; missing hook is `internal` error.
- Incremental sync (`event`) supports `create|modify|delete|rename` with deterministic stats.
- Startup mode starts watcher only after successful full rebuild.

### Render Query Blocks

- Trigger gating is explicit and deterministic (`on_save|manual`).
- Parse/execute/render pipeline continues across blocks while capturing per-block execution errors.
- Patch application failure returns `internal`; parse warnings may still render valid blocks.

### Search/Open/Create

- Picker action drives deterministic outcome: `cancelled|opened|created`.
- Create is forbidden when exact/full title match exists unless explicit force behavior is allowed.
- Omni create path classifies query for journal intent and forwards origin accordingly.
- All open/create actions delegate to `ensure_open_note` rather than duplicating note logic.

## Phase 6 Use-Case Error Semantics

- `invalid_input`:
	- Missing required ports or malformed input payloads.
	- Invalid mode/trigger/event kinds.
- `not_found`:
	- Creation disabled while target does not exist.
- `ambiguous_target`:
	- Multiple candidate note matches for ensure/open behavior.
- `internal`:
	- Filesystem/write/open failures, atomic replacement failures, or missing required runtime hooks.

Use-case semantics contract:

- Use cases normalize failures into structured domain errors and avoid leaking adapter-specific exceptions.
- Use cases orchestrate domain behavior and ports only; domain/business rules remain outside adapters.
