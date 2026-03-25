local config = require("nvim-obsidian.config")
local router = require("nvim-obsidian.journal.router")
local time_travel = require("nvim-obsidian.journal.time_travel")
local writer = require("nvim-obsidian.note.writer")
local template_commands = require("nvim-obsidian.template.commands")

local M = {}

function M.register()
    local cfg = config.get()

    vim.api.nvim_create_user_command("ObsidianOmni", function()
        require("nvim-obsidian.picker.omni").open()
    end, {})

    if cfg.journal_enabled then
        vim.api.nvim_create_user_command("ObsidianToday", function()
            local run_cfg = config.get()
            local note_type, title, filepath = router.today_daily(run_cfg)
            writer.ensure_and_open(filepath, title, note_type, run_cfg)
        end, {})

        vim.api.nvim_create_user_command("ObsidianNext", function()
            local run_cfg = config.get()
            local note_type, title, filepath = time_travel.open_relative(1)
            writer.ensure_and_open(filepath, title, note_type, run_cfg)
        end, {})

        vim.api.nvim_create_user_command("ObsidianPrev", function()
            local run_cfg = config.get()
            local note_type, title, filepath = time_travel.open_relative(-1)
            writer.ensure_and_open(filepath, title, note_type, run_cfg)
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

    -- ObsidianInsertTemplate: Insert rendered template at cursor
    -- Arguments:
    --   [none]  - auto-detect note type from current buffer
    --   standard/daily/weekly/monthly/yearly - use configured template for that type
    --   ./path or /abs/path - load template from file and render it
    vim.api.nvim_create_user_command("ObsidianInsertTemplate", function(opts)
        template_commands.insert_at_cursor(vim.trim(opts.args or ""))
    end, {
        nargs = "?",
        complete = function()
            return { "standard", "daily", "weekly", "monthly", "yearly" }
        end,
        desc = "Insert a template at cursor. Arg can be a note type (standard/daily/weekly/monthly/yearly) or a path to a template file.",
    })
end

return M
