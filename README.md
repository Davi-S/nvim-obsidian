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
