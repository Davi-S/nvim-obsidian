local config = require("nvim_obsidian.app.config")
local notifications = require("nvim_obsidian.adapters.neovim.notifications")

local M = {}

function M.build(user_opts)
    local opts = config.normalize(user_opts)

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
            vault_catalog = require("nvim_obsidian.core.domains.vault_catalog.contract"),
            journal = require("nvim_obsidian.core.domains.journal.contract"),
            wiki_link = require("nvim_obsidian.core.domains.wiki_link.contract"),
            template = require("nvim_obsidian.core.domains.template.contract"),
            dataview = require("nvim_obsidian.core.domains.dataview.contract"),
            search_ranking = require("nvim_obsidian.core.domains.search_ranking.contract"),
        },
        use_cases = {
            ensure_open_note = require("nvim_obsidian.use_cases.ensure_open_note"),
            follow_link = require("nvim_obsidian.use_cases.follow_link"),
            reindex_sync = require("nvim_obsidian.use_cases.reindex_sync"),
            render_query_blocks = require("nvim_obsidian.use_cases.render_query_blocks"),
            search_open_create = require("nvim_obsidian.use_cases.search_open_create"),
            show_backlinks = require("nvim_obsidian.use_cases.show_backlinks"),
            vault_search = require("nvim_obsidian.use_cases.vault_search"),
            insert_template = require("nvim_obsidian.use_cases.insert_template"),
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
    }

    return container
end

return M
