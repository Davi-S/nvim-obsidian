---@diagnostic disable: undefined-global

local config = require("nvim_obsidian.app.config")

describe("app config schema", function()
    it("requires vault_root", function()
        local ok, err = pcall(config.normalize, {})
        assert.is_false(ok)
        assert.matches("vault_root is required", tostring(err))
    end)

    it("requires absolute vault_root", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "relative/path",
        })
        assert.is_false(ok)
        assert.matches("vault_root must be an absolute path", tostring(err))
    end)

    it("applies phase-8 defaults deterministically", function()
        local opts = config.normalize({
            vault_root = "/tmp/nvim_obsidian_vault",
        })

        assert.equals("warn", opts.log_level)
        assert.equals("en-US", opts.locale)
        assert.equals("<S-CR>", opts.force_create_key)
        assert.equals("/tmp/nvim_obsidian_vault", opts.new_notes_subdir)
        assert.equals(true, opts.dataview.enabled)
        assert.same({ "on_open", "on_save" }, opts.dataview.render.when)
        assert.equals("event", opts.dataview.render.scope)
        assert.same({ "*.md" }, opts.dataview.render.patterns)
        assert.equals("below_block", opts.dataview.placement)
        assert.equals(true, opts.dataview.messages.task_no_results.enabled)
        assert.equals("Dataview: No results to show for task query.", opts.dataview.messages.task_no_results.text)
        assert.equals("sunday", opts.calendar.week_start)
        assert.equals("Title", opts.calendar.highlights.title)
        assert.equals("Comment", opts.calendar.highlights.weekday)
        assert.equals("Normal", opts.calendar.highlights.in_month_day)
        assert.equals("Comment", opts.calendar.highlights.outside_month_day)
        assert.equals("DiagnosticOk", opts.calendar.highlights.today)
        assert.equals("Bold", opts.calendar.highlights.note_exists)
        assert.equals(false, opts.calendar.confirm_before_create)
    end)

    it("accepts custom calendar highlight groups for day indicators", function()
        local opts = config.normalize({
            vault_root = "/tmp/nvim_obsidian_vault",
            calendar = {
                week_start = "monday",
                confirm_before_create = true,
                highlights = {
                    title = "MyCalendarTitle",
                    weekday = "MyCalendarWeekday",
                    in_month_day = "MyCalendarDay",
                    outside_month_day = "MyCalendarOutsideDay",
                    today = "MyCalendarToday",
                    note_exists = "MyCalendarHasNote",
                },
            },
        })

        assert.equals("monday", opts.calendar.week_start)
        assert.equals(true, opts.calendar.confirm_before_create)
        assert.equals("MyCalendarTitle", opts.calendar.highlights.title)
        assert.equals("MyCalendarWeekday", opts.calendar.highlights.weekday)
        assert.equals("MyCalendarDay", opts.calendar.highlights.in_month_day)
        assert.equals("MyCalendarOutsideDay", opts.calendar.highlights.outside_month_day)
        assert.equals("MyCalendarToday", opts.calendar.highlights.today)
        assert.equals("MyCalendarHasNote", opts.calendar.highlights.note_exists)
    end)

    it("does not mutate caller input tables", function()
        local user = {
            vault_root = "/tmp/nvim_obsidian_vault",
            dataview = {
                render = {
                    when = { "on_save" },
                },
            },
        }

        local before = vim.deepcopy(user)
        local _ = config.normalize(user)
        assert.same(before, user)
    end)

    it("rejects invalid log_level", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "/tmp/nvim_obsidian_vault",
            log_level = "debug",
        })
        assert.is_false(ok)
        assert.matches("log_level has invalid value", tostring(err))
    end)

    it("rejects invalid dataview render scope", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "/tmp/nvim_obsidian_vault",
            dataview = {
                render = {
                    scope = "workspace",
                },
            },
        })
        assert.is_false(ok)
        assert.matches("dataview.render.scope has invalid value", tostring(err))
    end)

    it("rejects invalid dataview render trigger", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "/tmp/nvim_obsidian_vault",
            dataview = {
                render = {
                    when = { "on_open", "on_write" },
                },
            },
        })
        assert.is_false(ok)
        assert.matches("dataview.render.when has invalid value", tostring(err))
    end)

    it("rejects invalid dataview placement", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "/tmp/nvim_obsidian_vault",
            dataview = {
                placement = "inline",
            },
        })
        assert.is_false(ok)
        assert.matches("dataview.placement has invalid value", tostring(err))
    end)

    it("rejects invalid dataview patterns type", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "/tmp/nvim_obsidian_vault",
            dataview = {
                render = {
                    patterns = "*.md",
                },
            },
        })
        assert.is_false(ok)
        assert.matches("dataview.render.patterns must be a list of strings", tostring(err))
    end)

    it("rejects invalid journal section shape when provided", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "/tmp/nvim_obsidian_vault",
            journal = {
                daily = {
                    subdir = "journal/daily",
                },
            },
        })
        assert.is_false(ok)
        assert.is_truthy(tostring(err):find("journal.daily.title_format must be a non-empty string", 1, true))
    end)

    it("rejects invalid calendar confirmation flag", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "/tmp/nvim_obsidian_vault",
            calendar = {
                confirm_before_create = "yes",
            },
        })

        assert.is_false(ok)
        assert.matches("calendar.confirm_before_create must be a boolean", tostring(err))
    end)

    it("accepts valid optional journal configuration", function()
        local opts = config.normalize({
            vault_root = "/tmp/nvim_obsidian_vault",
            journal = {
                daily = {
                    subdir = "journal/daily",
                    title_format = "{{year}}-{{month}}-{{day}}",
                },
                weekly = {
                    subdir = "journal/weekly",
                    title_format = "{{iso_year}}-W{{iso_week}}",
                },
            },
        })

        assert.equals("journal/daily", opts.journal.daily.subdir)
        assert.equals("journal/weekly", opts.journal.weekly.subdir)
    end)
end)
