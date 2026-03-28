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
    -- Use-case payload mode: items already prepared by search_open_create.
    if type(ctx) == "table" and type(ctx.items) == "table" then
        if not has_select() then
            return { action = "cancel" }
        end

        local display_items = {}
        local item_map = {}
        for _, item in ipairs(ctx.items) do
            local label = (type(item) == "table" and tostring(item.label or "")) or ""
            if label ~= "" then
                table.insert(display_items, label)
                table.insert(item_map, item)
            end
        end

        local create_idx = nil
        if ctx.allow_create then
            table.insert(display_items, "+ Create: " .. tostring(ctx.query or ""))
            create_idx = #display_items
        end

        if #display_items == 0 then
            return { action = "cancel" }
        end

        local picked_idx = nil
        safe_call(vim.ui.select, display_items, { prompt = "Obsidian Omni" }, function(choice, idx)
            if choice and idx then
                picked_idx = idx
            end
        end)

        if not picked_idx then
            return { action = "cancel" }
        end

        if create_idx and picked_idx == create_idx then
            return {
                action = "create",
                query = tostring(ctx.query or ""),
            }
        end

        local selected = item_map[picked_idx]
        if not selected then
            return { action = "cancel" }
        end

        return {
            action = "open",
            item = selected,
        }
    end

    -- Legacy/simple mode used by existing unit tests.
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
    local payload_mode = type(matches) == "table" and type(matches.matches) == "table"
    local source_matches = payload_mode and matches.matches or matches
    local items, match_map = M._prepare_disambiguation(source_matches)
    if #items == 0 then
        if payload_mode then
            return { action = "cancel" }
        end
        return false
    end

    if not has_select() then
        if payload_mode then
            return { action = "cancel" }
        end
        return false
    end

    local selected = nil
    safe_call(vim.ui.select, items, {
        prompt = payload_mode and "Backlinks" or "Disambiguate link target",
    }, function(choice, idx)
        if choice and idx and match_map[idx] then
            selected = match_map[idx]
        end
    end)

    if payload_mode then
        if not selected then
            return { action = "cancel" }
        end
        return {
            action = "open",
            item = selected,
            path = selected.path,
        }
    end

    return selected ~= nil
end

function M.open_search(opts)
    opts = opts or {}
    if not has_select() then
        return false
    end

    local root = opts.root or (vim and vim.fn and vim.fn.getcwd and vim.fn.getcwd()) or "."
    local query = tostring(opts.query or "")
    if query == "" and vim and vim.fn and type(vim.fn.input) == "function" then
        query = tostring(vim.fn.input("Search vault: "))
    end
    if query == "" then
        return false
    end

    local escaped_root = tostring(root):gsub("'", "'\\''")
    local escaped_query = tostring(query):gsub("'", "'\\''")
    local cmd = "rg --line-number --no-heading --color=never '" .. escaped_query .. "' '" .. escaped_root .. "'"
    local proc = io.popen(cmd)
    if not proc then
        return false
    end

    local lines = {}
    for line in proc:lines() do
        if line ~= "" then
            table.insert(lines, line)
        end
    end
    proc:close()

    if #lines == 0 then
        return false
    end

    local selected = nil
    safe_call(vim.ui.select, lines, { prompt = "Search results" }, function(choice)
        selected = choice
    end)

    if not selected then
        return false
    end

    local path = selected:match("^([^:]+):")
    local line_no = tonumber(selected:match("^[^:]+:(%d+):"))
    if path and opts.navigation and type(opts.navigation.open_path) == "function" then
        opts.navigation.open_path(path)
        if line_no and vim and vim.api and type(vim.api.nvim_win_set_cursor) == "function" then
            pcall(vim.api.nvim_win_set_cursor, 0, { line_no, 0 })
        end
    end

    return true
end

return M
