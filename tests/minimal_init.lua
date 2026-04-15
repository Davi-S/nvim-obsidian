---@diagnostic disable: undefined-global

require("tests.support.runtime").setup_runtime_paths()

if not pcall(require, "telescope") then
    package.loaded["telescope"] = {}
end

if not pcall(require, "blink.cmp") then
    package.loaded["blink.cmp"] = {}
end

if not pcall(require, "nvim-treesitter.parsers") then
    package.loaded["nvim-treesitter.parsers"] = {}
end

vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
