---@diagnostic disable: undefined-global

local M = {}

local function create_user_command(name, fn, opts)
    if not vim or not vim.api or not vim.api.nvim_create_user_command then
        return
    end
    local merged = vim.tbl_deep_extend("force", { force = true }, opts or {})
    vim.api.nvim_create_user_command(name, fn, merged)
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

local function journal_token_for(ctx, kind, direction)
    local journal = ctx.journal
    if type(journal) ~= "table" or type(journal.compute_adjacent) ~= "function" then
        return os.date("%Y-%m-%d", os.time())
    end

    local adjacent = journal.compute_adjacent(kind, os.time(), direction)
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

        local kind = resolve_journal_kind(ctx)
        local token = journal_token_for(ctx, kind, "current")
        local result = ctx.use_cases.ensure_open_note.execute(ctx, {
            title_or_token = token,
            create_if_missing = true,
            origin = "journal",
            now = os.time(),
        })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        if ctx.adapters and ctx.adapters.navigation then
            ctx.adapters.navigation.open_path(result.path)
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
            now = os.time(),
        })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        if ctx.adapters and ctx.adapters.navigation then
            ctx.adapters.navigation.open_path(result.path)
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
            now = os.time(),
        })

        if not result.ok then
            error_to_notification(ctx, result.error)
            return
        end

        if ctx.adapters and ctx.adapters.navigation then
            ctx.adapters.navigation.open_path(result.path)
        end
    end, { desc = "Open or create previous journal note in current context" })
end

local function register_obsidian_omni(ctx)
    create_user_command("ObsidianOmni", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.search_open_create then
            return
        end

        local result = ctx.use_cases.search_open_create.execute(ctx, {})

        if not result.ok then
            if result.error and result.error.code == "cancelled" then
                -- User cancelled picker, silent
                return
            end
            error_to_notification(ctx, result.error)
            return
        end

        if ctx.adapters and ctx.adapters.navigation then
            ctx.adapters.navigation.open_path(result.path)
        end

        if result.created and ctx.adapters and ctx.adapters.notifications then
            ctx.adapters.notifications.info("Created note: " .. result.path)
        end
    end, { desc = "Open note via Omni search/create" })
end

local function register_obsidian_follow(ctx)
    create_user_command("ObsidianFollow", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.follow_link then
            return
        end

        local result = ctx.use_cases.follow_link.execute(ctx, {})

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
            ctx.adapters.notifications.info("Reindex complete: " .. tostring(result.reindexed_count) .. " notes indexed")
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

local function register_obsidian_render_dataview(ctx)
    create_user_command("ObsidianRenderDataview", function()
        if not ctx or not ctx.use_cases or not ctx.use_cases.render_query_blocks then
            return
        end

        local result = ctx.use_cases.render_query_blocks.execute(ctx, {})

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
            ctx.adapters.notifications.info("Rendered " .. tostring(result.processed_blocks) .. " dataview blocks")
        end
    end, { desc = "Render dataview blocks in current buffer" })
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
    register_obsidian_render_dataview(container)
    register_obsidian_health(container)
end

return M
