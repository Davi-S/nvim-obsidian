---@diagnostic disable: undefined-global

if vim.g.loaded_nvim_obsidian == 1 then
    return
end
vim.g.loaded_nvim_obsidian = 1

require("nvim_obsidian").setup({})
