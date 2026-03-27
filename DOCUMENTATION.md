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
- new_notes_subdir: 10 Novas notas
- force_create_key: <S-CR> (standard Telescope force-create key)
- journal subdirs:
  - 11 Diario/11.01 Diario
  - 11 Diario/11.02 Semanal
  - 11 Diario/11.03 Mensal
  - 11 Diario/11.04 Anual

## 4.1 API Quick Reference

```lua
local obsidian = require("nvim-obsidian")

-- Template engine (note body templates)
obsidian.template_register_placeholder("title", function(ctx)
  return ctx.note.title
end)

-- Journal title formats (render + parse)
obsidian.journal.register_placeholder("year", function(ctx)
  return tostring(ctx.date.year)
end, "(%d%d%d%d)")
```

## 5. Configuration Reference

Main setup fields:

- vault_root: absolute path to vault
- locale: localization code (default: "en-US")
- new_notes_subdir: directory where new standard notes are created (default: "10 Novas notas")
- force_create_key: telescope omni force-create key (default: "<S-CR>")
- templates: template configuration for note creation
  - standard: template file or string for standard notes
- journal: configuration for journal note types (daily/weekly/monthly/yearly)
  - Each journal type has the same structure:
    ```lua
    journal = {
      daily = {
        subdir = "path/to/daily",           -- where daily notes are stored
        title_format = "{{year}} {{month_name}}", -- how to format daily note titles
        template = "path/to/template",      -- optional: template for daily notes
      },
      weekly = { subdir = "...", title_format = "...", template = "..." },
      monthly = { subdir = "...", title_format = "...", template = "..." },
      yearly = { subdir = "...", title_format = "...", template = "..." },
    }
    ```

- dataview: configuration for dataview rendering behavior
  - enabled: boolean, enable/disable dataview rendering globally (default: true)
  - render.when: list of trigger options (default: { "on_open", "on_save" })
    - on_open -> BufReadPost
    - on_save -> BufWritePost
    - on_buf_enter -> BufEnter
  - render.scope: which buffers to refresh per event (default: "event")
    - event: only the event buffer (`args.buf`)
    - current: only current buffer
    - visible: all visible-window markdown buffers
    - loaded: all loaded markdown buffers
  - render.patterns: autocmd pattern list (default: { "*.md" })
  - placement: where virtual output is rendered (`below_block` or `above_block`, default: `below_block`)
  - messages.task_no_results:
    - enabled: boolean (default: true)
    - text: message for valid TASK query with zero rows
  - highlights (optional group-name overrides):
    - header
    - error
    - table_link
    - task_no_results

Example configuration:

```lua
require("nvim-obsidian").setup({
  vault_root = "/path/to/vault",
  locale = "pt-BR",
  new_notes_subdir = "10 Notas",
  dataview = {
    enabled = true,
    render = {
      when = { "on_open", "on_save" },
      scope = "event",
      patterns = { "*.md" },
    },
    placement = "below_block",
    messages = {
      task_no_results = {
        enabled = true,
        text = "Dataview: No results to show for task query.",
      },
    },
    highlights = {
      -- optional overrides by highlight-group name
      -- header = "markdownLinkText",
      -- error = "WarningMsg",
      -- table_link = "markdownLinkText",
      -- task_no_results = "Comment",
    },
  },
  journal = {
    daily = {
      subdir = "11 Diario/11.01 Diario",
      title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
      template = "08 Templates/Nota diaria",
    },
    weekly = {
      subdir = "11 Diario/11.02 Semanal",
      title_format = "{{iso_year}} semana {{iso_week}}",
    },
    monthly = {
      subdir = "11 Diario/11.03 Mensal",
      title_format = "{{year}} {{month_name}}",
    },
    yearly = {
      subdir = "11 Diario/11.04 Anual",
      title_format = "{{year}}",
    },
  },
  templates = {
    standard = "08 Templates/Nova nota",
  },
})
```

Minimal example (save-only, current-buffer rendering):

```lua
require("nvim-obsidian").setup({
  vault_root = "/path/to/vault",
  dataview = {
    render = {
      when = { "on_save" },
      scope = "current",
      patterns = { "*.md" },
    },
  },
})
```

Journal placeholders are explicitly registered and are separate from template placeholders.

```lua
local obsidian = require("nvim-obsidian")

obsidian.journal.register_placeholder("year", function(ctx)
  return tostring(ctx.date.year)
end, "(%d%d%d%d)")

obsidian.journal.register_placeholder("iso_year", function(ctx)
  return tostring(ctx.date.iso_year)
end, "(%d%d%d%d)")

obsidian.journal.register_placeholder("month_name", function(ctx)
  return ctx.locale.month_name or ""
end, "(.+)")

obsidian.journal.register_placeholder("day2", function(ctx)
  return string.format("%02d", ctx.date.day or 0)
end, "(%d%d?)")

obsidian.journal.register_placeholder("weekday_name", function(ctx)
  return ctx.locale.weekday_name or ""
end, "(.+)")

obsidian.journal.register_placeholder("iso_week", function(ctx)
  return tostring(ctx.date.iso_week)
end, "(%d%d?)")
```

The second argument is a resolver function and the third argument is the Lua regex capture fragment used for parsing.

- month_names: map 1..12 -> localized month names
- weekday_names: map 1..7 -> localized weekday names

Template system is fully configurable via optional placeholder registration. See section 6.2 for details.

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
  - Vault-scoped text search (Telescope `live_grep` with `cwd = vault_root`).
- :ObsidianReindex
  - Forces full cache rebuild.
- :ObsidianInsertTemplate [type|path]
  - Inserts rendered template at cursor.
  - Optional argument can be a note type (standard/daily/weekly/monthly/yearly) or a file path.

## 6.2 Template System

The plugin includes a flexible template system with user-configurable placeholders.

**Placeholder Syntax:**
- Templates use `{{placeholder_name}}` syntax.
- Unknown placeholders are left unchanged in the output (with a warning).
- No built-in placeholders—all must be registered by the user.

**Registering Placeholders:**

Call `template_register_placeholder(name, resolver_fn)` during setup:

```lua
require("nvim-obsidian").setup({
  vault_root = "/path/to/vault",
  -- ... other config
})

-- Register custom placeholders
require("nvim-obsidian").template_register_placeholder("title", function(ctx)
  return ctx.note.title
end)

require("nvim-obsidian").template_register_placeholder("date", function(ctx)
  return ctx.time.format_local("%Y-%m-%d")
end)

require("nvim-obsidian").template_register_placeholder("weekday", function(ctx)
  return ctx.time.format_local("%A")
end)
```

**Placeholder Context:**

Each resolver function receives a context object with:

- `ctx.note.title` - the note title
- `ctx.note.type` - note type (standard/daily/weekly/monthly/yearly)
- `ctx.note.input` - original user input
- `ctx.note.rel_path` - vault-relative path
- `ctx.note.aliases` - array of note aliases
- `ctx.note.tags` - array of note tags
- `ctx.note.abs_path` - absolute file path
- `ctx.time.timestamp` - unix timestamp
- `ctx.time.local` - local date table {year, month, day, hour, min, sec, wday, yday}
- `ctx.time.utc` - UTC date table
- `ctx.time.iso` - ISO object {date, datetime, week, year}
- `ctx.time.format_local(fmt)` - local-time format function for date formatting
- `ctx.time.format_utc(fmt)` - UTC format function for date formatting
- `ctx.config` - read-only config object (attempting writes raises an error)

**Using Templates:**

Templates are injected when creating notes via `:ObsidianOmni` based on note type.

To insert a template manually at cursor:

```vim
:ObsidianInsertTemplate                  " Uses note type from current buffer
:ObsidianInsertTemplate standard         " Uses 'standard' note template
:ObsidianInsertTemplate ./my-template.md " Loads template from file
```

## 6.3 Template Examples

**Basic Setup with Common Placeholders:**

```lua
require("nvim-obsidian").setup({
  vault_root = "/home/user/Obsidian Vault",
  new_notes_subdir = "10 Notas",
  templates = {
    standard = "# {{title}}\n\nDate: {{date}}\n",
    daily = "# Daily: {{date}}\n\n## Tasks\n\n## Notes\n",
  },
})

-- Register common placeholders
require("nvim-obsidian").template_register_placeholder("title", function(ctx)
  return ctx.note.title
end)

require("nvim-obsidian").template_register_placeholder("date", function(ctx)
  return ctx.time.format_local("%Y-%m-%d")
end)

require("nvim-obsidian").template_register_placeholder("time", function(ctx)
  return ctx.time.format_local("%H:%M")
end)

require("nvim-obsidian").template_register_placeholder("weekday", function(ctx)
  return ctx.time.format_local("%A")
end)

require("nvim-obsidian").template_register_placeholder("iso_date", function(ctx)
  return string.format("%04d-%02d-%02d", 
    ctx.time.iso.year, ctx.time.iso.month, ctx.time.iso.day)
end)

require("nvim-obsidian").template_register_placeholder("note_type", function(ctx)
  return ctx.note.type
end)
```

With these placeholders registered, templates like:

```markdown
# {{title}}

Created: {{date}} at {{time}} ({{weekday}})
Type: {{note_type}}

---

## Content

Add your content here.
```

Will render to:

```markdown
# My Note

Created: 2026-03-25 at 14:30 (Wednesday)
Type: standard

---

## Content

Add your content here.
```

**Advanced Placeholder Examples:**

```lua
-- Extract year for archival paths
require("nvim-obsidian").template_register_placeholder("year", function(ctx)
  return tostring(ctx.time.iso.year)
end)

-- Access vault path
require("nvim-obsidian").template_register_placeholder("vault_name", function(ctx)
  local parts = vim.fn.split(ctx.config.vault_root, "/")
  return parts[#parts]
end)

-- Computed field based on note type
require("nvim-obsidian").template_register_placeholder("template_label", function(ctx)
  if ctx.note.type == "daily" then
    return "Daily Journal Entry"
  elseif ctx.note.type == "weekly" then
    return "Weekly Retrospective"
  else
    return "Note"
  end
end)

-- Month name from locale config
require("nvim-obsidian").template_register_placeholder("month_name", function(ctx)
  local months = ctx.config.month_names or {}
  local month = ctx.time.iso.month
  return months[month] or tostring(month)
end)

-- ISO format with custom separator
require("nvim-obsidian").template_register_placeholder("date_iso", function(ctx)
  return ctx.time.format_local("%Y%m%d")
end)
```

**Using File Path Arguments:**

Create reusable template files in your vault and reference them explicitly:

```vim
" Use a custom template file
:ObsidianInsertTemplate ./templates/meeting_notes.md

" Or with absolute path
:ObsidianInsertTemplate /home/user/Obsidian\ Vault/templates/research.md
```

Template files work the same way as configured templates—placeholders are still resolved.

## 7. Workflows

### 7.1 Omni Picker

Omni picker supports both discovery and creation:

- existing match: opens note
- no match: routes input through journal classifier
- journal match: creates in corresponding journal folder
- non-journal match: creates in new_notes_subdir

Force create:

- Configurable action key in picker, default <S-CR>.
- Useful when input matches alias/title but user still wants a new note.

Search and display policy:

- Searchable objects are explicit and ordered: title, aliases, relpath.
- Path search support enables folder-driven discovery when title/alias are
  unknown.
- Display defaults to `title -> relpath`.
- Display switches to `matched_alias -> relpath` only when query matches alias
  and does not match title.

Implementation note:

- Policy and matching logic are centralized in Omni helper functions so behavior
  is deterministic and easier to extend.

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
- external filesystem watcher (best effort)
- manual full rebuild via :ObsidianReindex

### 8.5 External Filesystem Watchers

Best-effort recursive directory watchers are started for the vault.

Behavior:

- external markdown create/update -> refresh single note
- external rename/delete -> remove stale path and watcher-driven reconciliation
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

Focused unit/spec tests exist in:

- tests/spec/router_spec.lua
- tests/spec/frontmatter_spec.lua
- tests/spec/vault_spec.lua
- tests/spec/omni_spec.lua

What it validates:

- command registration
- daily create/open
- next/prev journal navigation
- cache indexing
- wiki-link follow
- cmp source completion payload
- external file create/rename/delete synchronization

What the Omni spec validates:

- title/alias/path search ordering semantics
- alias-first display override rule
- path-in-ordinal behavior with relpath last (lower priority)

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
