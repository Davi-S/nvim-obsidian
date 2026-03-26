local path = require("nvim-obsidian.path")
local vault = require("nvim-obsidian.model.vault")
local link_parser = require("nvim-obsidian.link.parser")
local jump_resolver = require("nvim-obsidian.link.jump_resolver")

local M = {}

-- Dependency injection: store references to dependencies (default to real modules)
local _vault = vault

local WIKI_LINK_PATTERN = "()(%[%[[^%]]-%]%])()"

local function parsed_link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    for s, body, e in line:gmatch(WIKI_LINK_PATTERN) do
        if col >= s and col <= e then
            local inner = body:sub(3, -3)
            return link_parser.parse_wikilink(inner)
        end
    end

    return nil
end

function M.link_under_cursor()
    local parsed = parsed_link_under_cursor()
    if not parsed then
        return nil
    end
    return vim.trim(parsed.note_ref or "")
end

function M.follow()
    local cfg = require("nvim-obsidian.config").get()
    local parsed = parsed_link_under_cursor()
    if not parsed then
        vim.notify("nvim-obsidian: no wiki link under cursor", vim.log.levels.WARN)
        return
    end

    local current_file = vim.api.nvim_buf_get_name(0)
    local ok, err = jump_resolver.resolve_and_jump(parsed, cfg, current_file)
    if not ok then
        vim.notify("nvim-obsidian: " .. (err or "link target not found"), vim.log.levels.WARN)
    end
end

--- Initialize wiki module with optional dependency injection (for testing)
--- @param opts table Optional: { vault = ... }
function M.init(opts)
    opts = opts or {}
    if opts.vault then _vault = opts.vault end
end

return M
