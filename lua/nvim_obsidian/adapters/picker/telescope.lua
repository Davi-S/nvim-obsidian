local M = {}

local function has_select()
    return vim and vim.ui and type(vim.ui.select) == "function"
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b
end

local function numeric_keys(tbl)
    local keys = {}
    if type(tbl) ~= "table" then
        return keys
    end
    for k, _ in pairs(tbl) do
        if type(k) == "number" then
            table.insert(keys, k)
        end
    end
    table.sort(keys)
    return keys
end

function M._prepare_candidates(ctx, notes)
    local valid_notes = {}
    for _, i in ipairs(numeric_keys(notes)) do
        local note = notes[i]
        if type(note) == "table" and type(note.path) == "string" and note.path ~= "" then
            table.insert(valid_notes, note)
        end
    end

    local ranked_notes = valid_notes
    local ranking = ctx and ctx.search_ranking
    local score_candidates = ranking and ranking.score_candidates
    local scored = safe_call(score_candidates, "", valid_notes)
    if type(scored) == "table" and #scored > 0 then
        ranked_notes = {}
        for _, entry in ipairs(scored) do
            local n = entry and entry.note or nil
            if type(n) == "table" then
                table.insert(ranked_notes, n)
            end
        end
    end

    local items = {}
    local note_map = {}
    for _, note in ipairs(ranked_notes) do
        local display = nil
        local select_display = ranking and ranking.select_display
        if type(select_display) == "function" then
            display = safe_call(select_display, note)
        end

        if type(display) ~= "string" or display == "" then
            display = (note.title or note.path) .. " -> " .. note.path
        end

        table.insert(items, display)
        table.insert(note_map, note)
    end

    return items, note_map
end

function M._prepare_disambiguation(matches)
    local items = {}
    local match_map = {}

    for _, i in ipairs(numeric_keys(matches)) do
        local match = matches[i]
        if type(match) == "table" and type(match.path) == "string" and match.path ~= "" then
            local title = match.title or "(untitled)"
            table.insert(items, title .. " -> " .. match.path)
            table.insert(match_map, match)
        end
    end

    return items, match_map
end

function M.open_omni(ctx)
    local notes_fn = ctx and ctx.vault_catalog and ctx.vault_catalog.list_notes
    if type(notes_fn) ~= "function" then
        return false
    end

    local notes = safe_call(notes_fn) or {}
    local items, note_map = M._prepare_candidates(ctx or {}, notes)
    if #items == 0 then
        return false
    end

    if not has_select() then
        return false
    end

    local selected = nil
    safe_call(vim.ui.select, items, { prompt = "Obsidian Omni" }, function(choice, idx)
        if choice and idx and note_map[idx] then
            selected = note_map[idx]
        end
    end)

    return selected ~= nil
end

function M.open_disambiguation(matches)
    local items, match_map = M._prepare_disambiguation(matches)
    if #items == 0 then
        return false
    end

    if not has_select() then
        return false
    end

    local selected = nil
    safe_call(vim.ui.select, items, { prompt = "Disambiguate link target" }, function(choice, idx)
        if choice and idx and match_map[idx] then
            selected = match_map[idx]
        end
    end)

    return selected ~= nil
end

return M
