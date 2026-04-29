# nvim-obsidian

Neovim plugin for Obsidian-style workflows, rebuilt with clear architecture boundaries and test-first contracts.

This repository contains:
- The plugin implementation in Lua.
- Domain and behavior contracts in docs.
- Unit, integration, and end-to-end tests.

## What It Provides

# nvim-obsidian

A friendly Neovim plugin that brings Obsidian-style note workflows into Neovim.

Whether you keep a simple vault of markdown notes or run a large collection, nvim-obsidian helps you find, browse, and manage notes without leaving the editor.

Key features
- Fast omni search for notes (find or create as you type)
- Follow wiki-style links with smart disambiguation
- See backlinks for the current note
- Daily / journal helpers (today, next, previous)
- Calendar view and date picker for creating/opening dated notes
- Templates and placeholders for quick note creation

Getting started (example with lazy.nvim)

1. Install with your plugin manager. Example using `lazy.nvim`:

```lua
{
  "Davi-S/nvim-obsidian",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("nvim_obsidian").setup({
      vault_root = vim.fn.expand("~/ObsidianVault"),
    })
  end,
}
```

2. Open Neovim and use one of the main commands:

- `:ObsidianOmni` — search and create notes quickly
- `:ObsidianFollow` — follow a wiki link under the cursor
- `:ObsidianSearch` — advanced vault search
- `:ObsidianBacklinks` — view backlinks for current note
- `:ObsidianCalendar` / `:ObsidianCalendarFloat` — open calendar and date picker
- `:ObsidianReindex` — re-scan your vault (use if files moved externally)

Simple usage tips
- The calendar floats are sized in text columns and rows (not pixels). If a square-looking window is important, try increasing the `width` in your `calendar.floating` config — terminal fonts often make rows taller than columns.
- Templates make repetitive notes faster; configure placeholders in the plugin setup.

Configuration
The plugin exposes a small `setup()` table for things like `vault_root`, `calendar` options (highlights, floating size, border), and template behavior. See `docs/USER_GUIDE.md` for friendly, example-driven configuration snippets.

Help and documentation
- Short help: `:help nvim-obsidian` (run `:helptags ALL` if needed)
- Full user guide and examples: `docs/USER_GUIDE.md`

Want to help or test?
- Run the test suite: `make test` (unit, integration, and e2e are available)
- Contributing guidelines and architecture notes live under `docs/`.

License
- There is no license file in this repository yet — add one if you plan to redistribute.
