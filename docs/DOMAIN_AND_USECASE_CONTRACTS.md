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
