local M = {}

local function trim(s)
    return vim.trim(s or "")
end

function M.parse_wikilink(inner)
    local content = trim(inner)
    local out = {
        note_ref = "",
        alias = nil,
        anchor = nil,
        anchor_kind = nil,
    }

    if content == "" then
        return out
    end

    local note_part, alias = content:match("^(.-)|(.+)$")
    if note_part then
        out.alias = trim(alias)
    else
        note_part = content
    end

    note_part = trim(note_part)

    local note_ref, anchor = note_part:match("^(.-)#(.*)$")
    if note_ref then
        out.note_ref = trim(note_ref)
        anchor = trim(anchor)
        if anchor ~= "" then
            if anchor:sub(1, 1) == "^" then
                out.anchor_kind = "block"
                out.anchor = anchor:sub(2)
            else
                out.anchor_kind = "heading"
                out.anchor = anchor
            end
        end
    else
        out.note_ref = note_part
    end

    return out
end

return M
