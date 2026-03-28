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
        -- Stub: Backlinks workflow orchestration
        if not ctx or not ctx.adapters or not ctx.adapters.notifications then
            return
        end
        ctx.adapters.notifications.info("Backlinks: Phase 7 implementation pending")
    end, { desc = "Show notes linking to current note" })
end

local function register_obsidian_search(ctx)
    create_user_command("ObsidianSearch", function()
        -- Stub: Telescope live_grep wrapper
        if not ctx or not ctx.adapters or not ctx.adapters.notifications then
            return
        end
        ctx.adapters.notifications.info("Search: Phase 7 implementation pending")
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

        local result = ctx.use_cases.reindex_sync.execute(ctx, { kind = "full" })

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
        -- Stub: Template insertion workflow
        if not ctx or not ctx.adapters or not ctx.adapters.notifications then
            return
        end
        ctx.adapters.notifications.info("InsertTemplate: Phase 7 implementation pending")
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
end

return M
