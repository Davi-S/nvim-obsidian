# nvim-obsidian V2: Product Contract

Version: 2.0
Status: Phase 0 Specification (Revised)
Date: March 28, 2026

Document role: Canonical source for product requirements and policy semantics.
Related documents:
- UX behavior contract: docs/UX_BEHAVIOR_CONTRACT.md
- Ownership map: docs/DOMAIN_OWNERSHIP_MAP.md
- Context and decisions: PROJECT_CONTEXT.md

---

## Overview

nvim-obsidian V2 is a Neovim plugin for local markdown vault workflows. It focuses on journal routing, wikilinks, templates, dataview rendering, and picker/completion integration.

The plugin provides no custom UI framework; it integrates with Neovim, Telescope, and nvim-cmp.

Reference vault for examples and testing context:
- ~/Documents/ObsidianAllInVault

---

## Core Value Proposition

Users can:
1. Route notes into daily/weekly/monthly/yearly journal directories.
2. Navigate with wikilinks and anchor/block targets.
3. Render templates through user-registered placeholders.
4. Use an omni picker to search by title/alias and create notes when missing.
5. Render dataview TASK/TABLE blocks inside buffers.
6. Complete wiki targets (titles, aliases, headings, block IDs) from nvim-cmp.

---

## Must-Have Feature Set (V2.0)

### 1. Vault Management
- [ ] Configure vault root as an absolute path.
- [ ] Scan vault asynchronously on startup.
- [ ] Watch filesystem events (create, modify, delete, rename).
- [ ] Maintain in-memory indexes by path, title, aliases.
- [ ] Provide manual reindex command for explicit rebuilds.
- [ ] Parse frontmatter robustly, including YAML list styles:
  - Inline lists: aliases: ["A", 'B', C]
  - Multiline lists:
    aliases:
      - A
      - "B"
      - 'C'
  - Mixed scalar quoting styles.
- [ ] Title identity is case-sensitive for canonical note identity.
- [ ] Search matching is case-insensitive for discoverability.

Case policy (final):
- Canonical identity: case-sensitive (Foo and foo are different notes when filesystem allows).
- Search and picker matching: case-insensitive.
- Wikilink target resolution is case-sensitive and uses only the link target (left side), never the display alias.

### 2. Journal System
- [ ] Classify dates into daily, weekly, monthly, yearly.
- [ ] Route input (today, +1d, Mon, 2026-03-28) into journal note types.
- [ ] Generate canonical titles via configured placeholders and formats.
- [ ] Time travel commands open or create notes:
  - :ObsidianToday
  - :ObsidianNext
  - :ObsidianPrev
- [ ] Journal layout requires one configured directory per note type (no flat mixed layout mode).
- [ ] Locale-aware date formatting.
- [ ] Journal placeholders must be registered explicitly before setup when journal is enabled.

### 3. Wiki Link Parsing and Resolution
- [ ] Parse wikilink syntax:
  - [[Title]]
  - [[Title|Alias]]
  - [[Title#Heading]]
  - [[Title#^blockid]]
  - [[#Heading]]
- [ ] Resolve targets by link target only (left side), ignoring display alias text.
- [ ] Command: :ObsidianFollow.
- [ ] Link safety behavior:
  - Valid link, target note missing: create note and open it.
  - Valid link, target note exists but heading/block missing: open note and warn.
  - Not a valid wikilink at cursor: do nothing.

Clarification on wikilink resolution and ambiguity:
- Display alias does not affect resolution. Example: [[Foo|Bar]] does not resolve to note Bar.
- Case is strict for link targets. Example: [[foo]] never resolves to note Foo.
- Ambiguity comes from multiple canonical matches for the same target string, typically by path/basename collisions.
- Example: if both vaultroot/bar/foo and vaultroot/baz/foo exist, [[foo]] is ambiguous.
- Ambiguity can be resolved by using a more specific target such as [[vaultroot/baz/foo]].

### 4. Backlinks
- [ ] Search notes that link to current note.
- [ ] Command: :ObsidianBacklinks.
- [ ] Matching is exact title OR any alias of the current note.

### 5. Omni Search/Create and Text Search
- [ ] Command: :ObsidianOmni is the primary picker workflow (search/create).
- [ ] Omni searchable objects are ordered as: title, aliases, relpath.
- [ ] Omni discovery uses fuzzy matching on all three searchable fields (title, aliases, relpath).
- [ ] Omni does not use tags for matching/ranking.
- [ ] If no exact/full match exists, omni allows note creation from partial/no matches.
- [ ] Omni supports force-create via dedicated keybinding even when partial candidates exist.
- [ ] If there is an exact/full match, create is not offered; selection opens existing note.
- [ ] Creation routing follows journal classifier first:
  - If input matches a journal title pattern, create in that journal type directory.
  - Otherwise create as a standard note in new_notes_subdir.
- [ ] Omni display policy:
  - Default display is title -> relpath.
  - If query matches alias and not title, display becomes matched_alias -> relpath.
  - Display separator (default ->) is configurable.
- [ ] Telescope default selection behavior is preserved (current window, horizontal split, vertical split, tab based on Telescope mappings).
- [ ] Command: :ObsidianSearch remains vault-scoped text search (live grep style), separate from omni.

### 6. Note Creation Workflow
- [ ] Note creation is primarily handled through :ObsidianOmni and link-follow creation behavior.

### 7. Template System
- [ ] Template placeholders are user-registered only.
- [ ] No fixed/default placeholders are provided by V2.
- [ ] Unknown placeholders behavior is configurable; default is non-crashing and visible to the user.
- [ ] Command: :ObsidianInsertTemplate [type|path]
  - Optional argument allows bypassing picker.
  - No argument opens picker.
- [ ] Template inheritance/includes are not supported in V2.0.

### 8. Dataview Integration
- [ ] Parse and execute TASK and TABLE dataview blocks.
- [ ] Render placement, trigger events, scope, patterns, and messages are configurable.
- [ ] Rendering is non-mutating: query text remains intact and results are shown via extmarks/virtual lines.
- [ ] Command: :ObsidianRenderDataview for explicit re-render.
- [ ] On-open/on-save hooks are configurable.
- [ ] Parse and execution errors are rendered clearly without crashing UI.

### 9. Completion (nvim-cmp)
- [ ] Register cmp source for wikilinks.
- [ ] Trigger on [[.
- [ ] Candidate groups include:
  - Note titles
  - Aliases
  - Headings with # prefix
  - Block IDs with #^ prefix
- [ ] Insert completion with correct wikilink structure.

### 10. Global Commands (V2.0)
- [ ] :ObsidianOmni
- [ ] :ObsidianToday
- [ ] :ObsidianNext
- [ ] :ObsidianPrev
- [ ] :ObsidianFollow
- [ ] :ObsidianBacklinks
- [ ] :ObsidianSearch
- [ ] :ObsidianReindex
- [ ] :ObsidianInsertTemplate [type|path]
- [ ] :ObsidianRenderDataview

---

## Non-Goals (Explicitly Out of Scope)

- [ ] Markdown preview UI.
- [ ] Markdown concealment.
- [ ] Syntax highlighting enhancements.
- [ ] Note encryption.
- [ ] Obsidian desktop sync.
- [ ] Publish/export workflows.
- [ ] Collaboration.
- [ ] Graph visualization.
- [ ] Obsidian plugin API compatibility.
- [ ] Template inheritance/includes.

---

## Data Integrity and Link Safety

### Index Consistency
- Indexes remain synchronized after each processed watcher event.
- Rename events update canonical paths and indexes correctly.
- Manual reindex provides deterministic recovery path when needed.

### Watcher Policy
- No periodic automatic reconciliation loop in V2.0 baseline.
- Primary source of truth for updates is watcher/event processing.
- Manual :ObsidianReindex remains available for explicit full rebuild.

### Link Safety
- Missing target note on valid link follow: create and open.
- Missing heading/block in existing note: open note and warn.
- Invalid/non-wikilink text at cursor: no action.
- Display alias in [[target|alias]] never participates in target resolution.

---

## Configuration Requirements

### Required/User-Configured
1. vault_root
2. journal.daily.subdir
3. journal.weekly.subdir
4. journal.monthly.subdir
5. journal.yearly.subdir
6. journal.*.title_format with user-registered placeholders

### Configurable Systems
- Dataview trigger events, scope, patterns, placement, messages, highlights
- Template source mapping by note type
- Search ranking weights (for omni)
- Omni display separator
- Follow-link missing heading/block warning behavior

### Sensible Defaults
Defaults should follow current V1 shipped defaults unless overridden by user config:
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

User profile example currently in use:
- vault_root: /home/davi/Documents/ObsidianAllInVault
- locale: pt-BR
- journal subdirs and formats from active V1 config

---

## Error Handling Semantics

| Scenario                               | Behavior                                              |
| -------------------------------------- | ----------------------------------------------------- |
| Vault directory missing                | Clear error, no crash                                 |
| Frontmatter malformed                  | Safe parse failure with warning and fallback metadata |
| Wikilink target note missing           | Create note and open                                  |
| Heading/block missing in existing note | Open note and warn                                    |
| Ambiguous target token                 | Show disambiguation picker                            |
| Invalid text (not wikilink) for follow | No-op                                                 |

---

## Performance Characteristics

Top priority: no perceptible UI lag.

Operational targets:
- Initial index build on 1000 notes: as fast as practical, with async/non-blocking behavior.
- Event processing should avoid blocking UI thread.
- Omni picker interaction should remain responsive under large vaults.
- Dataview rendering should be bounded and configurable in scope.

Non-blocking UX is prioritized over aggressive background processing.

---

## Compatibility and Naming

- V2 has no backward compatibility requirement with V1 configuration.
- V1 and V2 are not intended to be enabled simultaneously.
- Command naming is chosen for the best standalone V2 UX (not coexistence constraints).

---

## Feature Parity with V1

V2.0 keeps all core V1 user-visible workflows:
- Journal routing and time travel.
- Omni search/create.
- Wikilink follow and backlinks.
- Vault text search.
- Template insertion with registered placeholders.
- Dataview TASK/TABLE rendering.
- cmp completion for titles, aliases, headings, block IDs.

---

## Success Criteria for V2.0

- [ ] Must-have features implemented and tested.
- [ ] Critical E2E workflows pass.
- [ ] UI remains responsive during scanning, watching, rendering.
- [ ] Errors are actionable and non-crashing.
- [ ] Config is validated with clear diagnostics.

---

Contract Status: Revised per clarification pass
Last Updated: March 28, 2026
