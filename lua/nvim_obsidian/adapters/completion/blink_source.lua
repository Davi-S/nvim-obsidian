---@class BlinkCompletionSource
---@field display_name string
---@field opts table

local M = {}

local completion_item_kinds = (vim and vim.lsp and vim.lsp.protocol and vim.lsp.protocol.CompletionItemKind) or {}
local VARIABLE_KIND = completion_item_kinds.Variable or 6

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

local function deep_copy(value)
    if vim and type(vim.deepcopy) == "function" then
        return vim.deepcopy(value)
    end
    return value
end

local function safe_callback(callback, payload)
    if type(callback) ~= "function" then
        return
    end

    pcall(function()
        callback(payload)
    end)
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

local function get_container()
    local ok, obsidian = pcall(require, "nvim_obsidian")
    if not ok or type(obsidian) ~= "table" or type(obsidian.get_container) ~= "function" then
        return nil
    end

    local ok_container, container = pcall(obsidian.get_container)
    if not ok_container then
        return nil
    end

    return container
end

local function get_cursor_context(ctx)
    local line = nil
    local row = nil
    local col = nil

    if type(ctx) == "table" then
        line = ctx.line or ctx.before_line or ctx.cur_line or ctx.text
        row = ctx.row or ctx.cursor_row
        col = ctx.col or ctx.cursor_col

        if col == nil and type(ctx.cursor) == "table" then
            row = row or ctx.cursor[1]
            col = ctx.cursor[2]
        end
    end

    if (line == nil or row == nil or col == nil) and vim and vim.api then
        if line == nil and type(vim.api.nvim_get_current_line) == "function" then
            local ok_line, current_line = pcall(vim.api.nvim_get_current_line)
            if ok_line and type(current_line) == "string" then
                line = current_line
            end
        end

        if (row == nil or col == nil) and type(vim.api.nvim_win_get_cursor) == "function" then
            local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
            if ok_cursor and type(cursor) == "table" then
                row = row or tonumber(cursor[1]) or 1
                col = col or tonumber(cursor[2]) or 0
            end
        end
    end

    if type(line) ~= "string" then
        line = ""
    end

    row = tonumber(row) or 1
    col = tonumber(col) or 0

    local before_line = line:sub(1, col)
    return {
        line = line,
        before_line = before_line,
        row = row,
        col = col,
    }
end

local function make_text_edit(row, start_col, end_col, new_text)
    return {
        newText = new_text,
        range = {
            start = {
                line = math.max((tonumber(row) or 1) - 1, 0),
                character = math.max((tonumber(start_col) or 1) - 1, 0),
            },
            ["end"] = {
                line = math.max((tonumber(row) or 1) - 1, 0),
                character = math.max((tonumber(end_col) or 0), 0),
            },
        },
    }
end

local function get_trigger_context(before_line, col)
    if type(before_line) ~= "string" or col < 2 then
        return false, "", nil, nil
    end

    local wiki_start = before_line:find("[[", 1, true)
    if not wiki_start then
        return false, "", nil, nil
    end

    local query_start = wiki_start + 2
    if query_start > col then
        return true, "", col + 1, wiki_start
    end

    local query = before_line:sub(query_start, col)
    if query:find("]]", 1, true) then
        return false, query, nil, nil
    end

    return true, query, query_start, wiki_start
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
        hash_pos = hash_pos,
    }
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

local function find_target_note(container, notes, note_query)
    local token = trim(note_query)
    if not token then
        return nil
    end

    if container and container.vault_catalog and type(container.vault_catalog.find_by_identity_token) == "function" then
        local ok_lookup, lookup = pcall(container.vault_catalog.find_by_identity_token, token)
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

local function read_note_markdown(container, note)
    if type(note) ~= "table" then
        return nil
    end

    local fs_io = container and container.fs_io
    if type(fs_io) ~= "table" or type(fs_io.read_file) ~= "function" then
        return nil
    end

    local relpath = note.path
    if type(relpath) ~= "string" or relpath == "" then
        return nil
    end

    local fullpath = relpath
    if not is_absolute_path(fullpath) then
        local root = container.config and container.config.vault_root
        if type(root) ~= "string" or root == "" then
            return nil
        end
        fullpath = join_path(root, relpath)
    end

    local ok_read, content = pcall(fs_io.read_file, fullpath)
    if not ok_read or type(content) ~= "string" then
        return nil
    end
    return content
end

local function extract_note_anchors(markdown)
    if type(markdown) ~= "string" then
        return {
            headings = {},
            blocks = {},
        }
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

local function format_note_item(note, score_data, text_edit)
    local label = note.title or note.path
    local score = score_data and score_data.score or 0
    return {
        label = label,
        kind = VARIABLE_KIND,
        sortText = string.format("%05d_%s", 9999 - score, label),
        filterText = label,
        detail = note.path,
        textEdit = text_edit,
        insertTextFormat = 1,
        data = {
            path = note.path,
            note = note,
        },
    }
end

local function format_anchor_item(note, value, is_block, text_edit)
    local anchor_prefix = is_block and "#^" or "#"
    local label = anchor_prefix .. value
    return {
        label = label,
        kind = VARIABLE_KIND,
        sortText = label,
        filterText = value,
        detail = note.path,
        textEdit = text_edit,
        insertTextFormat = 1,
        data = {
            path = note.path,
            note = note,
            anchor = value,
            anchor_type = is_block and "block" or "heading",
            note_label = note.title or note.path,
        },
    }
end

local function build_anchor_items(container, notes, anchor_ctx, row, col, query_start, query)
    local target = find_target_note(container, notes, anchor_ctx.note_query)
    if not target then
        return {}
    end

    local markdown = read_note_markdown(container, target)
    local extracted = extract_note_anchors(markdown)

    local values = anchor_ctx.is_block and extracted.blocks or extracted.headings
    local anchor_query = (anchor_ctx.anchor_query or ""):lower()
    local items = {}
    local replacement_start = query_start + anchor_ctx.hash_pos
    local new_text_prefix = anchor_ctx.is_block and "^" or ""

    for _, value in ipairs(values) do
        if anchor_query == "" or value:lower():find(anchor_query, 1, true) then
            local text_edit = make_text_edit(row, replacement_start, col, new_text_prefix .. value)
            table.insert(items, format_anchor_item(target, value, anchor_ctx.is_block, text_edit))
        end
    end

    return items
end

local function build_note_items(notes, score_data, row, col, query_start)
    local items = {}
    for _, scored in ipairs(score_data) do
        local note = scored.note or scored
        local text_edit = make_text_edit(row, query_start, col, note.title or note.path)
        table.insert(items, format_note_item(note, scored, text_edit))
    end
    return items
end

function M.get_trigger_characters()
    return { "[", "#" }
end

function M.resolve_completion_item(item, callback)
    if type(item) ~= "table" then
        return
    end

    local resolved = deep_copy(item)
    if resolved.data and resolved.data.path then
        resolved.detail = resolved.data.path
    end

    safe_callback(callback, resolved)
end

function M.new(opts)
    local source = {
        display_name = "Obsidian",
        opts = opts or {},
    }

    function source:enabled()
        return get_container() ~= nil
    end

    function source:get_trigger_characters()
        return M.get_trigger_characters()
    end

    function source:get_completions(ctx, callback)
        local result = {
            items = {},
            is_incomplete_backward = false,
            is_incomplete_forward = false,
        }

        local container = get_container()
        if not container then
            report_error("blink source: nvim-obsidian is not initialized")
            safe_callback(callback, result)
            return function() end
        end

        local cursor_ctx = get_cursor_context(ctx)
        local is_wiki, query, query_start = get_trigger_context(cursor_ctx.before_line, cursor_ctx.col)
        if not is_wiki then
            safe_callback(callback, result)
            return function() end
        end

        if type(container.vault_catalog) ~= "table" or type(container.vault_catalog.list_notes) ~= "function" then
            report_error("blink source: vault_catalog.list_notes is unavailable")
            safe_callback(callback, result)
            return function() end
        end

        local ok_notes, listed = pcall(container.vault_catalog.list_notes)
        if not ok_notes then
            report_error("blink source: list_notes failed: " .. tostring(listed))
            safe_callback(callback, result)
            return function() end
        end

        if type(listed) ~= "table" then
            report_error("blink source: list_notes returned invalid result")
            safe_callback(callback, result)
            return function() end
        end

        if #listed == 0 then
            safe_callback(callback, result)
            return function() end
        end

        local query_ctx = split_note_and_anchor(query)
        if query_ctx.mode == "anchor" then
            result.items = build_anchor_items(container, listed, query_ctx, cursor_ctx.row, cursor_ctx.col, query_start,
                query)
            safe_callback(callback, deep_copy(result))
            return function() end
        end

        local filtered = filter_candidates(listed, query)
        local ranked = filtered

        if container.search_ranking and type(container.search_ranking.score_candidates) == "function" then
            local ok_ranked, scored = pcall(container.search_ranking.score_candidates, query, filtered)
            if not ok_ranked then
                report_error("blink source: ranking failed: " .. tostring(scored))
            elseif type(scored) == "table" then
                ranked = scored
            else
                report_error("blink source: ranking returned invalid result")
            end
        end

        result.items = build_note_items(filtered, ranked, cursor_ctx.row, cursor_ctx.col, query_start)
        safe_callback(callback, deep_copy(result))
        return function() end
    end

    function source:resolve(item, callback)
        M.resolve_completion_item(item, callback)
    end

    return source
end

M.create_source = M.new

return M
