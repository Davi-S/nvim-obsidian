local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

local function trim(text)
    return vim.trim(text or "")
end

local function basename(path)
    local p = tostring(path or "")
    local name = p:match("[^/]+$") or p
    return name
end

local function stem(path)
    local name = basename(path)
    local s = name:gsub("%.md$", "")
    return s
end

local function normalize_path(path)
    local p = tostring(path or ""):gsub("\\", "/")
    p = p:gsub("//+", "/")
    return p
end

local function parse_inner(inner)
    local content = trim(inner)
    local note_part, display_alias = content:match("^(.-)|(.+)$")
    if note_part == nil then
        note_part = content
    end

    note_part = trim(note_part)
    display_alias = trim(display_alias)
    if display_alias == "" then
        display_alias = nil
    end

    local note_ref = note_part
    local anchor = nil
    local block_id = nil

    local left, right = note_part:match("^(.-)#(.*)$")
    if left ~= nil then
        note_ref = trim(left)
        right = trim(right)
        if right:sub(1, 1) == "^" then
            block_id = trim(right:sub(2))
            if block_id == "" then
                block_id = nil
            end
        else
            anchor = right
            if anchor == "" then
                anchor = nil
            end
        end
    end

    return {
        raw = "[[" .. inner .. "]]",
        note_ref = note_ref,
        anchor = anchor,
        block_id = block_id,
        display_alias = display_alias,
    }
end

function M.parse_at_cursor(line, col)
    if type(line) ~= "string" then
        return {
            target = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "line must be a string"),
        }
    end

    if type(col) ~= "number" then
        return {
            target = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "col must be a number"),
        }
    end

    local cursor_col = math.floor(col)
    if cursor_col < 1 then
        cursor_col = 1
    end

    local i = 1
    while i <= #line do
        local open = line:find("[[", i, true)
        if not open then
            break
        end
        local close = line:find("]]", open + 2, true)
        if not close then
            break
        end

        local end_col = close + 1
        if cursor_col >= open and cursor_col <= end_col then
            local inner = line:sub(open + 2, close - 1)
            local target = parse_inner(inner)
            return { target = target, error = nil }
        end

        i = close + 2
    end

    return { target = nil, error = nil }
end

local function note_matches_token(note, token)
    local title = tostring(note.title or "")
    if title == token then
        return true
    end

    if type(note.aliases) == "table" then
        for _, alias in ipairs(note.aliases) do
            if type(alias) == "string" and alias == token then
                return true
            end
        end
    end

    local path = normalize_path(note.path)
    if path ~= "" then
        if path == token then
            return true
        end
        if path:gsub("%.md$", "") == token then
            return true
        end
        if stem(path) == token then
            return true
        end
    end

    return false
end

function M.resolve_target(target, candidate_notes)
    local t = target or {}
    local token = trim(t.note_ref)

    local notes = candidate_notes
    if type(notes) ~= "table" then
        notes = {}
    end

    local matches = {}

    if token ~= "" then
        for _, note in ipairs(notes) do
            if type(note) == "table" and note_matches_token(note, token) then
                table.insert(matches, note)
            end
        end
    end

    table.sort(matches, function(a, b)
        return normalize_path(a.path or "") < normalize_path(b.path or "")
    end)

    if #matches == 0 then
        return {
            status = "missing",
            resolved_path = nil,
            ambiguous_matches = nil,
        }
    end

    if #matches == 1 then
        return {
            status = "resolved",
            resolved_path = matches[1].path,
            ambiguous_matches = nil,
        }
    end

    return {
        status = "ambiguous",
        resolved_path = nil,
        ambiguous_matches = matches,
    }
end

return M
