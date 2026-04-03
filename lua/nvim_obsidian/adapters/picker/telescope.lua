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

local function has_select()
    return vim and vim.ui and type(vim.ui.select) == "function"
end

local function load_telescope_for_custom_picker()
    local ok_pickers, pickers = pcall(require, "telescope.pickers")
    local ok_finders, finders = pcall(require, "telescope.finders")
    local ok_config, config = pcall(require, "telescope.config")
    local ok_actions, actions = pcall(require, "telescope.actions")
    local ok_state, action_state = pcall(require, "telescope.actions.state")

    if not (ok_pickers and ok_finders and ok_config and ok_actions and ok_state) then
        return nil
    end

    return {
        pickers = pickers,
        finders = finders,
        config = config,
        actions = actions,
        action_state = action_state,
    }
end

local function load_telescope_builtin()
    local ok, builtin = pcall(require, "telescope.builtin")
    if not ok then
        return nil
    end
    return builtin
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then
        report_error("adapter boundary error: expected callable function")
        return nil
    end
    local ok, a, b = pcall(fn, ...)
    if not ok then
        report_error("adapter boundary error: callback failed: " .. tostring(a))
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

local function trim(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(text)
    return string.lower(trim(text))
end

local function path_for_display(candidate)
    if type(candidate) ~= "table" then
        return ""
    end
    local relpath = tostring(candidate.relpath or "")
    if relpath ~= "" then
        return relpath
    end
    return tostring(candidate.path or "")
end

local function alias_exact_match(candidate, query)
    if type(candidate) ~= "table" or type(candidate.aliases) ~= "table" then
        return nil
    end

    local q = lower(query)
    if q == "" then
        return nil
    end

    for _, alias in ipairs(candidate.aliases) do
        if type(alias) == "string" and lower(alias) == q then
            return alias
        end
    end

    return nil
end

local function label_for_item(item, base_label, query)
    if type(item) ~= "table" then
        return tostring(base_label or "")
    end

    local candidate = item.candidate
    local alias = alias_exact_match(candidate, query)
    if not alias then
        return tostring(base_label or "")
    end

    local path = path_for_display(candidate)
    if path == "" then
        return alias
    end

    return alias .. " -> " .. path
end

local function build_omni_ordinal(item, label)
    local candidate = type(item) == "table" and item.candidate or nil
    local aliases = {}
    local title = ""
    local relpath = ""
    local path = ""

    if type(candidate) == "table" then
        title = tostring(candidate.title or "")
        relpath = tostring(candidate.relpath or "")
        path = tostring(candidate.path or "")
        if type(candidate.aliases) == "table" then
            for _, alias in ipairs(candidate.aliases) do
                if type(alias) == "string" and alias ~= "" then
                    table.insert(aliases, alias)
                end
            end
        end
    end

    local has_rich_metadata = #aliases > 0 or title ~= "" or relpath ~= ""
    local parts = {}

    local function append_part(value)
        if type(value) == "string" and value ~= "" then
            table.insert(parts, value)
        end
    end

    -- Keep aliases first in ordinal so exact alias typing is strongly favored by fuzzy sort.
    append_part(table.concat(aliases, " "))
    append_part(title)
    append_part(relpath)
    if has_rich_metadata then
        append_part(path)
    end
    append_part(tostring(label or ""))

    return table.concat(parts, " ")
end

local function build_disambiguation_ordinal(match)
    local path = ""
    local title = ""
    if type(match) == "table" then
        path = tostring(match.path or "")
        title = tostring(match.title or "")
    end

    if title ~= "" then
        return title .. " " .. path
    end

    return path
end

local function open_telescope_disambiguation(matches, prompt_title, opts)
    local telescope = load_telescope_for_custom_picker()
    if not telescope then
        return nil
    end

    opts = type(opts) == "table" and opts or {}

    local items = {}
    local match_map = {}

    for _, item in ipairs(matches) do
        if type(item) == "table" and type(item.path) == "string" and item.path ~= "" then
            local idx = #match_map + 1
            table.insert(items, {
                kind = "item",
                idx = idx,
                label = tostring(item.title or "(untitled)") .. " -> " .. item.path,
                ordinal = build_disambiguation_ordinal(item),
            })
            match_map[idx] = item
        end
    end

    if #items == 0 then
        return {
            action = "cancel",
        }
    end

    local picked = nil
    local opened = false
    telescope.pickers.new({}, {
        prompt_title = prompt_title,
        finder = telescope.finders.new_table({
            results = items,
            entry_maker = function(entry)
                local filename = ""
                if entry.kind == "item" and type(entry.idx) == "number" then
                    local mapped = match_map[entry.idx]
                    if type(mapped) == "table" and type(mapped.path) == "string" then
                        filename = mapped.path
                    end
                end

                return {
                    value = entry,
                    display = entry.label,
                    ordinal = entry.ordinal,
                    filename = filename,
                    path = filename,
                }
            end,
        }),
        sorter = telescope.config.values.generic_sorter({}),
        previewer = telescope.config.values.file_previewer({}),
        attach_mappings = function(prompt_bufnr, map)
            telescope.actions.select_default:replace(function()
                local selected = telescope.action_state.get_selected_entry()
                local value = selected and selected.value or nil
                local selected_path = nil
                if type(value) == "table" and value.kind == "item" and type(value.idx) == "number" then
                    picked = match_map[value.idx]
                    if picked then
                        selected_path = picked.path
                    end
                end
                telescope.actions.close(prompt_bufnr)

                if selected_path and type(opts.open_path) == "function" then
                    local run_open = function()
                        local ok, result = pcall(opts.open_path, selected_path, picked)
                        opened = ok == true and result == true
                    end

                    if vim and type(vim.schedule) == "function" then
                        vim.schedule(run_open)
                    else
                        run_open()
                    end
                end
            end)

            return true
        end,
    }):find()

    if not picked then
        return {
            action = "cancel",
        }
    end

    if opened then
        return {
            action = "opened",
            item = picked,
            path = picked.path,
        }
    end

    return {
        action = "open",
        item = picked,
        path = picked.path,
    }
end

function M._prepare_candidates(ctx, notes)
    if type(notes) ~= "table" then
        report_error("telescope _prepare_candidates received invalid notes payload")
        return {}, {}
    end

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
        local telescope = load_telescope_for_custom_picker()
        if not telescope then
            report_error("ObsidianOmni requires telescope.nvim to be available")
            return { action = "cancel" }
        end

        local entries = {}
        local item_map = {}
        for _, item in ipairs(ctx.items) do
            local label = (type(item) == "table" and tostring(item.label or "")) or ""
            if label ~= "" then
                local idx = #item_map + 1
                table.insert(entries, {
                    kind = "item",
                    idx = idx,
                    label = label,
                    ordinal = build_omni_ordinal(item, label),
                })
                item_map[idx] = item
            end
        end

        if ctx.allow_create then
            local create_label = "+ Create: " .. tostring(ctx.query or "")
            table.insert(entries, {
                kind = "create",
                label = create_label,
                ordinal = create_label,
            })
        end

        if #entries == 0 then
            return { action = "cancel" }
        end

        local prompt_title = "Obsidian Omni"
        local query = tostring(ctx.query or "")

        local function current_prompt_query()
            local prompt_query = query
            if telescope.action_state and type(telescope.action_state.get_current_line) == "function" then
                local current_line = telescope.action_state.get_current_line()
                if type(current_line) == "string" then
                    prompt_query = current_line
                end
            end
            return prompt_query
        end

        telescope.pickers.new({}, {
            prompt_title = prompt_title,
            finder = telescope.finders.new_table({
                results = entries,
                entry_maker = function(entry)
                    local filename = ""
                    if entry.kind == "item" and type(entry.idx) == "number" then
                        local mapped = item_map[entry.idx]
                        local candidate = mapped and mapped.candidate or nil
                        local path = candidate and candidate.path or nil
                        if type(path) == "string" and path ~= "" then
                            filename = path
                        end
                    end
                    return {
                        value = entry,
                        display = function()
                            if entry.kind ~= "item" or type(entry.idx) ~= "number" then
                                return entry.label
                            end

                            local mapped = item_map[entry.idx]
                            local prompt_query = query
                            if telescope.action_state and type(telescope.action_state.get_current_line) == "function" then
                                local current_line = telescope.action_state.get_current_line()
                                if type(current_line) == "string" then
                                    prompt_query = current_line
                                end
                            end

                            return label_for_item(mapped, entry.label, prompt_query)
                        end,
                        ordinal = entry.ordinal,
                        filename = filename,
                        path = filename,
                    }
                end,
            }),
            sorter = telescope.config.values.generic_sorter({}),
            previewer = telescope.config.values.file_previewer({}),
            attach_mappings = function(prompt_bufnr, map)
                local function trigger_open(item)
                    telescope.actions.close(prompt_bufnr)
                    if type(ctx.on_open) == "function" then
                        pcall(ctx.on_open, item)
                    end
                end

                local function trigger_create()
                    telescope.actions.close(prompt_bufnr)
                    if type(ctx.on_create) == "function" then
                        pcall(ctx.on_create, current_prompt_query())
                    end
                end

                telescope.actions.select_default:replace(function()
                    local selected = telescope.action_state.get_selected_entry()
                    local value = selected and selected.value or nil
                    if type(value) ~= "table" then
                        telescope.actions.close(prompt_bufnr)
                        return
                    end

                    if value.kind == "create" then
                        trigger_create()
                        return
                    end

                    if value.kind == "item" and type(value.idx) == "number" then
                        local item = item_map[value.idx]
                        if item then
                            trigger_open(item)
                            return
                        end
                    end

                    telescope.actions.close(prompt_bufnr)
                end)

                if ctx.allow_force_create then
                    local force_key = tostring(((ctx.config or {}).force_create_key) or "<C-x>")
                    map("i", force_key, function()
                        trigger_create()
                    end)
                    map("n", force_key, function()
                        trigger_create()
                    end)
                end

                return true
            end,
        }):find()

        return { action = "deferred" }
    end

    -- Legacy/simple mode used by existing unit tests.
    local notes_fn = ctx and ctx.vault_catalog and ctx.vault_catalog.list_notes
    if type(notes_fn) ~= "function" then
        report_error("ObsidianOmni adapter: vault_catalog.list_notes is required")
        return false
    end

    local notes = safe_call(notes_fn)
    if type(notes) ~= "table" then
        report_error("ObsidianOmni adapter: list_notes returned invalid result")
        return false
    end
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
    local result = open_telescope_disambiguation(source_matches,
        payload_mode and "Backlinks" or "Disambiguate link target",
        payload_mode and { open_path = matches.open_path } or nil)
    if result == nil then
        if payload_mode then
            return { action = "cancel" }
        end
        return false
    end

    if payload_mode then
        return result
    end

    return result.action == "open"
end

function M.open_search(opts)
    opts = opts or {}
    local builtin = load_telescope_builtin()
    if not builtin then
        report_error("ObsidianSearch requires telescope.nvim to be available")
        return false
    end

    local root = opts.root
    if type(root) ~= "string" or root == "" then
        report_error("ObsidianSearch adapter: root must be a non-empty string")
        return false
    end
    local query = tostring(opts.query or "")
    local live_grep_opts = { cwd = root }
    if query ~= "" then
        live_grep_opts.default_text = query
    end

    local ok = pcall(builtin.live_grep, live_grep_opts)
    if not ok then
        report_error("ObsidianSearch adapter: failed to open Telescope live_grep")
        return false
    end

    return true
end

return M
