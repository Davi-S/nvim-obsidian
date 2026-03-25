local writer = require("nvim-obsidian.note.writer")
local template = require("nvim-obsidian.template")

describe("integration writer and router", function()
    local root

    local function read_file(filepath)
        return table.concat(vim.fn.readfile(filepath), "\n")
    end

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        vim.fn.mkdir(root .. "/08 Templates", "p")

        template._reset_for_tests()
        template.register_placeholder("title", function(ctx)
            return ctx.note.title
        end)
        template.register_placeholder("date", function(ctx)
            return ctx.time.iso.date
        end)

        vim.fn.writefile({ "# {{title}}", "Date: {{date}}" }, root .. "/08 Templates/Standard.md")
        vim.fn.writefile({ "---", "type: daily", "---", "# {{title}}" }, root .. "/08 Templates/Daily.md")
    end)

    after_each(function()
        template._reset_for_tests()
        vim.fn.delete(root, "rf")
    end)

    it("creates standard note from template and renders placeholders", function()
        local cfg = {
            vault_root = root,
            locale = "en-US",
            month_names = {
                [1] = "january", [2] = "february", [3] = "march", [4] = "april", [5] = "may", [6] = "june",
                [7] = "july", [8] = "august", [9] = "september", [10] = "october", [11] = "november", [12] = "december",
            },
            weekday_names = {
                [1] = "sunday", [2] = "monday", [3] = "tuesday", [4] = "wednesday", [5] = "thursday", [6] = "friday", [7] = "saturday",
            },
            journal_enabled = true,
            templates = { standard = "08 Templates/Standard" },
            journal = {
                templates = { daily = "08 Templates/Daily" },
            },
        }

        local target = root .. "/10 Novas notas/New Note.md"
        writer.ensure_note(target, "New Note", "standard", cfg)

        assert.are.equal(1, vim.fn.filereadable(target))
        local content = read_file(target)
        assert.is_truthy(content:find("# New Note", 1, true))
        assert.is_truthy(content:find("Date: ", 1, true))
    end)

    it("does not overwrite existing note content", function()
        local cfg = {
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
        }

        local target = root .. "/10 Novas notas/Keep Me.md"
        vim.fn.mkdir(root .. "/10 Novas notas", "p")
        vim.fn.writefile({ "ORIGINAL CONTENT" }, target)

        writer.ensure_note(target, "Keep Me", "standard", cfg)

        assert.are.equal("ORIGINAL CONTENT", read_file(target))
    end)
end)
