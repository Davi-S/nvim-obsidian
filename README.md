# nvim-obsidian

Config-first Obsidian workflow plugin for Neovim.

nvim-obsidian focuses on fast note creation, journal routing, backlink search,
and configurable template rendering without forcing a specific visual style.

## Features

- Strict setup with absolute vault root
- Vault index with markdown/frontmatter scanning
- Omni picker for search, open, or create
- Journal routing for daily, weekly, monthly, and yearly notes
- Time travel commands for journal notes (today, next, previous)
- Wiki-link follow for [[Title]], [[Title|Alias]], [[Title#Heading]], and [[Title#^blockid|Alias]]
- Backlinks search for current note title
- Vault-scoped full-text search
- User-defined template placeholders
- nvim-cmp completion source for wiki links
- Dataview rendering for TASK and TABLE WITHOUT ID queries

## Non-goals

- Markdown concealment
- Markdown formatting

## Requirements

- Neovim
- nvim-lua/plenary.nvim
- nvim-telescope/telescope.nvim
- hrsh7th/nvim-cmp
- nvim-treesitter/nvim-treesitter

## Installation (lazy.nvim)

```lua
{
  "Davi-S/nvim-obsidian",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "hrsh7th/nvim-cmp",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    local obsidian = require("nvim-obsidian")

    -- Journal title placeholders (required when journal is enabled)
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
      vault_root = "/home/user/ObsidianVault",
      locale = "pt-BR",
      new_notes_subdir = "10 Novas notas",
      dataview = {
        enabled = true,
        render = {
          when = { "on_open", "on_save" },
          scope = "event", -- event | current | visible | loaded
          patterns = { "*.md" },
        },
        placement = "below_block", -- below_block | above_block
        messages = {
          task_no_results = {
            enabled = true,
            text = "Dataview: No results to show for task query.",
          },
        },
        highlights = {
          -- optional highlight group overrides
          -- header = "markdownLinkText",
          -- error = "WarningMsg",
          -- table_link = "markdownLinkText",
          -- task_no_results = "Comment",
        },
      },
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

    -- Template placeholders (optional)
    obsidian.template_register_placeholder("title", function(ctx)
      return ctx.note.title
    end)
  end,
}
```

## Commands

| Command                              | Description                                                        |
| ------------------------------------ | ------------------------------------------------------------------ |
| :ObsidianOmni                        | Open omni picker (search/create)                                   |
| :ObsidianToday                       | Open or create today daily note                                    |
| :ObsidianNext                        | Open or create next journal note                                   |
| :ObsidianPrev                        | Open or create previous journal note                               |
| :ObsidianFollow                      | Follow wiki-link under cursor                                      |
| :ObsidianBacklinks                   | Search backlinks for current note title                            |
| :ObsidianSearch                      | Vault-scoped text search (Telescope live_grep with cwd=vault_root) |
| :ObsidianReindex                     | Force full cache rebuild                                           |
| :ObsidianInsertTemplate [type\|path] | Insert rendered template at cursor                                 |

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

Journal placeholders are separate from template placeholders and must be
registered before setup when journal is enabled.

## Dataview Configuration

First-wave dataview options are exposed under `dataview`:

- `enabled`: globally enable/disable dataview rendering.
- `render.when`: trigger list with predetermined options:
  - `on_open` -> `BufReadPost`
  - `on_save` -> `BufWritePost`
  - `on_buf_enter` -> `BufEnter`
- `render.scope`: choose which buffers to refresh per event:
  - `event`, `current`, `visible`, `loaded`
- `render.patterns`: autocmd patterns (default `{ "*.md" }`).
- `placement`: render `below_block` or `above_block`.
- `messages.task_no_results`: control text shown when a TASK query is valid but returns no rows.
- `highlights`: optional highlight-group overrides for header/error/table links/no-results text.

Example (save-only rendering for current buffer):

```lua
require("nvim-obsidian").setup({
  vault_root = "/home/user/ObsidianVault",
  dataview = {
    render = {
      when = { "on_save" },
      scope = "current",
      patterns = { "*.md" },
    },
  },
})
```

## Search Behavior

- ObsidianSearch uses Telescope live_grep scoped to vault_root.
- ObsidianBacklinks searches for wiki-link references to the current note title.

## Omni Ranking Policy

- Search priority order: title, aliases, relpath
- Default display: title -> relpath
- If query matches alias and not title, display becomes matched_alias -> relpath

## Development

Repository scripts from Makefile:

- make fmt
- make lint
- make test-unit
- make test-integration
- make test-e2e
- make test

## Testing

Test layout:

- tests/spec: unit/spec coverage
- tests/integration: integration coverage
- tests/e2e: end-to-end workflow coverage

## Documentation

- Full docs: DOCUMENTATION.md
- Vim help: doc/nvim-obsidian.txt
