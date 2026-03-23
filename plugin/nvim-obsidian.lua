if vim.g.loaded_nvim_obsidian_runtime == 1 then
    return
end
vim.g.loaded_nvim_obsidian_runtime = 1

-- Conventional runtime entrypoint: users can set `vim.g.nvim_obsidian_opts`
-- before startup to auto-configure without a plugin manager callback.
if type(vim.g.nvim_obsidian_opts) == "table" then
    local ok, mod = pcall(require, "nvim-obsidian")
    if ok then
        mod.setup(vim.g.nvim_obsidian_opts)
    end
end
