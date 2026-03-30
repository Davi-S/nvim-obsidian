---@class CmpCompletionSource
---@field complete fun(ctx: table, callback: fun(result: table))
---@field resolve fun(item: table, callback: fun(item: table))
---@field display_name string
---@field _ctx table

local M = {}

local function is_absolute_path(path)
    if type(path) ~= "string" then
        return false
    end
    if path:match("^/") then
        return true
    end
    if path:match("^%a:[/\\]") then
        return true
    end
    return false
end

local function join_path(base, leaf)
    local b = tostring(base or ""):gsub("\\", "/"):gsub("//+", "/")
    local l = tostring(leaf or ""):gsub("\\", "/"):gsub("^/+", "")
    if b == "" then
        return l
    end
    if b:sub(-1) == "/" then
        return b .. l
    end
    return b .. "/" .. l
end

local function trim(text)
    if type(text) ~= "string" then
        return nil
    end
    local out = text:gsub("^%s+", ""):gsub("%s+$", "")
    if out == "" then
        return nil
    end
    return out
end

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

    local function split_note_and_anchor(query)
        local q = tostring(query or "")
        local hash_pos = q:find("#", 1, true)
        if not hash_pos then
            return {
                mode = "note",
                note_query = q,
                anchor_query = "",
                is_block = false,
            }
        end

        local note_query = q:sub(1, hash_pos - 1)
        local raw_anchor = q:sub(hash_pos + 1)
        local is_block = raw_anchor:sub(1, 1) == "^"
        local anchor_query = raw_anchor
        if is_block then
            anchor_query = raw_anchor:sub(2)
        end

        return {
            mode = "anchor",
            note_query = note_query,
            anchor_query = anchor_query,
            is_block = is_block,
        }
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

    local function find_target_note(notes, note_query)
        local token = trim(note_query)
        if not token then
            return nil
        end

        if ctx.vault_catalog and type(ctx.vault_catalog.find_by_identity_token) == "function" then
            local ok_lookup, lookup = pcall(ctx.vault_catalog.find_by_identity_token, token)
            if ok_lookup and type(lookup) == "table" then
                local exact = type(lookup.exact_matches) == "table" and lookup.exact_matches or {}
                if #exact > 0 then
                    return exact[1]
                end

                local exact_ci = type(lookup.exact_ci_matches) == "table" and lookup.exact_ci_matches or {}
                if #exact_ci > 0 then
                    return exact_ci[1]
                end

                local fuzzy = type(lookup.fuzzy_matches) == "table" and lookup.fuzzy_matches or {}
                if #fuzzy > 0 then
                    return fuzzy[1]
                end
            end
        end

        local filtered = filter_candidates(notes, token)
        if #filtered == 0 then
            return nil
        end
        return filtered[1]
    end

    local function read_note_markdown(note)
        if type(note) ~= "table" then
            return nil
        end
        if type(ctx.fs_io) ~= "table" or type(ctx.fs_io.read_file) ~= "function" then
            return nil
        end

        local relpath = note.path
        if type(relpath) ~= "string" or relpath == "" then
            return nil
        end

        local fullpath = relpath
        if not is_absolute_path(fullpath) then
            local root = ctx.config and ctx.config.vault_root
            if type(root) ~= "string" or root == "" then
                return nil
            end
            fullpath = join_path(root, relpath)
        end

        local ok_read, content = pcall(ctx.fs_io.read_file, fullpath)
        if not ok_read or type(content) ~= "string" then
            return nil
        end
        return content
    end

    local function extract_note_anchors(markdown)
        if type(markdown) ~= "string" then
            return { headings = {}, blocks = {} }
        end

        local headings = {}
        local blocks = {}
        local seen_headings = {}
        local seen_blocks = {}

        for line in (markdown .. "\n"):gmatch("(.-)\n") do
            local heading = line:match("^%s*#+%s+(.+)%s*$")
            if heading then
                heading = heading:gsub("%s+#+%s*$", "")
                heading = trim(heading)
                if heading and not seen_headings[heading] then
                    seen_headings[heading] = true
                    table.insert(headings, heading)
                end
            end

            for block_id in line:gmatch("%^(%w[%w%-%_]*)") do
                if block_id and not seen_blocks[block_id] then
                    seen_blocks[block_id] = true
                    table.insert(blocks, block_id)
                end
            end
        end

        return {
            headings = headings,
            blocks = blocks,
        }
    end

    local function format_anchor_item(note, value, is_block)
        local anchor_prefix = is_block and "#^" or "#"
        local item_label = anchor_prefix .. value
        local note_label = note.title or note.path
        return {
            label = item_label,
            kind = "Variable",
            sortText = item_label,
            filterText = value,
            insertText = is_block and ("^" .. value) or value,
            detail = note.path,
            data = {
                path = note.path,
                note = note,
                anchor = value,
                anchor_type = is_block and "block" or "heading",
                note_label = note_label,
            },
        }
    end

    local function build_anchor_items(notes, anchor_ctx)
        local target = find_target_note(notes, anchor_ctx.note_query)
        if not target then
            return {}
        end

        local markdown = read_note_markdown(target)
        local extracted = extract_note_anchors(markdown)

        local values = anchor_ctx.is_block and extracted.blocks or extracted.headings
        local query = (anchor_ctx.anchor_query or ""):lower()
        local items = {}

        for _, value in ipairs(values) do
            if query == "" or value:lower():find(query, 1, true) then
                table.insert(items, format_anchor_item(target, value, anchor_ctx.is_block))
            end
        end

        return items
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

        local query_ctx = split_note_and_anchor(query)
        if query_ctx.mode == "anchor" then
            result.items = build_anchor_items(notes, query_ctx)
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
