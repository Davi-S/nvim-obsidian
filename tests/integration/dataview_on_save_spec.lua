local config = require("nvim-obsidian.config")
local vault = require("nvim-obsidian.model.vault")
local dataview_engine = require("nvim-obsidian.dataview.engine")
local journal_registry = require("nvim-obsidian.journal.placeholder_registry")

describe("integration dataview on save", function()
    local root

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        vim.fn.mkdir(root .. "/11 Diario/11.01 Diario", "p")
        vim.fn.mkdir(root .. "/10 Novas notas", "p")

        journal_registry.reset_for_tests()
        journal_registry.register_placeholder("year", function(ctx)
            return tostring(ctx.date.year)
        end, "(%d%d%d%d)")
        journal_registry.register_placeholder("iso_year", function(ctx)
            return tostring(ctx.date.iso_year)
        end, "(%d%d%d%d)")
        journal_registry.register_placeholder("month_name", function(ctx)
            return ctx.locale.month_name or ""
        end, "(.+)")
        journal_registry.register_placeholder("day2", function(ctx)
            return string.format("%02d", ctx.date.day or 0)
        end, "(%d%d?)")
        journal_registry.register_placeholder("weekday_name", function(ctx)
            return ctx.locale.weekday_name or ""
        end, "(.+)")
        journal_registry.register_placeholder("iso_week", function(ctx)
            return tostring(ctx.date.iso_week)
        end, "(%d%d?)")

        local cfg = config.resolve({
            vault_root = root,
            locale = "pt-BR",
            new_notes_subdir = "10 Novas notas",
            journal = {
                daily = {
                    subdir = "11 Diario/11.01 Diario",
                    title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
                },
                weekly = {
                    subdir = "11 Diario/11.02 Semanal",
                    title_format = "{{iso_year}} semana {{iso_week}}",
                },
                monthly = {
                    subdir = "11 Diario/11.03 Mensal",
                    title_format = "{{year}} {{month_name}}",
                },
                yearly = {
                    subdir = "11 Diario/11.04 Anual",
                    title_format = "{{year}}",
                },
            },
        })
        config.set(cfg)

        local source_file = root .. "/11 Diario/11.01 Diario/2026 março 26, quinta-feira.md"
        vim.fn.writefile({ "- [ ] tarefa dataview" }, source_file)

        vault.reset()
        vault.upsert_note(source_file, {
            relpath = "11 Diario/11.01 Diario/2026 março 26, quinta-feira.md",
            aliases = {},
            tags = {},
            frontmatter = {},
            note_type = "daily",
        })

        dataview_engine.setup_autocmds()
    end)

    after_each(function()
        vault.reset()
        vim.fn.delete(root, "rf")
    end)

    it("renders dataview block on save", function()
        local dv_file = root .. "/10 Novas notas/Query.md"
        vim.fn.writefile({
            "```dataview",
            "TASK",
            "FROM \"11 Diario/11.01 Diario\"",
            "WHERE !checked",
            "GROUP BY file.link AS foo",
            "SORT foo.date ASC",
            "```",
        }, dv_file)

        vim.cmd("edit " .. vim.fn.fnameescape(dv_file))
        vim.cmd("write")

        local ns = vim.api.nvim_create_namespace("nvim-obsidian-dataview")
        local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
        assert.is_true(#marks >= 1)

        local virt = marks[1][4].virt_lines
        assert.is_true(type(virt) == "table" and #virt >= 4)
        assert.are.equal("2026 março 26, quinta-feira", virt[1][1][1])
        assert.are.equal("", virt[2][1][1])
        assert.are.equal("- [ ] tarefa dataview", virt[3][1][1])
    end)

    it("renders in already-open markdown buffer when refreshed after cache ready", function()
        local dv_file = root .. "/10 Novas notas/Query aberta antes cache.md"
        vim.fn.writefile({
            "```dataview",
            "TASK",
            "FROM \"11 Diario/11.01 Diario\"",
            "WHERE !checked",
            "GROUP BY file.link AS foo",
            "SORT foo.date ASC",
            "```",
        }, dv_file)

        vim.cmd("edit " .. vim.fn.fnameescape(dv_file))

        local ns = vim.api.nvim_create_namespace("nvim-obsidian-dataview")
        local before = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
        assert.are.equal(0, #before)

        dataview_engine.refresh_open_markdown_buffers()

        local after = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
        assert.is_true(#after >= 1)
    end)
end)
