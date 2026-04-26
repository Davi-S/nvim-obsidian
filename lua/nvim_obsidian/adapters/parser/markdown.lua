---Markdown parser adapter.
---
---Extracts wiki-links from markdown text for backlink and navigation features.
local M = {}

local function trim(s)
    if type(s) ~= "string" then return nil end
    local out = s:gsub("^%s+", ""):gsub("%s+$", "")
    if out == "" then
        return nil
    end
    return out
end

---Extract wiki-link references from markdown text.
---@param markdown string
---@return table[]
function M.extract_wikilinks(markdown)
    if type(markdown) ~= "string" then
        return {}
    end

    local out = {}
    for body in markdown:gmatch("%[%[([^%]]+)%]%]") do
        local raw = "[[" .. body .. "]]"
        local target = body
        local alias = nil

        local pipe_pos = target:find("|", 1, true)
        if pipe_pos then
            alias = trim(target:sub(pipe_pos + 1))
            target = target:sub(1, pipe_pos - 1)
        end

        local note_ref = target
        local heading = nil
        local block = nil

        local hash_pos = target:find("#", 1, true)
        if hash_pos then
            note_ref = target:sub(1, hash_pos - 1)
            local anchor = trim(target:sub(hash_pos + 1))
            if anchor and anchor:sub(1, 1) == "^" then
                block = trim(anchor:sub(2))
            else
                heading = anchor
            end
        end

        note_ref = trim(note_ref)
        if note_ref then
            table.insert(out, {
                raw = raw,
                note_ref = note_ref,
                alias = alias,
                heading = heading,
                block = block,
            })
        end
    end

    return out
end

return M
