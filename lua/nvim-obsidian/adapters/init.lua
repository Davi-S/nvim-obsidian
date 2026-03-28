---Adapters for nvim-obsidian.
---
---Provides various plugin integrations and interfaces:
--- - picker: note selection UIs (Telescope, vim.ui.select, etc)
---@module adapters

local M = {}

M.picker = require("nvim_obsidian.adapters.picker")

return M
