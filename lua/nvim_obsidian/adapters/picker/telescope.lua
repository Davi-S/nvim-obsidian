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
                    ordinal = string.lower(label),
                })
                item_map[idx] = item
            end
        end

        if ctx.allow_create then
            local create_label = "+ Create: " .. tostring(ctx.query or "")
            table.insert(entries, {
                kind = "create",
                label = create_label,
                ordinal = string.lower(create_label),
            })
        end

        if #entries == 0 then
            return { action = "cancel" }
        end

        local prompt_title = "Obsidian Omni"
        local query = tostring(ctx.query or "")

        telescope.pickers.new({}, {
            prompt_title = prompt_title,
            finder = telescope.finders.new_table({
                results = entries,
                entry_maker = function(entry)
                    local filename = nil
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
                local function trigger_open(item)
                    telescope.actions.close(prompt_bufnr)
                    if type(ctx.on_open) == "function" then
                        pcall(ctx.on_open, item)
                    end
                end

                local function trigger_create()
                    telescope.actions.close(prompt_bufnr)
                    if type(ctx.on_create) == "function" then
                        pcall(ctx.on_create, query)
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
