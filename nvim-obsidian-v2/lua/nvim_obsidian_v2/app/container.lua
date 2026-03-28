local config = require("nvim_obsidian_v2.app.config")

local M = {}

function M.build(user_opts)
    local opts = config.normalize(user_opts)

    local container = {
        config = opts,
        domains = {
            vault_catalog = require("nvim_obsidian_v2.core.domains.vault_catalog.contract"),
            journal = require("nvim_obsidian_v2.core.domains.journal.contract"),
            wiki_link = require("nvim_obsidian_v2.core.domains.wiki_link.contract"),
            template = require("nvim_obsidian_v2.core.domains.template.contract"),
            dataview = require("nvim_obsidian_v2.core.domains.dataview.contract"),
            search_ranking = require("nvim_obsidian_v2.core.domains.search_ranking.contract"),
        },
        use_cases = {
            ensure_open_note = require("nvim_obsidian_v2.use_cases.ensure_open_note"),
            follow_link = require("nvim_obsidian_v2.use_cases.follow_link"),
            reindex_sync = require("nvim_obsidian_v2.use_cases.reindex_sync"),
            render_query_blocks = require("nvim_obsidian_v2.use_cases.render_query_blocks"),
            search_open_create = require("nvim_obsidian_v2.use_cases.search_open_create"),
        },
        adapters = {
            commands = require("nvim_obsidian_v2.adapters.neovim.commands"),
            notifications = require("nvim_obsidian_v2.adapters.neovim.notifications"),
            navigation = require("nvim_obsidian_v2.adapters.neovim.navigation"),
            telescope = require("nvim_obsidian_v2.adapters.picker.telescope"),
            cmp_source = require("nvim_obsidian_v2.adapters.completion.cmp_source"),
            fs_io = require("nvim_obsidian_v2.adapters.filesystem.io"),
            watcher = require("nvim_obsidian_v2.adapters.filesystem.watcher"),
            frontmatter = require("nvim_obsidian_v2.adapters.parser.frontmatter"),
            markdown = require("nvim_obsidian_v2.adapters.parser.markdown"),
        },
    }

    return container
end

return M
