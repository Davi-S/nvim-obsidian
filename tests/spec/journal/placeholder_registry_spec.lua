local registry = require("nvim-obsidian.journal.placeholder_registry")
local config = require("nvim-obsidian.config")

describe("journal placeholder registry", function()
    before_each(function()
        registry.reset_for_tests()
    end)

    it("registers and resolves placeholders with regex fragments", function()
        registry.register_placeholder("year", function(ctx)
            return tostring(ctx.date.year)
        end, "(%d%d%d%d)")

        assert.is_true(registry.has("year"))
        assert.are.equal("(%d%d%d%d)", registry.get_regex_fragment("year"))

        local value, ok = registry.resolve("year", {
            date = { year = 2026 },
        })

        assert.is_true(ok)
        assert.are.equal("2026", value)
    end)

    it("rejects invalid registration payloads", function()
        assert.has_error(function()
            registry.register_placeholder("", function() end, "(%d+)")
        end)

        assert.has_error(function()
            registry.register_placeholder("year", "not_fn", "(%d+)")
        end)

        assert.has_error(function()
            registry.register_placeholder("year", function() end, "")
        end)
    end)

    it("requires journal placeholders to be registered before setup", function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")

        local opts = {
            vault_root = root,
            locale = "en-US",
            journal = {
                daily = {
                    subdir = "daily",
                    title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
                },
                weekly = {
                    subdir = "weekly",
                    title_format = "{{iso_year}} week {{iso_week}}",
                },
                monthly = {
                    subdir = "monthly",
                    title_format = "{{year}} {{month_name}}",
                },
                yearly = {
                    subdir = "yearly",
                    title_format = "{{year}}",
                },
            },
        }

        assert.has_error(function()
            config.resolve(opts)
        end)

        registry.register_placeholder("year", function(ctx)
            return tostring(ctx.date.year)
        end, "(%d%d%d%d)")
        registry.register_placeholder("iso_year", function(ctx)
            return tostring(ctx.date.iso_year)
        end, "(%d%d%d%d)")
        registry.register_placeholder("month_name", function(ctx)
            return ctx.locale.month_name or ""
        end, "(.+)")
        registry.register_placeholder("day2", function(ctx)
            return string.format("%02d", ctx.date.day or 0)
        end, "(%d%d?)")
        registry.register_placeholder("weekday_name", function(ctx)
            return ctx.locale.weekday_name or ""
        end, "(.+)")
        registry.register_placeholder("iso_week", function(ctx)
            return tostring(ctx.date.iso_week)
        end, "(%d%d?)")

        local resolved = config.resolve(opts)
        assert.is_true(resolved.journal_enabled)

        vim.fn.delete(root, "rf")
    end)
end)
