local M = {}

local function trim(s)
    return vim.trim(s or "")
end

function M.normalize_heading_id(text)
    local s = trim(text)
    s = vim.fn.tolower(s)
    s = s:gsub("[`*_~]", "")
    s = s:gsub("%[", ""):gsub("%]", "")
    s = s:gsub("%b()", "")
    s = s:gsub("[^%w%s%-_À-ÖØ-öø-ÿ]", "")
    s = s:gsub("%s+", "-")
    s = s:gsub("%-+", "-")
    s = s:gsub("^%-", ""):gsub("%-$", "")
    return s
end

function M.extract_headings(text)
    local out = {}
    local lines = vim.split(text or "", "\n", { plain = true })

    for i, line in ipairs(lines) do
        local hashes, heading = line:match("^(#+)%s+(.+)$")
        if hashes and heading then
            heading = heading:gsub("%s+#+%s*$", "")
            heading = trim(heading)
            if heading ~= "" then
                table.insert(out, {
                    level = #hashes,
                    text = heading,
                    id = M.normalize_heading_id(heading),
                    line = i,
                })
            end
        end
    end

    return out
end

function M.extract_blocks(text)
    local out = {}
    local lines = vim.split(text or "", "\n", { plain = true })

    for i, line in ipairs(lines) do
        local id = line:match("%^([A-Za-z0-9_-]+)%s*$")
        if id then
            table.insert(out, {
                id = id,
                line = i,
            })
        end
    end

    return out
end

return M
