local Note = require("nvim-obsidian.model.note")
local path = require("nvim-obsidian.path")

local M = {
    notes_by_path = {},
    title_index = {},
    alias_index = {},
    _bulk_updating = false,
}

local function clear_indexes()
    M.title_index = {}
    M.alias_index = {}
end

local function index_note(note)
    local key = vim.fn.tolower(note.title)
    M.title_index[key] = M.title_index[key] or {}
    table.insert(M.title_index[key], note)

    for _, alias in ipairs(note.aliases) do
        local akey = vim.fn.tolower(alias)
        M.alias_index[akey] = M.alias_index[akey] or {}
        table.insert(M.alias_index[akey], note)
    end
end

function M.rebuild_indexes()
    clear_indexes()
    for _, note in pairs(M.notes_by_path) do
        index_note(note)
    end

    for _, bucket in pairs(M.title_index) do
        table.sort(bucket, function(a, b)
            return a.filepath < b.filepath
        end)
    end

    for _, bucket in pairs(M.alias_index) do
        table.sort(bucket, function(a, b)
            return a.filepath < b.filepath
        end)
    end
end

function M.begin_bulk_update()
    M._bulk_updating = true
end

function M.end_bulk_update()
    M._bulk_updating = false
    M.rebuild_indexes()
end

function M.reset()
    M.notes_by_path = {}
    clear_indexes()
end

function M.upsert_note(filepath, data)
    M.notes_by_path[filepath] = Note.new(filepath, data)
    if not M._bulk_updating then
        M.rebuild_indexes()
    end
end

function M.remove_note(filepath)
    M.notes_by_path[filepath] = nil
    if not M._bulk_updating then
        M.rebuild_indexes()
    end
end

function M.all_notes()
    local out = {}
    for _, note in pairs(M.notes_by_path) do
        table.insert(out, note)
    end
    table.sort(out, function(a, b)
        return a.title < b.title
    end)
    return out
end

function M.find_exact_title(title)
    return M.title_index[vim.fn.tolower(title)] or {}
end

function M.find_exact_alias(alias)
    return M.alias_index[vim.fn.tolower(alias)] or {}
end

function M.resolve_by_title_or_alias(input, cfg)
    local by_title = M.find_exact_title(input)
    if #by_title > 0 then
        return by_title
    end

    local by_alias = M.find_exact_alias(input)
    if #by_alias > 0 then
        return by_alias
    end

    local rel = input:gsub("\\", "/")
    if rel:sub(-3) ~= ".md" then
        rel = rel .. ".md"
    end
    local abs = path.join(cfg.vault_root, rel)
    local found = M.notes_by_path[path.normalize(abs)]
    if found then
        return { found }
    end

    return {}
end

function M.preferred_match(input, matches, cfg)
    if #matches == 0 then
        return nil
    end
    if #matches == 1 then
        return matches[1]
    end

    local rel = input:gsub("\\", "/")
    if rel:sub(-3) ~= ".md" then
        rel = rel .. ".md"
    end
    local explicit_path = path.normalize(path.join(cfg.vault_root, rel))

    for _, note in ipairs(matches) do
        if path.normalize(note.filepath) == explicit_path then
            return note
        end
    end

    local root_filename = vim.fn.fnamemodify(explicit_path, ":t")
    local root_exact = path.normalize(path.join(cfg.vault_root, root_filename))
    for _, note in ipairs(matches) do
        if path.normalize(note.filepath) == root_exact then
            return note
        end
    end

    return nil
end

return M
