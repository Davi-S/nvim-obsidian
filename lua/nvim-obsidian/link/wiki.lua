local path = require("nvim-obsidian.path")
local vault = require("nvim-obsidian.model.vault")

local M = {}

-- Dependency injection: store references to dependencies (default to real modules)
local _vault = vault

local WIKI_LINK_PATTERN = "()(%[%[[^%]]-%]%])()"
local WIKI_ALIAS_SPLIT_PATTERN = "^([^|]+)"

function M.link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    for s, body, e in line:gmatch(WIKI_LINK_PATTERN) do
        if col >= s and col <= e then
            local inner = body:sub(3, -3)
            local target = inner:match(WIKI_ALIAS_SPLIT_PATTERN) or inner
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

    local matches = _vault.resolve_by_title_or_alias(target, cfg)
    local preferred = _vault.preferred_match(target, matches, cfg)
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

--- Initialize wiki module with optional dependency injection (for testing)
--- @param opts table Optional: { vault = ... }
function M.init(opts)
    opts = opts or {}
    if opts.vault then _vault = opts.vault end
end

return M
