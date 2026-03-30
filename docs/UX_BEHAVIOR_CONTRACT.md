# UX Behavior Contract

Version: 1.1
Status: Phase 0 Specification (Revised)
Date: March 28, 2026

This document defines observable command behavior, including create/open semantics, warnings, and picker behavior.
Document role: Canonical source for user-visible command behavior and notifications.
Policy authority: Product rules are canonical in docs/PRODUCT_CONTRACT.md.

---

## Command Behavior

### :ObsidianOmni
Purpose: Primary search/create workflow for notes.

Behavior:
1. Open Telescope picker scoped to vault index.
2. Searchable objects are queried in this order: title, aliases, relpath.
3. Matching is case-insensitive for discovery; exact/full matches are prioritized.
4. If selected candidate exists (exact/full match), open it.
5. If no exact/full match exists, create flow is available.
6. Force-create keybinding can create a new note from partial/no-match state.
7. Telescope default open actions are preserved (<CR>, splits, tab if mapped).
8. Creation routing:
   - If input matches journal classifier/title format, create in that journal type directory.
   - Otherwise create in standard new_notes_subdir.
9. Display policy:
   - Default is title -> relpath.
   - If alias matched and title did not match, display is matched_alias -> relpath.
   - Separator token is configurable (default ->).

Notes:
- No tag matching in omni.
- Omni is the primary end-user workflow; singular-responsibility create commands may still exist.

### :ObsidianToday
Purpose: Open or create today's daily note.

Behavior:
1. Resolve today's journal target.
2. Ensure note exists (create when missing).
3. Open note.
4. Apply configured default template if available for that note type.

### :ObsidianNext
Purpose: Open or create next journal note in current context.

Behavior:
1. Detect current note type (daily/weekly/monthly/yearly, else daily fallback).
2. Compute next target.
3. Ensure target note exists.
4. Open target note.

### :ObsidianPrev
Purpose: Open or create previous journal note in current context.

Behavior mirrors :ObsidianNext with previous target calculation.

### :ObsidianFollow
Purpose: Follow wikilink under cursor.

Behavior:
1. If cursor is not on a valid wikilink, no-op.
2. Parse link.
3. Resolve target note:
   - Use only link target (left side), never display alias.
   - Match is case-sensitive.
4. If target note missing but link is valid, create note and open it.
5. If note exists and heading/block exists, jump to it.
6. If note exists but heading/block missing, open note and warn.
7. If multiple canonical matches exist for the same target token (for example duplicate basename in different paths), show disambiguation picker.

### :ObsidianBacklinks
Purpose: Show notes linking to current note.

Behavior:
1. Gather current canonical title and aliases.
2. Search wikilinks referencing title OR aliases.
3. Show Telescope picker.
4. Open selection using Telescope default actions.

### :ObsidianSearch
Purpose: Vault-scoped text search (live grep).

Behavior:
1. Open Telescope live_grep with vault cwd.
2. Search raw text across markdown files.
3. Open selection using Telescope default actions.

### :ObsidianReindex
Purpose: Explicit full index rebuild.

Behavior:
1. Run full vault rescan.
2. Replace in-memory index atomically.
3. Notify completion or failure.

### :ObsidianInsertTemplate <type|path>
Purpose: Insert rendered template at cursor.

Behavior:
1. Resolve template by type name or file path (argument required).
2. Render using user-registered placeholders.
3. Insert at cursor location.

Rules:
- No template inheritance.
- No built-in placeholder set.

### :ObsidianRenderDataview
Purpose: Render dataview blocks in current buffer.

Behavior:
1. Detect dataview blocks.
2. Parse and execute TASK/TABLE queries.
3. Render query results as extmarks with virtual lines (non-mutating).
4. Respect configured placement/scope/patterns.

---

## Policy References

- Link safety behavior is specified in docs/PRODUCT_CONTRACT.md under Wiki Link Parsing and Resolution.
- Omni matching and creation policy is specified in docs/PRODUCT_CONTRACT.md under Omni Search/Create and Text Search.
- Case sensitivity and identity policy is specified in docs/PRODUCT_CONTRACT.md under Vault Management.
- Performance and responsiveness requirements are specified in docs/PRODUCT_CONTRACT.md under Performance Characteristics.

This contract captures how those rules appear to users through command behavior and notifications.

---

## Notification Standards

Levels:
- error: operation failed.
- warning: operation succeeded with degraded target behavior.
- info: optional operational updates.
- silent: normal open/create flows unless user config enables informational notices.

Messages must include:
1. Command context
2. Target context (title/path/anchor where relevant)
3. Suggested next step when possible

---

## Configurability Requirements

All major behaviors are configurable, including:
- Dataview render triggers and scope.
- Warning verbosity for follow-link missing anchors.
- Optional creation notices for omni/link-driven note creation.
- Template selection defaults by note type.

---

## Performance UX Requirement

Top-level requirement: no noticeable UI lag.

Operational UX implications:
- Heavy operations are async/non-blocking.
- Picker interactions remain responsive.
- Dataview rendering can be scoped to reduce cost.

---

Last Updated: March 28, 2026
