local config = require("nvim_obsidian.app.config")

local M = {}

function M.build(user_opts)
    local opts = config.normalize(user_opts)

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
        },
        adapters = {
            commands = require("nvim_obsidian.adapters.neovim.commands"),
            notifications = require("nvim_obsidian.adapters.neovim.notifications"),
            navigation = require("nvim_obsidian.adapters.neovim.navigation"),
            telescope = require("nvim_obsidian.adapters.picker.telescope"),
            cmp_source = require("nvim_obsidian.adapters.completion.cmp_source"),
            fs_io = require("nvim_obsidian.adapters.filesystem.io"),
            watcher = require("nvim_obsidian.adapters.filesystem.watcher"),
            frontmatter = require("nvim_obsidian.adapters.parser.frontmatter"),
            markdown = require("nvim_obsidian.adapters.parser.markdown"),
        },
    }

    return container
end

return M
