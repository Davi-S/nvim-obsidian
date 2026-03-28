---@class CmpCompletionSource
---@field complete fun(ctx: table, callback: fun(result: table))
---@field resolve fun(item: table, callback: fun(item: table))
---@field display_name string
---@field _ctx table

local M = {}

--- Get trigger characters for completion source
---@return string[]
function M.get_trigger_characters()
    return { "[", "#" }
end

--- Resolve completion item with additional information
---@param item table Completion item from cmp
---@param callback fun(item: table) Callback with resolved item
function M.resolve_completion_item(item, callback)
    if not item then
        return
    end

    if item.data and item.data.path then
        item.detail = item.data.path
    end

    if callback then
        callback(item)
    end
end

--- Create a completion source for nvim-cmp
---@param ctx table Context with vault_catalog and search_ranking
---@return CmpCompletionSource
function M.create_source(ctx)
    ctx = ctx or {}

    local source = {
        display_name = "Obsidian",
        _ctx = ctx,
    }

    local function is_wiki_link_context(before_line, col)
        if not before_line or col < 2 then
            return false, ""
        end

        -- Look for [[ trigger
        local wiki_start = before_line:find("%[%[", 1, true)
        if not wiki_start then
            return false, ""
        end

        -- Extract the query after [[
        local query_start = wiki_start + 2
        if query_start > col then
            return true, ""
        end

        local query = before_line:sub(query_start, col - 1)
        -- Check if we're still in the wiki link (not closed by ]])
        if query:find("%]%]") then
            return false, query
        end

        return true, query
    end

    local function extract_anchor_context(query)
        -- Check if query contains anchor reference [[foo#bar]]
        local anchor_idx = query:find("#", 1, true)
        if not anchor_idx then
            return nil, ""
        end
        local note_ref = query:sub(1, anchor_idx - 1)
        local anchor_query = query:sub(anchor_idx + 1)
        return note_ref, anchor_query
    end

    local function filter_candidates(notes, query)
        if not query or query == "" then
            return notes
        end

        local query_lower = query:lower()
        local filtered = {}

        for _, note in ipairs(notes or {}) do
            local title_lower = (note.title or ""):lower()
            if string.find(title_lower, query_lower, 1, true) then
                table.insert(filtered, note)
            else
                -- Check aliases
                local has_match = false
                for _, alias in ipairs(note.aliases or {}) do
                    if string.find(alias:lower(), query_lower, 1, true) then
                        has_match = true
                        break
                    end
                end
                if has_match then
                    table.insert(filtered, note)
                end
            end
        end

        return filtered
    end

    local function format_completion_item(note, score_data)
        return {
            label = note.title or note.path,
            kind = "Variable",
            sortText = string.format("%05d_%s", 9999 - (score_data and score_data.score or 0), note.title or note.path),
            filterText = note.title or note.path,
            detail = note.path,
            data = { path = note.path, note = note },
        }
    end

    --- Complete function for nvim-cmp
    ---@param completion_ctx table Completion context from cmp
    ---@param callback fun(result: {items: table}) Callback with items
    function source.complete(completion_ctx, callback)
        local result = { items = {} }

        if not completion_ctx or type(completion_ctx) ~= "table" then
            if callback then
                callback(result)
            end
            return
        end

        local before_line = completion_ctx.before_line or completion_ctx.cur_line or ""
        local col = completion_ctx.col or 0

        local is_wiki, query = is_wiki_link_context(before_line, col)

        if not is_wiki then
            if callback then
                callback(result)
            end
            return
        end

        -- Get vault notes
        local notes = {}
        pcall(function()
            if ctx.vault_catalog and ctx.vault_catalog.list_notes then
                notes = ctx.vault_catalog.list_notes() or {}
            end
        end)

        if #notes == 0 then
            if callback then
                callback(result)
            end
            return
        end

        -- Filter by query
        local filtered = filter_candidates(notes, query)

        -- Rank candidates
        local ranked = filtered
        pcall(function()
            if ctx.search_ranking and ctx.search_ranking.score_candidates then
                ranked = ctx.search_ranking.score_candidates(query, filtered) or filtered
            end
        end)

        -- Convert to completion items
        for _, score_data in ipairs(ranked) do
            local note = score_data.note or score_data
            local item = format_completion_item(note, score_data)
            table.insert(result.items, item)
        end

        if callback then
            pcall(function()
                callback(result)
            end)
        end
    end

    --- Resolve function for nvim-cmp
    ---@param item table Completion item
    ---@param callback fun(item: table) Callback with resolved item
    function source.resolve(item, callback)
        M.resolve_completion_item(item, callback)
    end

    return source
end

return M
