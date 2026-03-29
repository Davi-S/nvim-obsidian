local config = require("nvim_obsidian.app.config")
local journal_placeholders = require("nvim_obsidian.app.journal_placeholders")
local notifications = require("nvim_obsidian.adapters.neovim.notifications")

local M = {}

function M.build(user_opts)
    local opts = config.normalize(user_opts)

    local vault_catalog = require("nvim_obsidian.core.domains.vault_catalog.impl")
    local journal = require("nvim_obsidian.core.domains.journal.impl")
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

    local adapter_set = {
        commands = require("nvim_obsidian.adapters.neovim.commands"),
        notifications = notifications.create_notifier({
            vim = vim,
            config = opts,
        }),
        navigation = require("nvim_obsidian.adapters.neovim.navigation"),
        telescope = require("nvim_obsidian.adapters.picker.telescope"),
        cmp_source = require("nvim_obsidian.adapters.completion.cmp_source"),
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
        },
        adapters = adapter_set,

        -- Bridge fields to satisfy use-case contracts that depend on top-level ports.
        navigation = adapter_set.navigation,
        notifications = adapter_set.notifications,
        fs_io = adapter_set.fs_io,
        watcher = adapter_set.watcher,
        frontmatter = adapter_set.frontmatter,
        markdown = adapter_set.markdown,
        telescope = adapter_set.telescope,

        vault_catalog = vault_catalog,
        journal = journal,
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

        scan_markdown_files = function()
            local files, _ = adapter_set.fs_io.list_markdown_files(opts.vault_root)
            return files or {}
        end,
        replace_catalog = function(notes)
            if type(vault_catalog._replace_all) ~= "function" then
                return false, "vault catalog does not support atomic replace"
            end
            return vault_catalog._replace_all(notes)
        end,
        resolve_journal_title = function(kind, date)
            local section = (((opts.journal or {})[kind]) or {})
            local format = section.title_format
            if type(format) ~= "string" or format == "" then
                local built = journal.build_title(kind, date, opts.locale)
                return tostring((built and built.title) or "")
            end
            return journal_placeholders.render_title_format(format, {
                config = opts,
                date = date,
                kind = kind,
            })
        end,
    }

    return container
end

return M
