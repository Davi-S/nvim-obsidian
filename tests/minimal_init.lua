---@diagnostic disable: undefined-global

require("tests.support.runtime").setup_runtime_paths()

if not pcall(require, "telescope") then
    package.loaded["telescope"] = {}
end

if not pcall(require, "cmp") then
    package.loaded["cmp"] = {}
end

if not pcall(require, "nvim-treesitter.parsers") then
    package.loaded["nvim-treesitter.parsers"] = {}
end

vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
