---@diagnostic disable: undefined-global

local cwd = vim.fn.getcwd()
vim.opt.rtp:append(cwd)

local container = require("nvim_obsidian").setup({})
assert(container and container.adapters and container.use_cases, "setup should return container")

local commands = vim.api.nvim_get_commands({ builtin = false })
assert(commands.ObsidianHealth ~= nil, "ObsidianHealth should be available")

vim.cmd("ObsidianHealth")
