---@diagnostic disable: undefined-global

local M = {}

local function create_user_command(name, fn, opts)
    if not vim or not vim.api or not vim.api.nvim_create_user_command then
        return
    end
    vim.api.nvim_create_user_command(name, fn, opts or {})
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

local function basename(path)
    local p = tostring(path or ""):gsub("\\", "/")
    return p:match("[^/]+$") or p
end

local function get_current_buffer_path()
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

        local now = os.time()
        local result = ctx.use_cases.ensure_open_note.execute(ctx, {
            title_or_token = os.date("%Y-%m-%d", now),
            create_if_missing = true,
            origin = "journal",
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

        -- Stub: In full implementation, detect current note type and compute next
        local result = ctx.use_cases.ensure_open_note.execute(ctx, {
            title_or_token = os.date("%Y-%m-%d", os.time() + 86400),
            create_if_missing = true,
            origin = "journal",
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

        -- Stub: In full implementation, detect current note type and compute prev
        local result = ctx.use_cases.ensure_open_note.execute(ctx, {
            title_or_token = os.date("%Y-%m-%d", os.time() - 86400),
            create_if_missing = true,
            origin = "journal",
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
        if not ctx or not ctx.adapters then
            return
        end

        local notifications = ctx.adapters.notifications
        local telescope = ctx.adapters.telescope
        local navigation = ctx.adapters.navigation
        local fs_io = ctx.fs_io or (ctx.adapters and ctx.adapters.fs_io)
        local markdown = ctx.markdown or (ctx.adapters and ctx.adapters.markdown)
        local vault_catalog = ctx.vault_catalog

        if type(vault_catalog) ~= "table" or type(vault_catalog.list_notes) ~= "function" then
            if notifications and notifications.warn then
                notifications.warn("Backlinks unavailable: vault catalog list_notes is missing")
            end
            return
        end

        local current_path = get_current_buffer_path()
        if not current_path then
            if notifications and notifications.warn then
                notifications.warn("Backlinks unavailable: current buffer has no path")
            end
            return
        end

        local notes = vault_catalog.list_notes() or {}
        local by_path = {}
        local current_note = nil
        for _, note in ipairs(notes) do
            if type(note) == "table" and type(note.path) == "string" then
                by_path[note.path] = note
                if note.path == current_path then
                    current_note = note
                end
            end
        end

        if not current_note then
            if notifications and notifications.warn then
                notifications.warn("Backlinks unavailable: current note is not indexed")
            end
            return
        end

        if type(fs_io) ~= "table" or type(fs_io.list_markdown_files) ~= "function" or type(fs_io.read_file) ~= "function" then
            if notifications and notifications.warn then
                notifications.warn("Backlinks unavailable: filesystem adapter is missing")
            end
            return
        end

        if type(markdown) ~= "table" or type(markdown.extract_wikilinks) ~= "function" then
            if notifications and notifications.warn then
                notifications.warn("Backlinks unavailable: markdown parser adapter is missing")
            end
            return
        end

        local token_map = {}
        token_map[tostring(current_note.title or "")] = true
        for _, alias in ipairs(current_note.aliases or {}) do
            token_map[tostring(alias)] = true
        end

        local root = (ctx.config and ctx.config.vault_root) or (vim and vim.fn and vim.fn.getcwd and vim.fn.getcwd())
        local files = fs_io.list_markdown_files(root) or {}
        local matches = {}
        local seen = {}

        for _, path in ipairs(files) do
            if path ~= current_path then
                local content = fs_io.read_file(path)
                if type(content) == "string" then
                    local links = markdown.extract_wikilinks(content) or {}
                    for _, link in ipairs(links) do
                        local ref = tostring(link.note_ref or "")
                        if token_map[ref] and not seen[path] then
                            seen[path] = true
                            local n = by_path[path] or {
                                path = path,
                                title = basename(path):gsub("%.md$", ""),
                                aliases = {},
                            }
                            table.insert(matches, n)
                        end
                    end
                end
            end
        end

        if #matches == 0 then
            if notifications and notifications.info then
                notifications.info({
                    command = "ObsidianBacklinks",
                    message = "No backlinks found",
                    target = current_note.path,
                })
            end
            return
        end

        if type(telescope) ~= "table" or type(telescope.open_disambiguation) ~= "function" then
            if notifications and notifications.warn then
                notifications.warn("Backlinks found but picker adapter is unavailable")
            end
            return
        end

        local picked = telescope.open_disambiguation({
            target = { note_ref = current_note.title },
            matches = matches,
            buffer_path = current_path,
        })

        if type(picked) == "table" and picked.action == "open" and type(picked.path) == "string" then
            if navigation and type(navigation.open_path) == "function" then
                navigation.open_path(picked.path)
            end
        end
    end, { desc = "Show notes linking to current note" })
end

local function register_obsidian_search(ctx)
    create_user_command("ObsidianSearch", function()
        if not ctx or not ctx.adapters then
            return
        end

        local telescope = ctx.adapters.telescope
        local navigation = ctx.adapters.navigation
        local notifications = ctx.adapters.notifications
        local root = (ctx.config and ctx.config.vault_root) or (vim and vim.fn and vim.fn.getcwd and vim.fn.getcwd())

        if type(telescope) ~= "table" or type(telescope.open_search) ~= "function" then
            if notifications and notifications.warn then
                notifications.warn("Search unavailable: telescope search adapter is missing")
            end
            return
        end

        local ok = telescope.open_search({
            root = root,
            navigation = navigation,
        })

        if not ok and notifications and notifications.info then
            notifications.info({
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
        if not ctx or not ctx.adapters then
            return
        end

        local notifications = ctx.adapters.notifications
        local fs_io = ctx.fs_io or (ctx.adapters and ctx.adapters.fs_io)
        local query = trim((cmd and cmd.args) or "")
        local template_content = nil

        if query and type(ctx.resolve_template_content) == "function" then
            local resolved = ctx.resolve_template_content({
                query = query,
                command = "ObsidianInsertTemplate",
            })
            if type(resolved) == "string" and resolved ~= "" then
                template_content = resolved
            end
        end

        if not template_content and query and type(fs_io) == "table" and type(fs_io.read_file) == "function" then
            local content = fs_io.read_file(query)
            if type(content) == "string" and content ~= "" then
                template_content = content
            end
        end

        if not template_content then
            if notifications and notifications.warn then
                notifications.warn({
                    command = "ObsidianInsertTemplate",
                    message = "Template not found",
                    target = query or "<picker>",
                    next_step = "Provide a template path or configure resolve_template_content",
                })
            end
            return
        end

        local rendered = template_content
        if type(ctx.template) == "table" and type(ctx.template.render) == "function" then
            local out = ctx.template.render(template_content, {
                now = os.time(),
                date = os.date("%Y-%m-%d"),
                command = "ObsidianInsertTemplate",
            })
            if type(out) == "table" and type(out.rendered) == "string" then
                rendered = out.rendered
            elseif type(out) == "string" then
                rendered = out
            end
        end

        if vim and vim.api and type(vim.api.nvim_put) == "function" then
            local lines = split_lines(rendered)
            pcall(vim.api.nvim_put, lines, "c", true, true)
            if notifications and notifications.info then
                notifications.info({
                    command = "ObsidianInsertTemplate",
                    message = "Template inserted",
                    target = query,
                })
            end
        else
            if notifications and notifications.warn then
                notifications.warn("Template insertion unavailable: nvim_put is missing")
            end
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
