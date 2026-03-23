local path = require("nvim-obsidian.path")
local vault = require("nvim-obsidian.model.vault")

local M = {}

function M.link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    for s, body, e in line:gmatch("()(%[%[[^%]]-%]%])()") do
        if col >= s and col <= e then
            local inner = body:sub(3, -3)
            local target = inner:match("^([^|]+)") or inner
            return vim.trim(target)
        end
    end

    return nil
end

function M.follow()
    local cfg = require("nvim-obsidian.config").get()
    local target = M.link_under_cursor()
    if not target or target == "" then
        vim.notify("nvim-obsidian: no wiki link under cursor", vim.log.levels.WARN)
        return
    end

    local matches = vault.resolve_by_title_or_alias(target, cfg)
    local preferred = vault.preferred_match(target, matches, cfg)
    if preferred then
        vim.cmd.edit(vim.fn.fnameescape(preferred.filepath))
        return
    end

    if #matches > 1 then
        vim.notify("nvim-obsidian: multiple matches for link target; use vault-relative path", vim.log.levels.WARN)
        return
    end

    vim.notify("nvim-obsidian: link target not found", vim.log.levels.WARN)
end

return M
