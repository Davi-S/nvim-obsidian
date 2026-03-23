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

## Basic setup

```lua
require("nvim-obsidian").setup({
  vault_root = "/home/davi/Documents/ObsidianAllInVault",
  locale = "pt-BR",
  notes_subdir = "10 Novas notas",
  force_create_key = "<S-CR>",
})
```

## Commands

- `:ObsidianOmni`
- `:ObsidianToday`
- `:ObsidianNext`
- `:ObsidianPrev`
- `:ObsidianFollow`
- `:ObsidianBacklinks`
- `:ObsidianSearch`
- `:ObsidianReindex`
