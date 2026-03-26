# nvim-obsidian

Config-first Obsidian workflow plugin for Neovim.

## Current status

Initial implementation slice completed:

- strict setup configuration with absolute vault root
- directory-based note type resolution (Directory is Truth)
- in-memory vault cache with markdown/frontmatter scan
- cache reconciliation on focus gain + rename-aware sync for buffer path changes
- external filesystem watcher (best effort) for out-of-editor file create/update/delete
- Omni picker for open/create using Telescope
- smart routing for daily/weekly/monthly/yearly/standard notes
- template injection with placeholders
- journal time travel (next/previous) and open today
- wiki-link follow command (`[[Title]]` and `[[Title|Alias]]`)
- backlinks command and vault-scoped text search
- nvim-cmp source for `[[` wiki-link completion

## Scope exclusions

This plugin does not do markdown visual concealment and does not do formatting.

## Dependencies (hard)

- nvim-lua/plenary.nvim
- nvim-telescope/telescope.nvim
- hrsh7th/nvim-cmp
- nvim-treesitter/nvim-treesitter

## Runtime entry

This repository now includes a standard Neovim runtime entrypoint:

- `plugin/nvim-obsidian.lua`

This allows conventional plugin loading and optional global auto-setup via:

```lua
vim.g.nvim_obsidian_opts = {
  vault_root = "/abs/path/to/vault",
}
```

## Basic setup

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

obsidian.setup({
  vault_root = "/home/davi/Documents/ObsidianAllInVault",
  locale = "pt-BR",
  new_notes_subdir = "10 Novas notas",
  journal = {
    daily = {
      subdir = "11 Diário/11.01 Diário",
      title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
    },
    weekly = {
      subdir = "11 Diário/11.02 Semanal",
      title_format = "{{iso_year}} semana {{iso_week}}",
    },
    monthly = {
      subdir = "11 Diário/11.03 Mensal",
      title_format = "{{year}} {{month_name}}",
    },
    yearly = {
      subdir = "11 Diário/11.04 Anual",
      title_format = "{{year}}",
    },
  },
})
```

Journal placeholders are separate from template placeholders and must be
registered before `setup()` when journal is enabled.

## API Quick Reference

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

## Commands

- `:ObsidianOmni`
- `:ObsidianToday`
- `:ObsidianNext`
- `:ObsidianPrev`
- `:ObsidianFollow`
- `:ObsidianBacklinks`
- `:ObsidianSearch` (Telescope `live_grep` scoped to `vault_root`)
- `:ObsidianReindex`
- `:ObsidianInsertTemplate [type|path]`

## Omni behavior

Omni search uses an explicit search/display policy:

- search objects (priority order): `title`, `aliases`, `relpath`
- display default: `title  ->  relpath`
- display override: when query matches an alias and does not match title,
  display becomes `matched_alias  ->  relpath`

This keeps path matching available (for folder-driven discovery) while keeping
title/alias relevance higher.

## Developer workflow

Style/lint config files:

- `.stylua.toml`
- `.luacheckrc`

Scripted commands are available through `Makefile`:

- `make fmt`
- `make lint`
- `make test-unit`
- `make test-e2e`
- `make test`

## Tests

Test suite is split into focused layers:

- unit/spec tests in `tests/spec/`
- integration smoke test in `tests/e2e_smoke.lua`

The spec suite currently covers:

- journal routing classification and paths
- strict frontmatter parsing behavior
- duplicate resolution preference in vault matching
- omni entry policy (title/alias/path ordering and alias-first display rule)
