local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

local state = {
    by_path = {},
}

local function normalize_path(path)
    local p = tostring(path or ""):gsub("\\", "/")
    p = p:gsub("//+", "/")
    return p
end

local function is_string(value)
    return type(value) == "string" and value ~= ""
end

local function normalize_aliases(aliases)
    local out = {}
    if type(aliases) ~= "table" then
        return out
    end

    for _, alias in ipairs(aliases) do
        if type(alias) == "string" and alias ~= "" then
            table.insert(out, alias)
        end
    end
    return out
end

local function copy_note(note)
    return {
        path = normalize_path(note.path),
        title = tostring(note.title),
        aliases = normalize_aliases(note.aliases),
    }
end

local function validate_note(note)
    if type(note) ~= "table" then
        return false, errors.new(errors.codes.INVALID_INPUT, "note must be a table")
    end

    if not is_string(note.path) then
        return false, errors.new(errors.codes.INVALID_INPUT, "note.path must be a non-empty string")
    end

    if not is_string(note.title) then
        return false, errors.new(errors.codes.INVALID_INPUT, "note.title must be a non-empty string")
    end

    if note.aliases ~= nil and type(note.aliases) ~= "table" then
        return false, errors.new(errors.codes.INVALID_INPUT, "note.aliases must be an array when provided")
    end

    return true, nil
end

local function collect_notes_sorted()
    local out = {}
    for _, note in pairs(state.by_path) do
        table.insert(out, note)
    end

    table.sort(out, function(a, b)
        return a.path < b.path
    end)

    return out
end

local function dedup_by_path(items)
    local out = {}
    local seen = {}
    for _, item in ipairs(items) do
        if not seen[item.path] then
            seen[item.path] = true
            table.insert(out, item)
        end
    end
    return out
end

function M.upsert_note(note)
    local ok, err = validate_note(note)
    if not ok then
        return { ok = false, error = err }
    end

    local normalized = copy_note(note)
    state.by_path[normalized.path] = normalized
    return { ok = true, error = nil }
end

function M.remove_note(path)
    if not is_string(path) then
        return {
            ok = false,
            error = errors.new(errors.codes.INVALID_INPUT, "path must be a non-empty string"),
        }
    end

    local key = normalize_path(path)
    if state.by_path[key] == nil then
        return {
            ok = false,
            error = errors.new(errors.codes.NOT_FOUND, "note path not found", { path = key }),
        }
    end

    state.by_path[key] = nil
    return { ok = true, error = nil }
end

function M.find_by_identity_token(token)
    local q = tostring(token or "")
    if q == "" then
        return { matches = {} }
    end
    local q_path = normalize_path(q)

    local notes = collect_notes_sorted()

    local exact = {}
    for _, note in ipairs(notes) do
        if note.title == q then
            table.insert(exact, note)
        elseif note.path == q_path then
            table.insert(exact, note)
        else
            for _, alias in ipairs(note.aliases) do
                if alias == q then
                    table.insert(exact, note)
                    break
                end
            end
        end
    end

    if #exact > 0 then
        return { matches = dedup_by_path(exact) }
    end

    local ql = string.lower(q)
    local qpl = string.lower(q_path)
    local ci = {}
    for _, note in ipairs(notes) do
        if string.lower(note.title) == ql then
            table.insert(ci, note)
        elseif string.lower(note.path) == qpl then
            table.insert(ci, note)
        else
            for _, alias in ipairs(note.aliases) do
                if string.lower(alias) == ql then
                    table.insert(ci, note)
                    break
                end
            end
        end
    end

    return { matches = dedup_by_path(ci) }
end

-- Backward-compatible alias; callers should migrate to find_by_identity_token.
M.find_by_title_or_alias = M.find_by_identity_token

function M.list_notes()
    return collect_notes_sorted()
end

function M._replace_all(notes)
    if type(notes) ~= "table" then
        return false, "notes must be a table"
    end

    local next_state = {}
    for _, note in ipairs(notes) do
        local ok, err = validate_note(note)
        if not ok then
            return false, tostring(err and err.message or "invalid note")
        end
        local normalized = copy_note(note)
        next_state[normalized.path] = normalized
    end

    state.by_path = next_state
    return true, nil
end

function M._reset_for_tests()
    state.by_path = {}
end

function M._all_notes_for_tests()
    return collect_notes_sorted()
end

return M
