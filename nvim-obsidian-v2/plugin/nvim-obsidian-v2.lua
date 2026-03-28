---@diagnostic disable: undefined-global

if vim.g.loaded_nvim_obsidian_v2 == 1 then
    return
end
vim.g.loaded_nvim_obsidian_v2 = 1

require("nvim_obsidian_v2").setup({})
