---@diagnostic disable: undefined-global

local M = {}

local function create_user_command(name, fn, opts)
    if not vim or not vim.api or not vim.api.nvim_create_user_command then
        return
    end
    local merged = vim.tbl_deep_extend("force", { force = true }, opts or {})
    vim.api.nvim_create_user_command(name, fn, merged)
end

local function get_current_line_and_col()
    if not vim or not vim.api then
        return nil, nil
    end
    if type(vim.api.nvim_get_current_line) ~= "function" or type(vim.api.nvim_win_get_cursor) ~= "function" then
        return nil, nil
    end

    local ok_line, line = pcall(vim.api.nvim_get_current_line)
    local ok_cur, cur = pcall(vim.api.nvim_win_get_cursor, 0)
    if not ok_line or not ok_cur or type(line) ~= "string" or type(cur) ~= "table" then
        return nil, nil
    end

    local col = tonumber(cur[2])
    if col == nil then
        return nil, nil
    end

    return line, col
end

local function error_to_notification(ctx, error_obj)
    if not ctx or not ctx.adapters or not ctx.adapters.notifications then
        return
    end

    local code = error_obj.code
    local msg = error_obj.message or "Unknown error"

    if code == "invalid_input" then
        ctx.adapters.notifications.warn(msg)
    elseif code == "parse_failure" then
        ctx.adapters.notifications.warn(msg)
    else
        -- internal_error, not_found, ambiguous_target, missing_anchor, etc
        ctx.adapters.notifications.error(msg)
    end
end

local function trim(s)
    if type(s) ~= "string" then return nil end
    local out = s:gsub("^%s+", ""):gsub("%s+$", "")
    if out == "" then return nil end
    return out
end

local function strip_accents(text)
    local s = tostring(text or "")
    local replacements = {
        ["á"] = "a",
        ["à"] = "a",
        ["ã"] = "a",
        ["â"] = "a",
        ["ä"] = "a",
        ["é"] = "e",
        ["è"] = "e",
        ["ê"] = "e",
        ["ë"] = "e",
        ["í"] = "i",
        ["ì"] = "i",
        ["î"] = "i",
        ["ï"] = "i",
        ["ó"] = "o",
        ["ò"] = "o",
        ["õ"] = "o",
        ["ô"] = "o",
        ["ö"] = "o",
        ["ú"] = "u",
        ["ù"] = "u",
        ["û"] = "u",
        ["ü"] = "u",
        ["ç"] = "c",
    }
    for accented, base in pairs(replacements) do
        s = s:gsub(accented, base)
    end
    return s
end

local MONTH_INDEX = {
    january = 1,
    fevereiro = 2,
    february = 2,
    march = 3,
    marco = 3,
    april = 4,
    abril = 4,
    may = 5,
    maio = 5,
    june = 6,
    junho = 6,
    july = 7,
    julho = 7,
    august = 8,
    agosto = 8,
    september = 9,
    setembro = 9,
    october = 10,
    outubro = 10,
    november = 11,
    novembro = 11,
    december = 12,
    dezembro = 12,
    janeiro = 1,
}

local function iso_week_start(iso_year, iso_week)
    local jan4 = os.time({ year = iso_year, month = 1, day = 4, hour = 12 })
    local jan4_wday = tonumber(os.date("%u", jan4)) or 1
    local week1_monday = jan4 - ((jan4_wday - 1) * 86400)
    local target = week1_monday + ((iso_week - 1) * 7 * 86400)
    local dt = os.date("*t", target)
    return { year = dt.year, month = dt.month, day = dt.day }
end

local function parse_date_from_note_token(token, kind)
    local raw = tostring(token or "")
    if raw == "" then
        return nil
    end

    local lower = strip_accents(raw:lower())

    if kind == "daily" then
        local y, m, d = raw:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        if y and m and d then
            return { year = tonumber(y), month = tonumber(m), day = tonumber(d) }
        end

        local y2, month_name, d2 = lower:match("^(%d%d%d%d)%s+(%S+)%s+(%d%d?)")
        local month = month_name and MONTH_INDEX[month_name]
        if y2 and month and d2 then
            return { year = tonumber(y2), month = month, day = tonumber(d2) }
        end
    end

    if kind == "weekly" then
        local y, w = raw:match("^(%d%d%d%d)%-[Ww](%d%d)$")
        if y and w then
            return iso_week_start(tonumber(y), tonumber(w))
        end

        local y2, w2 = lower:match("^(%d%d%d%d)%s+[Ww]eek%s+(%d%d?)$")
        if y2 and w2 then
            return iso_week_start(tonumber(y2), tonumber(w2))
        end

        local y3, w3 = lower:match("^(%d%d%d%d)%s+semana%s+(%d%d?)$")
        if y3 and w3 then
            return iso_week_start(tonumber(y3), tonumber(w3))
        end
    end

    if kind == "monthly" then
        local y, m = raw:match("^(%d%d%d%d)%-(%d%d)$")
        if y and m then
            return { year = tonumber(y), month = tonumber(m), day = 1 }
        end

        local y2, month_name = lower:match("^(%d%d%d%d)%s+(%S+)$")
        local month = month_name and MONTH_INDEX[month_name]
        if y2 and month then
            return { year = tonumber(y2), month = month, day = 1 }
        end
    end

    if kind == "yearly" then
        local y = raw:match("^(%d%d%d%d)$")
        if y then
            return { year = tonumber(y), month = 1, day = 1 }
        end
    end

    return nil
end

local function split_lines(text)
    local out = {}
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
end

local get_current_buffer_path

local function current_note_token()
    local path = get_current_buffer_path()
    if not path then
        return nil
    end
    local normalized = tostring(path):gsub("\\", "/")
    local filename = normalized:match("([^/]+)$")
    if not filename then
        return nil
    end
    local token = filename:gsub("%.md$", "")
    token = trim(token)
    if token == "" then
        return nil
    end
    return token
end

local function resolve_journal_kind(ctx)
    local token = current_note_token()
    if type(ctx.journal) ~= "table" or type(ctx.journal.classify_input) ~= "function" or not token then
        return "daily"
    end

    local classified = ctx.journal.classify_input(token, os.time())
    local kind = tostring((classified and classified.kind) or "daily")
    if kind == "none" then
        return "daily"
    end
    return kind
end

local function current_note_anchor_date(kind)
    local token = current_note_token()
    if not token then
        return os.date("*t")
    end

    local parsed = parse_date_from_note_token(token, kind)
    if type(parsed) == "table" then
        return parsed
    end

    return os.date("*t")
end

local function journal_token_for(ctx, kind, direction)
    local journal = ctx.journal
    if type(journal) ~= "table" or type(journal.compute_adjacent) ~= "function" then
        return os.date("%Y-%m-%d", os.time())
    end

    local anchor_date = current_note_anchor_date(kind)
    local adjacent = journal.compute_adjacent(kind, anchor_date, direction)
    local target_date = (adjacent and adjacent.target_date) or os.date("*t")

    if type(ctx.resolve_journal_title) == "function" then
        local resolved = ctx.resolve_journal_title(kind, target_date)
        if type(resolved) == "string" and resolved ~= "" then
            return resolved
        end
    end

    if type(journal.build_title) == "function" then
        local built = journal.build_title(kind, target_date, (ctx.config or {}).locale)
        local title = tostring((built and built.title) or "")
        if title ~= "" then
            return title
        end
    end

    return os.date("%Y-%m-%d", os.time())
end

local function basename_without_extension(path)
    local normalized = tostring(path or ""):gsub("\\", "/")
    local filename = normalized:match("([^/]+)$")
    if type(filename) ~= "string" or filename == "" then
        return nil
    end
    return filename:gsub("%.md$", "")
end

local function build_journal_calendar_marks(ctx)
    local marks = {}
    local vault_catalog = ctx and (ctx.vault_catalog or (ctx.domains and ctx.domains.vault_catalog))
    local journal = ctx and (ctx.journal or (ctx.domains and ctx.domains.journal))

    if type(vault_catalog) ~= "table" or type(vault_catalog.list_notes) ~= "function" then
        return marks
    end

    local ok_notes, notes = pcall(vault_catalog.list_notes)
    if not ok_notes or type(notes) ~= "table" then
        return marks
    end

    for _, note in ipairs(notes) do
        if type(note) == "table" then
            local candidate = nil
            if type(note.title) == "string" and note.title ~= "" then
                candidate = note.title
            else
                candidate = basename_without_extension(note.path)
            end

            if type(candidate) == "string" and candidate ~= "" and type(journal) == "table" and type(journal.classify_input) == "function" then
                local classified = journal.classify_input(candidate, os.time())
                if type(classified) == "table" and classified.kind == "daily" then
                    local parsed = parse_date_from_note_token(candidate, "daily")
                    if type(parsed) == "table" then
                        local token = string.format("%04d-%02d-%02d", parsed.year, parsed.month, parsed.day)
                        marks[token] = {
                            path = note.path,
                            title = candidate,
                        }
                    end
                end
            end
        end
    end

    return marks
end

get_current_buffer_path = function()
    if not vim or not vim.api or type(vim.api.nvim_buf_get_name) ~= "function" then
        return nil
    end
    local ok, path = pcall(vim.api.nvim_buf_get_name, 0)
    if not ok then
        return nil
    end
    return trim(path)
end

local function register_obsidian_today(ctx)
    create_user_command("ObsidianToday", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.ensure_open_note then
            return
        end

        local kind = "daily"
        local today = os.date("*t")
        local token = nil

        if type(ctx.resolve_journal_title) == "function" then
            local resolved = ctx.resolve_journal_title(kind, today)
            if type(resolved) == "string" and resolved ~= "" then
                token = resolved
            end
        end

        if not token and type(ctx.journal) == "table" and type(ctx.journal.build_title) == "function" then
            local built = ctx.journal.build_title(kind, today, (ctx.config or {}).locale)
            local title = tostring((built and built.title) or "")
            if title ~= "" then
                token = title
            end
        end

        if not token then
            token = os.date("%Y-%m-%d")
        end

        local result = ctx.use_cases.ensure_open_note.execute(ctx, {
            title_or_token = token,
            create_if_missing = true,
            origin = "journal",
            journal_kind = kind,
            now = os.time(),
        })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        if result.created and ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info("Created today's note: " .. result.path)
        end
    end, { desc = "Open or create today's daily journal note" })
end

local function register_obsidian_next(ctx)
    create_user_command("ObsidianNext", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.ensure_open_note then
            return
        end

        local kind = resolve_journal_kind(ctx)
        local token = journal_token_for(ctx, kind, "next")
        local result = ctx.use_cases.ensure_open_note.execute(ctx, {
            title_or_token = token,
            create_if_missing = true,
            origin = "journal",
            journal_kind = kind,
            now = os.time(),
        })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end
    end, { desc = "Open or create next journal note in current context" })
end

local function register_obsidian_prev(ctx)
    create_user_command("ObsidianPrev", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.ensure_open_note then
            return
        end

        local kind = resolve_journal_kind(ctx)
        local token = journal_token_for(ctx, kind, "prev")
        local result = ctx.use_cases.ensure_open_note.execute(ctx, {
            title_or_token = token,
            create_if_missing = true,
            origin = "journal",
            journal_kind = kind,
            now = os.time(),
        })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end
    end, { desc = "Open or create previous journal note in current context" })
end

local function register_obsidian_omni(ctx)
    create_user_command("ObsidianOmni", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.search_open_create then
            return
        end

        local result = ctx.use_cases.search_open_create.execute(ctx, {
            query = "",
            allow_force_create = true,
        })

        if not result.ok then
            if result.error and result.error.code == "cancelled" then
                -- User cancelled picker, silent
                return
            end
            error_to_notification(ctx, result.error)
            return
        end

        if type(result.path) == "string" and result.path ~= "" and ctx.adapters and ctx.adapters.navigation then
            ctx.adapters.navigation.open_path(result.path)
        end

        if result.created and type(result.path) == "string" and result.path ~= "" and ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info("Created note: " .. result.path)
        end
    end, { desc = "Open note via Omni search/create" })
end

local function register_obsidian_follow(ctx)
    create_user_command("ObsidianFollow", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.follow_link then
            return
        end

        local buffer_path = get_current_buffer_path()
        local line, col = get_current_line_and_col()

        if not buffer_path or not line or col == nil then
            if ctx.adapters and ctx.adapters.notifications and ctx.adapters.notifications.warn then
                ctx.adapters.notifications.warn("ObsidianFollow unavailable: missing current buffer context")
            end
            return
        end

        local result = ctx.use_cases.follow_link.execute(ctx, {
            line = line,
            col = col,
            buffer_path = buffer_path,
        })

        if not result.ok then
            local error_code = result.error and result.error.code
            if error_code == "invalid_input" then
                if ctx.adapters and ctx.adapters.notifications then
                    ctx.adapters.notifications.warn("Cursor not on a valid wikilink")
                end
            elseif error_code == "ambiguous_target" then
                -- Picker should have been shown by use case; no-op here
                if ctx.adapters and ctx.adapters.notifications then
                    ctx.adapters.notifications.warn("Multiple matches for link. Use picker or be more specific.")
                end
            elseif error_code == "missing_anchor" then
                if ctx.adapters and ctx.adapters.notifications then
                    ctx.adapters.notifications.warn("Target note exists but heading/anchor not found")
                end
            else
                error_to_notification(ctx, result.error)
            end
            return
        end

        if ctx.adapters and ctx.adapters.navigation then
            ctx.adapters.navigation.open_path(result.path)
        end
    end, { desc = "Follow wikilink under cursor" })
end

local function register_obsidian_backlinks(ctx)
    create_user_command("ObsidianBacklinks", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.show_backlinks then
            return
        end

        local current_path = get_current_buffer_path()
        if not current_path then
            local notifications = ctx.adapters and ctx.adapters.notifications
            if notifications and notifications.warn then
                notifications.warn("Backlinks unavailable: current buffer has no path")
            end
            return
        end

        local result = ctx.use_cases.show_backlinks.execute(ctx, {
            buffer_path = current_path,
        })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        if result.match_count == 0 and ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info({
                command = "ObsidianBacklinks",
                message = "No backlinks found",
                target = current_path,
            })
        end
    end, { desc = "Show notes linking to current note" })
end

local function register_obsidian_search(ctx)
    create_user_command("ObsidianSearch", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.vault_search then
            return
        end

        local result = ctx.use_cases.vault_search.execute(ctx, {})
        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        if not result.selected and ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info({
                command = "ObsidianSearch",
                message = "No search result selected",
            })
        end
    end, { desc = "Vault-scoped text search via Telescope" })
end

local function register_obsidian_reindex(ctx)
    create_user_command("ObsidianReindex", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.reindex_sync then
            return
        end

        if ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info("Reindexing vault...")
        end

        local result = ctx.use_cases.reindex_sync.execute(ctx, { mode = "manual" })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        if ctx.adapters and ctx.adapters.notifications then
            local count = nil
            if type(result.stats) == "table" then
                count = result.stats.upserted or result.stats.scanned
            else
                count = result.reindexed_count
            end
            ctx.adapters.notifications.info("Reindex complete: " .. tostring(count or "unknown") .. " notes indexed")
        end
    end, { desc = "Explicitly rebuild vault index (full rescan)" })
end

local function register_obsidian_insert_template(ctx)
    create_user_command("ObsidianInsertTemplate", function(cmd)
        if not ctx or not ctx.use_cases or not ctx.use_cases.insert_template then
            return
        end

        local query = trim((cmd and cmd.args) or "")
        local result = ctx.use_cases.insert_template.execute(ctx, {
            query = query,
            now = os.time(),
        })

        if not result.ok then
            if ctx.adapters and ctx.adapters.notifications and result.error and result.error.code == "not_found" then
                ctx.adapters.notifications.warn({
                    command = "ObsidianInsertTemplate",
                    message = "Template not found",
                    target = query or "<picker>",
                    next_step = "Provide a template path or configure resolve_template_content",
                })
                return
            end

            error_to_notification(ctx, result.error)
            return
        end

        if ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info({
                command = "ObsidianInsertTemplate",
                message = "Template inserted",
                target = query,
            })
        end
    end, { desc = "Insert rendered template at cursor", nargs = "?" })
end

local function register_obsidian_calendar(ctx)
    -- Shared completion handler for calendar picker mode.
    --
    -- Why this helper exists:
    -- - We now expose picker mode through two command surfaces:
    --   1) :ObsidianCalendar pick (generic calendar command with explicit picker arg)
    --   2) :ObsidianJournalCalendar (secondary power-flow command dedicated to journal access)
    -- - Both flows must apply exactly the same journal open/create behavior.
    -- - Keeping this logic in one closure factory prevents subtle drift between commands.
    local function build_calendar_picker_on_finish(command_name)
        return function(payload)
            -- on_finish is invoked asynchronously by the calendar adapter when
            -- user interaction ends. Keep this callback lightweight and side-effect
            -- scoped to journal note resolution/opening.
            if type(payload) ~= "table" or payload.action ~= "selected" then
                return
            end

            local selected_kind = tostring(payload.selected_kind or "")
            if selected_kind ~= "daily" and selected_kind ~= "weekly" and selected_kind ~= "monthly" and selected_kind ~= "yearly" then
                return
            end

            local target_date = payload.date or payload.cursor_date
            if type(target_date) ~= "table" then
                return
            end

            if not ctx.use_cases.ensure_open_note or type(ctx.use_cases.ensure_open_note.execute) ~= "function" then
                return
            end

            local journal_title = nil
            if type(ctx.resolve_journal_title) == "function" then
                local resolved = ctx.resolve_journal_title(selected_kind, target_date)
                if type(resolved) == "string" and resolved ~= "" then
                    journal_title = resolved
                end
            end

            if not journal_title and type(ctx.journal) == "table" and type(ctx.journal.build_title) == "function" then
                local built = ctx.journal.build_title(selected_kind, target_date, (ctx.config or {}).locale)
                if type(built) == "table" and type(built.title) == "string" and built.title ~= "" then
                    journal_title = built.title
                end
            end

            if type(journal_title) ~= "string" or journal_title == "" then
                return
            end

            local open_result = ctx.use_cases.ensure_open_note.execute(ctx, {
                title_or_token = journal_title,
                create_if_missing = true,
                origin = "journal",
                journal_kind = selected_kind,
                now = os.time(),
            })

            if not open_result.ok and ctx.adapters and ctx.adapters.notifications then
                error_to_notification(ctx, open_result.error)
                return
            end

            if ctx.adapters and ctx.adapters.notifications then
                ctx.adapters.notifications.info({
                    command = command_name,
                    message = "Journal note opened",
                    target = journal_title,
                    next_step = "Use the calendar again to create another journal note family",
                })
            end
        end
    end

    -- Shared opener that centralizes adapter invocation contract.
    --
    -- This keeps both calendar commands aligned on:
    -- - UI variant
    -- - initial date seed
    -- - callback hookup
    local function open_calendar(mode, command_name, extra_request)
        local request = {
            mode = mode,
            ui_variant = "buffer",
            initial_date = os.date("*t"),
            on_finish = build_calendar_picker_on_finish(command_name),
        }

        if type(extra_request) == "table" then
            for key, value in pairs(extra_request) do
                request[key] = value
            end
        end

        return ctx.use_cases.open_date_picker.execute(ctx, {
            mode = request.mode,
            ui_variant = request.ui_variant,
            initial_date = request.initial_date,
            on_finish = request.on_finish,
            marks = request.marks,
        })
    end

    create_user_command("ObsidianCalendar", function(cmd)
        if not ctx or not ctx.use_cases or not ctx.use_cases.open_date_picker then
            return
        end

        -- MVP interface:
        -- :ObsidianCalendar           -> visualizer mode (default)
        -- :ObsidianCalendar pick      -> picker mode (returns selected date)
        --
        -- Keeping mode selection command-driven allows reviewers to validate both
        -- interaction contracts immediately while we still have only one UI variant.
        -- Parse optional mode argument.
        --
        -- Supported forms:
        -- - :ObsidianCalendar
        -- - :ObsidianCalendar visualizer
        -- - :ObsidianCalendar pick
        -- - :ObsidianCalendar picker
        local raw_args = trim((cmd and cmd.args) or "")
        local mode = "visualizer"
        if raw_args == "pick" or raw_args == "picker" then
            mode = "picker"
        elseif raw_args == "visualizer" then
            mode = "visualizer"
        end

        local result = open_calendar(mode, "ObsidianCalendar")

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        -- Non-blocking flow:
        -- command returns immediately after successful calendar open; final outcomes
        -- are delivered through on_finish callback above.
    end, {
        desc = "Open interactive calendar (visualizer or picker)",
        nargs = "?",
        complete = function()
            return { "pick", "picker", "visualizer" }
        end,
    })

    -- Secondary power-flow command for journal navigation/creation via calendar picker.
    --
    -- Product intent:
    -- - Keep :ObsidianToday/:ObsidianNext/:ObsidianPrev as primary directional flows.
    -- - Provide an explicit calendar-driven flow for users who want broad temporal access
    --   (daily/weekly/monthly/yearly) from one interaction surface.
    --
    -- UX intent:
    -- - No mode argument needed here: this command is always picker-first.
    -- - Keeps discoverability high without changing existing directional command behavior.
    create_user_command("ObsidianJournalCalendar", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.open_date_picker then
            return
        end

        local result = open_calendar("picker", "ObsidianJournalCalendar", {
            marks = build_journal_calendar_marks(ctx),
        })
        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end
    end, {
        desc = "Open journal calendar picker (secondary power flow)",
        nargs = 0,
    })
end

local function register_obsidian_render_dataview(ctx)
    create_user_command("ObsidianRenderDataview", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.render_query_blocks then
            return
        end

        if not vim or not vim.api or type(vim.api.nvim_get_current_buf) ~= "function" then
            if ctx.adapters and ctx.adapters.notifications and ctx.adapters.notifications.error then
                ctx.adapters.notifications.error("ObsidianRenderDataview unavailable: nvim buffer API is missing")
            end
            return
        end

        local ok_buf, buffer = pcall(vim.api.nvim_get_current_buf)
        if not ok_buf or type(buffer) ~= "number" then
            if ctx.adapters and ctx.adapters.notifications and ctx.adapters.notifications.error then
                ctx.adapters.notifications.error("ObsidianRenderDataview unavailable: failed to resolve current buffer")
            end
            return
        end

        local result = ctx.use_cases.render_query_blocks.execute(ctx, {
            buffer = buffer,
            trigger = "manual",
        })

        if not result.ok then
            if result.error and result.error.code == "parse_failure" then
                if ctx.adapters and ctx.adapters.notifications then
                    ctx.adapters.notifications.warn("Parse error in dataview block: " .. result.error.message)
                end
            else
                error_to_notification(ctx, result.error)
            end
            return
        end

        if ctx.adapters and ctx.adapters.notifications then
            local count = result.processed_blocks
            if count == nil then
                count = result.rendered_blocks
            end
            ctx.adapters.notifications.info("Rendered " .. tostring(count or 0) .. " dataview blocks")
        end
    end, { desc = "Render dataview blocks in current buffer" })
end

local function register_dataview_autocmds(ctx)
    if not ctx or not ctx.config or not ctx.config.dataview or ctx.config.dataview.enabled ~= true then
        return
    end
    if not ctx.use_cases or not ctx.use_cases.render_query_blocks or type(ctx.use_cases.render_query_blocks.execute) ~= "function" then
        return
    end
    if not vim or not vim.api or type(vim.api.nvim_create_autocmd) ~= "function" then
        return
    end

    local render_cfg = ctx.config.dataview.render or {}
    local when = type(render_cfg.when) == "table" and render_cfg.when or {}
    local patterns = type(render_cfg.patterns) == "table" and render_cfg.patterns or { "*.md" }
    local scope = render_cfg.scope or "event"

    local trigger_for_event = {
        BufReadPost = "on_open",
        BufWritePost = "on_save",
    }

    local selected_events = {}
    local function has_trigger(name)
        for _, configured in ipairs(when) do
            if configured == name then
                return true
            end
        end
        return false
    end

    if has_trigger("on_open") then
        table.insert(selected_events, "BufReadPost")
    end
    if has_trigger("on_save") then
        table.insert(selected_events, "BufWritePost")
    end
    if #selected_events == 0 then
        return
    end

    local function list_target_buffers(args)
        local seen = {}
        local targets = {}

        local function add(buf)
            local n = tonumber(buf)
            if not n or seen[n] then
                return
            end
            seen[n] = true
            table.insert(targets, n)
        end

        local function add_event_buffer()
            if args and args.buf ~= nil then
                add(args.buf)
            end
        end

        if scope == "event" then
            add_event_buffer()
            return targets
        end

        if not vim or not vim.api then
            add_event_buffer()
            return targets
        end

        if scope == "current" then
            if type(vim.api.nvim_get_current_buf) == "function" then
                local ok, buf = pcall(vim.api.nvim_get_current_buf)
                if ok then
                    add(buf)
                end
            end
            if #targets == 0 then
                add_event_buffer()
            end
            return targets
        end

        if scope == "visible" then
            if type(vim.api.nvim_list_wins) == "function" and type(vim.api.nvim_win_get_buf) == "function" then
                local ok, wins = pcall(vim.api.nvim_list_wins)
                if ok and type(wins) == "table" then
                    for _, win in ipairs(wins) do
                        local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
                        if ok_buf then
                            add(buf)
                        end
                    end
                end
            end
            if #targets == 0 then
                add_event_buffer()
            end
            return targets
        end

        if scope == "loaded" then
            if type(vim.api.nvim_list_bufs) == "function" then
                local ok, bufs = pcall(vim.api.nvim_list_bufs)
                if ok and type(bufs) == "table" then
                    for _, buf in ipairs(bufs) do
                        if type(vim.api.nvim_buf_is_loaded) ~= "function" or vim.api.nvim_buf_is_loaded(buf) then
                            add(buf)
                        end
                    end
                end
            end
            if #targets == 0 then
                add_event_buffer()
            end
            return targets
        end

        add_event_buffer()
        return targets
    end

    local group = nil
    if type(vim.api.nvim_create_augroup) == "function" then
        group = vim.api.nvim_create_augroup("NvimObsidianDataview", { clear = true })
    end

    vim.api.nvim_create_autocmd(selected_events, {
        group = group,
        pattern = patterns,
        callback = function(args)
            local trigger = trigger_for_event[args.event]
            if not trigger then
                return
            end

            local function run_render(buffer, render_trigger)
                if type(vim) == "table" and type(vim.api) == "table" then
                    if type(vim.api.nvim_buf_is_valid) == "function" and not vim.api.nvim_buf_is_valid(buffer) then
                        return
                    end
                    if type(vim.api.nvim_buf_is_loaded) == "function" and not vim.api.nvim_buf_is_loaded(buffer) then
                        return
                    end
                end

                local result = ctx.use_cases.render_query_blocks.execute(ctx, {
                    buffer = buffer,
                    trigger = render_trigger,
                })

                if not result or result.ok ~= true then
                    if result and result.error and result.error.code == "parse_failure" then
                        if ctx.adapters and ctx.adapters.notifications and ctx.adapters.notifications.warn then
                            ctx.adapters.notifications.warn("Parse error in dataview block: " ..
                                tostring(result.error.message or "parse failed"))
                        end
                        return
                    end
                    if result and result.error then
                        error_to_notification(ctx, result.error)
                    end
                end
            end

            local function run_for_scope(render_trigger)
                local buffers = list_target_buffers(args)
                for _, buffer in ipairs(buffers) do
                    run_render(buffer, render_trigger)
                end
            end

            -- Defer rendering to avoid blocking the triggering event (buffer save, open, etc.)
            -- This allows the user action to complete immediately while dataview renders asynchronously.
            --
            -- For BufWritePost (save events), use a longer delay via vim.defer_fn() to ensure the save
            -- is truly complete before rendering starts. For other events (open, etc.), use vim.schedule()
            -- for immediate (but async) processing after the event completes.
            if type(vim) == "table" then
                if args.event == "BufWritePost" and type(vim.defer_fn) == "function" then
                    -- Schedule rendering after save with 50ms delay to ensure save is truly complete
                    vim.defer_fn(function()
                        run_for_scope(trigger)
                    end, 50)
                    return
                elseif type(vim.schedule) == "function" then
                    -- For other events, schedule immediately after event completes
                    vim.schedule(function()
                        run_for_scope(trigger)
                    end)
                    return
                end
            end

            run_for_scope(trigger)
        end,
    })
end

local function register_obsidian_health(ctx)
    create_user_command("ObsidianHealth", function()
        if ctx and ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info("nvim-obsidian health: ok")
        end
    end, { desc = "Check nvim-obsidian adapter wiring health" })
end

function M.register(container)
    if not container then
        return
    end

    register_obsidian_today(container)
    register_obsidian_next(container)
    register_obsidian_prev(container)
    register_obsidian_omni(container)
    register_obsidian_follow(container)
    register_obsidian_backlinks(container)
    register_obsidian_search(container)
    register_obsidian_reindex(container)
    register_obsidian_insert_template(container)
    register_obsidian_calendar(container)
    register_obsidian_render_dataview(container)
    register_dataview_autocmds(container)
    register_obsidian_health(container)
end

return M
