local config = require("nvim-obsidian.config")
local router = require("nvim-obsidian.journal.router")
local time_travel = require("nvim-obsidian.journal.time_travel")
local path = require("nvim-obsidian.path")

local M = {}

local function ensure_and_open(note_type, title, filepath)
    if vim.fn.filereadable(filepath) == 0 then
        path.ensure_dir(path.parent(filepath))
        local tpl = router.template_for_type(note_type, config.get())
        local rendered = router.render_template(tpl, title)
        if rendered == "" then
            vim.fn.writefile({}, filepath)
        else
            vim.fn.writefile(vim.split(rendered, "\n", { plain = true }), filepath)
        end
    end
    vim.cmd.edit(vim.fn.fnameescape(filepath))
end

function M.register()
    local cfg = config.get()

    vim.api.nvim_create_user_command("ObsidianOmni", function()
        require("nvim-obsidian.picker.omni").open()
    end, {})

    if cfg.journal_enabled then
        vim.api.nvim_create_user_command("ObsidianToday", function()
            local note_type, title, filepath = router.today_daily(config.get())
            ensure_and_open(note_type, title, filepath)
        end, {})

        vim.api.nvim_create_user_command("ObsidianNext", function()
            local note_type, title, filepath = time_travel.open_relative(1)
            ensure_and_open(note_type, title, filepath)
        end, {})

        vim.api.nvim_create_user_command("ObsidianPrev", function()
            local note_type, title, filepath = time_travel.open_relative(-1)
            ensure_and_open(note_type, title, filepath)
        end, {})
    end

    vim.api.nvim_create_user_command("ObsidianBacklinks", function()
        require("nvim-obsidian.backlinks").search_current()
    end, {})

    vim.api.nvim_create_user_command("ObsidianSearch", function()
        require("nvim-obsidian.backlinks").global_search()
    end, {})

    vim.api.nvim_create_user_command("ObsidianFollow", function()
        require("nvim-obsidian.link.wiki").follow()
    end, {})

    vim.api.nvim_create_user_command("ObsidianReindex", function()
        require("nvim-obsidian.cache.scanner").refresh_all_async(function()
            vim.notify("nvim-obsidian: reindex complete", vim.log.levels.INFO)
        end)
    end, {})
end

return M
