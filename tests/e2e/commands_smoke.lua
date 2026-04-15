---@diagnostic disable: undefined-global

local cwd = vim.fn.getcwd()
vim.opt.rtp:append(cwd)

if not pcall(require, "telescope") then
    package.loaded["telescope"] = {}
end

if not pcall(require, "blink.cmp") then
    package.loaded["blink.cmp"] = {}
end

if not pcall(require, "nvim-treesitter.parsers") then
    package.loaded["nvim-treesitter.parsers"] = {}
end

if not pcall(require, "plenary.job") then
    package.loaded["plenary.job"] = {}
end

local container = require("nvim_obsidian").setup({
    vault_root = "/tmp/nvim_obsidian_e2e_vault",
})
assert(container and container.adapters and container.use_cases, "setup should return container")

local commands = vim.api.nvim_get_commands({ builtin = false })
assert(commands.ObsidianHealth ~= nil, "ObsidianHealth should be available")

vim.cmd("ObsidianHealth")
