local vault = require("nvim-obsidian.model.vault")
local markdown_parser = require("nvim-obsidian.parser.markdown")

local M = {}

local function normalize(s)
    return markdown_parser.normalize_heading_id(vim.trim(s or ""))
end

local function find_heading_line(note, anchor)
    if not anchor or anchor == "" then
        return nil
    end

    local wanted_norm = normalize(anchor)
    for _, h in ipairs(note.headings or {}) do
        if vim.fn.tolower(h.text or "") == vim.fn.tolower(anchor) then
            return h.line
        end
        if normalize(h.text or "") == wanted_norm then
            return h.line
        end
        if (h.id or "") == anchor or (h.id or "") == wanted_norm then
            return h.line
        end
    end

    return nil
end

local function find_block_line(note, block_id)
    if not block_id or block_id == "" then
        return nil
    end

    for _, b in ipairs(note.blocks or {}) do
        if b.id == block_id then
            return b.line
        end
    end

    return nil
end

function M.resolve_and_jump(link, cfg, current_file)
    local note_ref = vim.trim(link.note_ref or "")

    local preferred
    if note_ref == "" then
        local all = vault.resolve_by_title_or_alias(vim.fn.fnamemodify(current_file or "", ":t:r"), cfg)
        preferred = all[1]
    else
        local matches = vault.resolve_by_title_or_alias(note_ref, cfg)
        preferred = vault.preferred_match(note_ref, matches, cfg)
        if not preferred and #matches == 1 then
            preferred = matches[1]
        end
    end

    if not preferred then
        return false, "link target not found"
    end

    vim.cmd.edit(vim.fn.fnameescape(preferred.filepath))

    if link.anchor_kind == "heading" then
        local line = find_heading_line(preferred, link.anchor)
        if not line then
            return false, "heading not found"
        end
        vim.api.nvim_win_set_cursor(0, { line, 0 })
    elseif link.anchor_kind == "block" then
        local line = find_block_line(preferred, link.anchor)
        if not line then
            return false, "block not found"
        end
        vim.api.nvim_win_set_cursor(0, { line, 0 })
    end

    return true
end

return M
