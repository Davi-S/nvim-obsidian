---@class CmpCompletionSource
---@field complete fun(ctx: table, callback: fun(result: table))
---@field resolve fun(item: table, callback: fun(item: table))
---@field display_name string
---@field _ctx table

local M = {}

local function report_error(message)
    if vim and type(vim.notify) == "function" then
        local level = nil
        if vim.log and vim.log.levels then
            level = vim.log.levels.WARN
        end
        pcall(vim.notify, tostring(message), level, { title = "nvim-obsidian" })
    end
end

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

    local function filter_candidates(notes, query)
        -- If no query is provided, return all notes
        if not query or query == "" then
            return notes
        end

        local query_lower = query:lower()
        local filtered = {}

        for _, note in ipairs(notes or {}) do
            local title_lower = (note.title or ""):lower()
            -- Match against title first (primary match)
            if string.find(title_lower, query_lower, 1, true) then
                table.insert(filtered, note)
            else
                -- Fall back to alias matching
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
        -- Normalize score to 0-9999 range for cmp sorting (higher score = better match)
        -- Sort text format: "{score}_{label}" allows cmp to sort by score then alphabetically
        local score = score_data and score_data.score or 0
        return {
            label = note.title or note.path,
            kind = "Variable", -- Controls icon and sorting in completion menu
            sortText = string.format("%05d_%s", 9999 - score, note.title or note.path),
            filterText = note.title or note.path,
            detail = note.path,
            data = { path = note.path, note = note },
        }
    end

    --- Complete function for nvim-cmp
    ---@param completion_ctx table Completion context from cmp with before_line, cur_line, col
    ---@param callback fun(result: {items: table}) Callback invoked with completion result
    function source.complete(completion_ctx, callback)
        local result = { items = {} }

        -- All callback invocations are wrapped in pcall to gracefully handle callback errors
        -- This allows the completion pipeline to continue even if user-provided callbacks fail

        if not completion_ctx or type(completion_ctx) ~= "table" then
            if callback then
                pcall(function()
                    callback(result)
                end)
            end
            return
        end

        local before_line = completion_ctx.before_line or completion_ctx.cur_line or ""
        local col = completion_ctx.col or 0

        -- Detect wiki link context (e.g., "[[note_query")
        local is_wiki, query = is_wiki_link_context(before_line, col)

        if not is_wiki then
            if callback then
                pcall(function()
                    callback(result)
                end)
            end
            return
        end

        -- Get vault notes
        local notes = {}
        if not (ctx.vault_catalog and type(ctx.vault_catalog.list_notes) == "function") then
            report_error("cmp source: vault_catalog.list_notes is unavailable")
            if callback then
                pcall(function()
                    callback(result)
                end)
            end
            return
        end

        local ok_notes, listed = pcall(ctx.vault_catalog.list_notes)
        if not ok_notes then
            report_error("cmp source: list_notes failed: " .. tostring(listed))
            if callback then
                pcall(function()
                    callback(result)
                end)
            end
            return
        end
        if type(listed) ~= "table" then
            report_error("cmp source: list_notes returned invalid result")
            if callback then
                pcall(function()
                    callback(result)
                end)
            end
            return
        end
        notes = listed

        if #notes == 0 then
            if callback then
                pcall(function()
                    callback(result)
                end)
            end
            return
        end

        -- Filter notes by query string (title and alias matching)
        local filtered = filter_candidates(notes, query)

        -- Rank candidates by relevance score
        local ranked = filtered
        if ctx.search_ranking and type(ctx.search_ranking.score_candidates) == "function" then
            local ok_ranked, scored = pcall(ctx.search_ranking.score_candidates, query, filtered)
            if not ok_ranked then
                report_error("cmp source: ranking failed: " .. tostring(scored))
            elseif type(scored) == "table" then
                ranked = scored
            else
                report_error("cmp source: ranking returned invalid result")
            end
        end

        -- Convert ranked results to completion items
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
