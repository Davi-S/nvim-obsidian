---Picker adapters for nvim-obsidian.
---
---Provides different UI implementations for note selection:
--- - Telescope: uses telescope.nvim for Telescope integration
--- - vim.ui: uses Neovim's native vim.ui.select
---@module adapters.picker

local M = {}

M.telescope = require("nvim_obsidian.adapters.picker.telescope")

return M
