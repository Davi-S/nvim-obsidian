# nvim-obsidian Documentation

## 1. Overview

nvim-obsidian is a configurable Neovim plugin that reproduces the core workflow of working with an Obsidian-style vault directly in Neovim.

Design goals:

- Keep behavior config-first and deterministic.
- Treat directory structure as the source of truth for note type.
- Keep operations fast with in-memory cache and async synchronization.
- Integrate with Telescope and nvim-cmp for note navigation and creation.
- Avoid visual markdown concealment and avoid formatting responsibilities.

Out of scope:

- No markdown concealment.
- No markdown formatting.

## 2. Core Concepts

### 2.1 Vault Root

All plugin operations are scoped to a configured absolute vault path.

This includes:

- scan and cache population
- search and backlinks
- note creation and routing
- link resolution

### 2.2 Directory is Truth

A note type is determined exclusively by its directory path.

- daily note directory -> note is daily
- weekly note directory -> note is weekly
- monthly note directory -> note is monthly
- yearly note directory -> note is yearly
- any other folder -> standard note

No note-type state is derived from note content.

### 2.3 Journal Naming Patterns

Current routing/classification logic supports:

- Daily: YYYY month DD, weekday
- Weekly: YYYY semana WW
- Monthly: YYYY month
- Yearly: YYYY

When input does not match journal patterns, it is treated as a standard note title.

## 3. Dependencies

Hard dependencies:

- nvim-lua/plenary.nvim
- nvim-telescope/telescope.nvim
- hrsh7th/nvim-cmp
- nvim-treesitter/nvim-treesitter

## 4. Installation and Setup

Plugin can be loaded as a local plugin from your Neovim config.

Example lazy.nvim spec (local plugin):

- dir: ~/Documents/nvim-obsidian
- name: nvim-obsidian
- dependencies: the four hard dependencies listed above
- cmd: Obsidian* command set (for lazy command triggers)

The plugin setup requires at least:

- vault_root (absolute path)

Current defaults include:

- locale: pt-BR
- notes_subdir: 10 Novas notas
- force_create_key: <S-CR>
- journal subdirs:
  - 11 Diario/11.01 Diario
  - 11 Diario/11.02 Semanal
  - 11 Diario/11.03 Mensal
  - 11 Diario/11.04 Anual

## 5. Configuration Reference

Main setup fields:

- vault_root: absolute path to vault
- locale: localization code
- notes_subdir: standard note target folder
- force_create_key: telescope omni force-create mapping
- journal:
  - daily.subdir
  - weekly.subdir
  - monthly.subdir
  - yearly.subdir
- templates:
  - standard
  - daily
  - weekly
  - monthly
  - yearly
- month_names: map 1..12 -> localized month names
- weekday_names: map 1..7 -> localized weekday names

Template placeholders currently supported:

- {{title}}
- {{date}}

## 6. Commands

Global commands provided by the plugin:

- :ObsidianOmni
  - Opens omni picker for search/open/create.
- :ObsidianToday
  - Opens or creates today daily note.
- :ObsidianNext
  - Opens or creates next journal note based on context.
- :ObsidianPrev
  - Opens or creates previous journal note based on context.
- :ObsidianFollow
  - Follows wiki-link target under cursor.
- :ObsidianBacklinks
  - Finds usages of current note title across vault.
- :ObsidianSearch
  - Vault-scoped text search.
- :ObsidianReindex
  - Forces full cache rebuild.

## 7. Workflows

### 7.1 Omni Picker

Omni picker supports both discovery and creation:

- existing match: opens note
- no match: routes input through journal classifier
- journal match: creates in corresponding journal folder
- non-journal match: creates in notes_subdir

Force create:

- Configurable action key in picker, default <S-CR>.
- Useful when input matches alias/title but user still wants a new note.

### 7.2 Journal Navigation

Context-aware relative navigation:

- inside daily note -> +/- 1 day
- inside weekly note -> +/- 1 week
- inside monthly note -> +/- 1 month
- inside yearly note -> +/- 1 year

Fallback behavior:

- if buffer is not a recognized journal note, daily context anchored to current time is used.

### 7.3 Wiki-Link Navigation

Supported forms:

- [[Note Title]]
- [[Note Title|Alias]]

Resolution strategy:

- exact title match
- alias match
- explicit vault-relative path disambiguation when duplicates exist
- vault-root filename preference when applicable

### 7.4 Backlinks Search

Backlinks command searches for references to the current note title using vault-scoped grep patterns that capture both:

- [[Title]]
- [[Title|

## 8. Cache and Synchronization

### 8.1 In-Memory Model

The plugin keeps note metadata in memory:

- path
- title
- aliases
- tags
- note type
- vault-relative path

Indexes maintained:

- title index
- alias index

### 8.2 Startup Scan

At setup, the plugin performs async cache population from all markdown files under vault_root.

### 8.3 Frontmatter Parsing Pipeline

Current hardening uses strict Tree-sitter-based root metadata isolation:

- parse markdown AST
- only accept first root node as minus_metadata at file start
- extract YAML payload from root metadata block
- decode YAML and normalize aliases/tags to arrays

Only root YAML frontmatter is parsed.

### 8.4 Sync Triggers

Cache sync currently uses:

- buffer write/new/filepost events
- rename-aware old path removal via file pre/post hooks
- buffer delete removal
- focus-gained debounced reconciliation
- external filesystem watcher (best effort)
- manual full rebuild via :ObsidianReindex

### 8.5 External Filesystem Watchers

Best-effort recursive directory watchers are started for the vault.

Behavior:

- external markdown create/update -> refresh single note
- external rename/delete -> remove stale path and reconcile
- directory topology changes -> watcher restart debounce
- cleanup on VimLeavePre

## 9. Completion Integration

The plugin registers a dedicated cmp source:

- source name: nvim_obsidian
- trigger context: markdown buffer inside vault and wiki-link typing context
- completion items include:
  - note title insertion
  - note title plus alias insertion

Inserted forms are generated as wiki-link payload endings.

## 10. Current Architecture Map

Top-level modules:

- lua/nvim-obsidian/init.lua
- lua/nvim-obsidian/config.lua
- lua/nvim-obsidian/path.lua
- lua/nvim-obsidian/commands.lua

Data and cache:

- lua/nvim-obsidian/model/note.lua
- lua/nvim-obsidian/model/vault.lua
- lua/nvim-obsidian/cache/scanner.lua
- lua/nvim-obsidian/parser/frontmatter.lua

Workflow modules:

- lua/nvim-obsidian/picker/omni.lua
- lua/nvim-obsidian/journal/router.lua
- lua/nvim-obsidian/journal/format.lua
- lua/nvim-obsidian/journal/time_travel.lua
- lua/nvim-obsidian/link/wiki.lua
- lua/nvim-obsidian/backlinks.lua
- lua/nvim-obsidian/cmp/source.lua

## 11. Testing

An automated headless E2E smoke script exists:

- tests/e2e_smoke.lua

What it validates:

- command registration
- daily create/open
- next/prev journal navigation
- cache indexing
- wiki-link follow
- cmp source completion payload
- external file create/rename/delete synchronization

How to run:

nvim --headless -u NONE "+lua dofile('tests/e2e_smoke.lua')" "+qall"

Expected terminal output includes:

- E2E smoke passed
- exit code 0

## 12. Known Limitations

- Interactive Telescope UI flows cannot be fully validated in pure headless mode.
- Filesystem watcher behavior depends on platform filesystem event semantics and remains best effort.
- Static diagnostics may show Undefined global vim outside Neovim runtime; runtime behavior is authoritative for plugin execution.

## 13. Operational Troubleshooting

If commands are missing:

- verify plugin spec includes cmd trigger list for Obsidian commands
- run Neovim and check :echo exists(':ObsidianToday')

If cache seems stale:

- run :ObsidianReindex
- verify vault_root path exists and is absolute

If link resolution is ambiguous:

- use vault-relative target path for disambiguation

If cmp source does not appear:

- ensure plugin has been loaded (run any Obsidian command)
- confirm cmp source list contains nvim_obsidian

## 14. Suggested Next Enhancements

- Extend template placeholder system (custom user placeholders).
- Add optional explicit command for path-qualified note creation.
- Add richer duplicate disambiguation picker fallback.
- Add structured test harness for interactive Telescope behavior.
- Add optional periodic low-frequency background reconcile for very large vaults.
