local config = require("nvim-obsidian.config")
local template = require("nvim-obsidian.template")
local commands = require("nvim-obsidian.commands")

describe("integration insert template command", function()
    local root

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        vim.fn.mkdir(root .. "/08 Templates", "p")
        vim.fn.mkdir(root .. "/10 Novas notas", "p")

        vim.fn.writefile({ "# {{title}}", "Date: {{date}}" }, root .. "/08 Templates/Standard.md")
        vim.fn.writefile({ "# Existing" }, root .. "/10 Novas notas/Current.md")

        config.set({
            vault_root = root,
            locale = "en-US",
            month_names = {
                [1] = "january", [2] = "february", [3] = "march", [4] = "april", [5] = "may", [6] = "june",
                [7] = "july", [8] = "august", [9] = "september", [10] = "october", [11] = "november", [12] = "december",
            },
            weekday_names = {
                [1] = "sunday", [2] = "monday", [3] = "tuesday", [4] = "wednesday", [5] = "thursday", [6] = "friday", [7] = "saturday",
            },
            journal_enabled = false,
            templates = { standard = "08 Templates/Standard" },
            notes_dir_abs = root .. "/10 Novas notas",
        })

        template._reset_for_tests()
        template.register_placeholder("title", function(ctx)
            return ctx.note.title
        end)
        template.register_placeholder("date", function(ctx)
            return ctx.time.iso.date
        end)

        commands.register()
        vim.cmd("edit " .. vim.fn.fnameescape(root .. "/10 Novas notas/Current.md"))
    end)

    after_each(function()
        template._reset_for_tests()
        vim.cmd("silent! delcommand ObsidianInsertTemplate")
        vim.cmd("silent! delcommand ObsidianOmni")
        vim.cmd("silent! delcommand ObsidianBacklinks")
        vim.cmd("silent! delcommand ObsidianSearch")
        vim.cmd("silent! delcommand ObsidianFollow")
        vim.cmd("silent! delcommand ObsidianReindex")
        vim.fn.delete(root, "rf")
    end)

    it("inserts rendered template at cursor", function()
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.cmd("ObsidianInsertTemplate standard")

        local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
        assert.is_truthy(text:find("# Current", 1, true))
        assert.is_truthy(text:find("Date: ", 1, true))
        assert.is_truthy(text:find("# Existing", 1, true))
    end)
end)
