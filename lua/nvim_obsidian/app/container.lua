local config = require("nvim_obsidian.app.config")
local journal_placeholders = require("nvim_obsidian.app.journal_placeholders")
local notifications = require("nvim_obsidian.adapters.neovim.notifications")

---Runtime dependency container builder.
---
---The container is the composition root for DDD layers:
---1) domains and use-cases (core logic)
---2) adapters (Neovim/filesystem/picker integrations)
---3) bridge ports exposed at top-level for use-case contracts.
local M = {}

---@param path any
---@return boolean
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

---@param base any
---@param leaf any
---@return string
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

---@param path any
---@return boolean
local function is_markdown_path(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    return path:match("%.md$") ~= nil
end

---Build the full runtime container and wire all composition dependencies.
---@param user_opts? table
---@return table container
function M.build(user_opts)
    local opts = config.normalize(user_opts)
    local dataview_namespace = nil

    local vault_catalog = require("nvim_obsidian.core.domains.vault_catalog.impl")
    local journal = require("nvim_obsidian.core.domains.journal.impl")
    local date_picker = require("nvim_obsidian.core.domains.date_picker.impl")
    local wiki_link = require("nvim_obsidian.core.domains.wiki_link.impl")
    local template = require("nvim_obsidian.core.domains.template.impl")
    local dataview = require("nvim_obsidian.core.domains.dataview.impl")
    local search_ranking = require("nvim_obsidian.core.domains.search_ranking.impl")

    local ensure_open_note = require("nvim_obsidian.use_cases.ensure_open_note")
    local follow_link = require("nvim_obsidian.use_cases.follow_link")
    local reindex_sync = require("nvim_obsidian.use_cases.reindex_sync")
    local render_query_blocks = require("nvim_obsidian.use_cases.render_query_blocks")
    local search_open_create = require("nvim_obsidian.use_cases.search_open_create")
    local show_backlinks = require("nvim_obsidian.use_cases.show_backlinks")
    local vault_search = require("nvim_obsidian.use_cases.vault_search")
    local insert_template = require("nvim_obsidian.use_cases.insert_template")
    local open_date_picker = require("nvim_obsidian.use_cases.open_date_picker")

    local adapter_set = {
        commands = require("nvim_obsidian.adapters.neovim.commands"),
        notifications = notifications.create_notifier({
            vim = vim,
            config = opts,
        }),
        navigation = require("nvim_obsidian.adapters.neovim.navigation"),
        calendar_buffer = require("nvim_obsidian.adapters.neovim.calendar_buffer"),
        telescope = require("nvim_obsidian.adapters.picker.telescope"),
        blink_source = require("nvim_obsidian.adapters.completion.blink_source"),
        fs_io = require("nvim_obsidian.adapters.filesystem.io"),
        watcher = require("nvim_obsidian.adapters.filesystem.watcher"),
        frontmatter = require("nvim_obsidian.adapters.parser.frontmatter"),
        markdown = require("nvim_obsidian.adapters.parser.markdown"),
    }

    local container = {
        config = opts,
        domains = {
            vault_catalog = vault_catalog,
            journal = journal,
            date_picker = date_picker,
            wiki_link = wiki_link,
            template = template,
            dataview = dataview,
            search_ranking = search_ranking,
        },
        use_cases = {
            ensure_open_note = ensure_open_note,
            follow_link = follow_link,
            reindex_sync = reindex_sync,
            render_query_blocks = render_query_blocks,
            search_open_create = search_open_create,
            show_backlinks = show_backlinks,
            vault_search = vault_search,
            insert_template = insert_template,
            open_date_picker = open_date_picker,
        },
        adapters = adapter_set,

        -- Bridge fields to satisfy use-case contracts that depend on top-level
        -- ports. This keeps use-cases decoupled from nested adapter/domain trees.
        navigation = adapter_set.navigation,
        notifications = adapter_set.notifications,
        fs_io = adapter_set.fs_io,
        watcher = adapter_set.watcher,
        frontmatter = adapter_set.frontmatter,
        markdown = adapter_set.markdown,
        telescope = adapter_set.telescope,

        vault_catalog = vault_catalog,
        journal = journal,
        date_picker = date_picker,
        wiki_link = wiki_link,
        template = template,
        dataview = dataview,
        search_ranking = search_ranking,

        ensure_open_note = ensure_open_note,
        follow_link = follow_link,
        reindex_sync = reindex_sync,
        render_query_blocks = render_query_blocks,
        search_open_create = search_open_create,
        show_backlinks = show_backlinks,
        vault_search = vault_search,
        insert_template = insert_template,
        open_date_picker = open_date_picker,

        ---Read entire buffer as markdown text.
        ---@param buffer integer
        ---@return string|nil
        get_buffer_markdown = function(buffer)
            if not vim or not vim.api or type(vim.api.nvim_buf_get_lines) ~= "function" then
                return nil
            end

            local ok, lines = pcall(vim.api.nvim_buf_get_lines, buffer, 0, -1, false)
            if not ok or type(lines) ~= "table" then
                return nil
            end

            return table.concat(lines, "\n")
        end,
        ---Apply dataview overlays using extmarks and virtual lines.
        ---
        ---Implementation note:
        ---A dedicated namespace is lazily initialized and reused to support
        ---idempotent redraws. Existing overlays are cleared before re-apply.
        ---@param buffer integer
        ---@param overlays table
        ---@param highlight_config? table
        ---@return boolean ok
        ---@return string? err
        apply_rendered_blocks = function(buffer, overlays, highlight_config)
            if not vim or not vim.api then
                return false, "nvim API is unavailable"
            end

            if type(vim.api.nvim_buf_clear_namespace) ~= "function" or type(vim.api.nvim_buf_set_extmark) ~= "function" then
                return false, "nvim extmark API is unavailable"
            end

            if dataview_namespace == nil then
                if type(vim.api.nvim_create_namespace) ~= "function" then
                    return false, "nvim namespace API is unavailable"
                end
                dataview_namespace = vim.api.nvim_create_namespace("nvim-obsidian-dataview")
            end

            if type(overlays) ~= "table" then
                return false, "overlays must be a table"
            end

            -- Default highlight config if not provided
            if type(highlight_config) ~= "table" then
                highlight_config = {
                    header = "Comment",
                    task_text = "Normal",
                    task_no_results = "Comment",
                    table_header = "Comment",
                    table_link = "Comment",
                    error = "WarningMsg",
                }
            end

            local clear_ok, clear_err = pcall(vim.api.nvim_buf_clear_namespace, buffer, dataview_namespace, 0, -1)
            if not clear_ok then
                return false, tostring(clear_err)
            end

            for _, overlay in ipairs(overlays) do
                local anchor_line = tonumber(overlay.anchor_line)
                local lines = overlay.lines
                local placement = tostring(overlay.placement or "below_block")

                if not anchor_line or anchor_line < 1 then
                    return false, "invalid overlay anchor_line"
                end
                if type(lines) ~= "table" then
                    return false, "invalid overlay lines"
                end

                local virt_lines = {}
                for _, line_obj in ipairs(lines) do
                    local text = tostring(line_obj)
                    local hl = "Comment"

                    if type(line_obj) == "table" then
                        text = tostring(line_obj.text or "")
                        hl = highlight_config[line_obj.highlight] or "Comment"
                    end

                    table.insert(virt_lines, {
                        { text, hl },
                    })
                end

                local virt_lines_above = (placement == "above_block")
                local ok, err = pcall(vim.api.nvim_buf_set_extmark, buffer, dataview_namespace, anchor_line - 1, 0, {
                    virt_lines = virt_lines,
                    virt_lines_above = virt_lines_above,
                    hl_mode = "combine",
                })
                if not ok then
                    return false, tostring(err)
                end
            end

            return true
        end,

        ---Scan vault for markdown files.
        ---@return string[]
        scan_markdown_files = function()
            local files, list_err = adapter_set.fs_io.list_markdown_files(opts.vault_root)
            if type(files) ~= "table" then
                error("nvim-obsidian setup: failed to scan markdown files: " .. tostring(list_err or "unknown error"))
            end
            return files
        end,
        ---Replace vault catalog atomically.
        ---@param notes table[]
        ---@return boolean
        ---@return string|nil
        replace_catalog = function(notes)
            if type(vault_catalog._replace_all) ~= "function" then
                return false, "vault catalog does not support atomic replace"
            end
            return vault_catalog._replace_all(notes)
        end,
        ---Resolve a journal note title for the given kind/date.
        ---
        ---Prefers user-provided title_format and falls back to domain defaults.
        ---@param kind string
        ---@param date table|nil
        ---@return string
        resolve_journal_title = function(kind, date)
            if type(kind) ~= "string" or kind == "" then
                error("nvim-obsidian setup: resolve_journal_title requires a non-empty kind")
            end

            local section = type(opts.journal) == "table" and opts.journal[kind] or nil
            local format = type(section) == "table" and section.title_format or nil
            if type(format) ~= "string" or format == "" then
                local built = journal.build_title(kind, date, opts.locale)
                if type(built) ~= "table" or type(built.title) ~= "string" or built.title == "" then
                    error("nvim-obsidian setup: journal.build_title returned invalid title")
                end
                return built.title
            end
            return journal_placeholders.render_title_format(format, {
                config = opts,
                date = date,
                kind = kind,
            })
        end,
        ---Resolve template file content from request context and config.
        ---
        ---Resolution order intentionally favors explicit query input, then
        ---journal-kind template mapping, then standard template fallback.
        ---@param req? table
        ---@return string|nil
        resolve_template_content = function(req)
            local request = req or {}
            local query = nil
            if type(request.query) == "string" then
                local trimmed = request.query:gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed ~= "" then
                    query = trimmed
                end
            end

            local kind = tostring(request.kind or "")
            if kind == "" and request.type ~= nil then
                kind = tostring(request.type or "")
            end

            local candidates = {}

            local function add_candidate(path)
                if type(path) ~= "string" or path == "" then
                    return
                end
                table.insert(candidates, path)
            end

            if query == "standard" then
                add_candidate(type(opts.templates) == "table" and opts.templates.standard or nil)
            elseif query == "daily" or query == "weekly" or query == "monthly" or query == "yearly" then
                local section = type(opts.journal) == "table" and opts.journal[query] or nil
                add_candidate(type(section) == "table" and section.template or nil)
            elseif query then
                add_candidate(query)
            end

            if not query then
                if request.origin == "journal" and (kind == "daily" or kind == "weekly" or kind == "monthly" or kind == "yearly") then
                    local section = type(opts.journal) == "table" and opts.journal[kind] or nil
                    add_candidate(type(section) == "table" and section.template or nil)
                else
                    add_candidate(type(opts.templates) == "table" and opts.templates.standard or nil)
                end
            end

            for _, template_ref in ipairs(candidates) do
                local absolute = template_ref
                if not is_absolute_path(template_ref) then
                    absolute = join_path(opts.vault_root, template_ref)
                end

                local try_paths = { absolute }
                if not absolute:match("%.md$") then
                    table.insert(try_paths, absolute .. ".md")
                end

                for _, path in ipairs(try_paths) do
                    local content = nil
                    if type(adapter_set.fs_io.read_file) == "function" then
                        content = adapter_set.fs_io.read_file(path)
                    end
                    if type(content) == "string" then
                        return content
                    end
                end
            end

            return nil
        end,
    }

    ---Handle normalized filesystem events and synchronize vault index.
    ---@param event table
    container.on_fs_event = function(event)
        if type(event) ~= "table" then
            return
        end

        local kind = tostring(event.kind or "")
        local path = event.path

        if kind == "rescan" then
            local ok_exec, result = pcall(reindex_sync.execute, container, {
                mode = "manual",
                event = nil,
            })
            if not ok_exec then
                if adapter_set.notifications and type(adapter_set.notifications.warn) == "function" then
                    adapter_set.notifications.warn("Watcher rescan failed: " .. tostring(result))
                end
                return
            end

            if type(result) ~= "table" or result.ok ~= true then
                if adapter_set.notifications and type(adapter_set.notifications.warn) == "function" then
                    local message = "watcher rescan failed"
                    if type(result) == "table" and type(result.error) == "table" and type(result.error.message) == "string" then
                        message = result.error.message
                    end
                    adapter_set.notifications.warn("Watcher rescan failed: " .. message)
                end
            end
            return
        end

        if kind == "rename" then
            local old_path = event.old_path
            local new_path = event.new_path
            if not is_markdown_path(old_path) and not is_markdown_path(new_path) then
                return
            end
        else
            if not is_markdown_path(path) then
                return
            end
            if kind ~= "create" and kind ~= "modify" and kind ~= "delete" then
                kind = "modify"
            end
        end

        local request = {
            mode = "event",
            event = {
                kind = kind,
                path = path,
                old_path = event.old_path,
                new_path = event.new_path,
            },
        }

        local ok_exec, result = pcall(reindex_sync.execute, container, request)
        if not ok_exec then
            if adapter_set.notifications and type(adapter_set.notifications.warn) == "function" then
                adapter_set.notifications.warn("Watcher sync failed: " .. tostring(result))
            end
            return
        end

        if type(result) ~= "table" or result.ok ~= true then
            if adapter_set.notifications and type(adapter_set.notifications.warn) == "function" then
                local message = "watcher event sync failed"
                if type(result) == "table" and type(result.error) == "table" and type(result.error.message) == "string" then
                    message = result.error.message
                end
                adapter_set.notifications.warn("Watcher sync failed: " .. message)
            end
        end
    end

    -- Backward-compatible alias used by watcher adapters and tests.
    container.handle_fs_event = container.on_fs_event

    return container
end

return M
