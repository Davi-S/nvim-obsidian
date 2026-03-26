local task_source = require("nvim-obsidian.dataview.task_source")
local path = require("nvim-obsidian.path")
local journal_registry = require("nvim-obsidian.journal.placeholder_registry")
local config = require("nvim-obsidian.config")

describe("dataview task source", function()
    local root

    before_each(function()
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

        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        vim.fn.mkdir(root .. "/11 Diario/11.01 Diario", "p")
        vim.fn.mkdir(root .. "/11 Diario/11.03 Mensal", "p")
        vim.fn.mkdir(root .. "/13 Outras", "p")

        vim.fn.writefile({ "- [ ] tarefa a", "- [x] tarefa b", "- [/] tarefa c" },
            root .. "/11 Diario/11.01 Diario/2026 março 26, quinta-feira.md")

        vim.fn.writefile({ "- [ ] tarefa mensal" },
            root .. "/11 Diario/11.03 Mensal/2026 março.md")

        vim.fn.writefile({ "---", "date: 2026-03-25", "---", "- [ ] tarefa fm" },
            root .. "/13 Outras/Nota com data.md")

        vim.fn.writefile({ "- [ ] tarefa sem data" },
            root .. "/13 Outras/Nota sem data.md")
    end)

    after_each(function()
        journal_registry.reset_for_tests()
        vim.fn.delete(root, "rf")
    end)

    it("collects tasks and recognizes checked as any marker char", function()
        local cfg = {
            vault_root = root,
            journal_enabled = true,
            month_names = {
                [1] = "janeiro",
                [2] = "fevereiro",
                [3] = "março",
                [4] = "abril",
                [5] = "maio",
                [6] = "junho",
                [7] = "julho",
                [8] = "agosto",
                [9] = "setembro",
                [10] = "outubro",
                [11] = "novembro",
                [12] = "dezembro",
            },
            weekday_names = {
                [1] = "domingo",
                [2] = "segunda-feira",
                [3] = "terca-feira",
                [4] = "quarta-feira",
                [5] = "quinta-feira",
                [6] = "sexta-feira",
                [7] = "sabado",
            },
            journal = {
                title_formats = {
                    daily = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
                    weekly = "{{iso_year}} semana {{iso_week}}",
                    monthly = "{{year}} {{month_name}}",
                    yearly = "{{year}}",
                },
                daily = { dir_abs = root .. "/11 Diario/11.01 Diario" },
                weekly = { dir_abs = root .. "/11 Diario/11.02 Semanal" },
                monthly = { dir_abs = root .. "/11 Diario/11.03 Mensal" },
                yearly = { dir_abs = root .. "/11 Diario/11.04 Anual" },
            },
        }

        local notes = {
            {
                filepath = path.normalize(root .. "/11 Diario/11.01 Diario/2026 março 26, quinta-feira.md"),
                relpath = "11 Diario/11.01 Diario/2026 março 26, quinta-feira.md",
                note_type = "daily",
                frontmatter = {},
            },
            {
                filepath = path.normalize(root .. "/11 Diario/11.03 Mensal/2026 março.md"),
                relpath = "11 Diario/11.03 Mensal/2026 março.md",
                note_type = "monthly",
                frontmatter = {},
            },
            {
                filepath = path.normalize(root .. "/13 Outras/Nota com data.md"),
                relpath = "13 Outras/Nota com data.md",
                note_type = "standard",
                frontmatter = { date = "2026-03-25" },
            },
            {
                filepath = path.normalize(root .. "/13 Outras/Nota sem data.md"),
                relpath = "13 Outras/Nota sem data.md",
                note_type = "standard",
                frontmatter = {},
            },
        }

        local tasks, errs = task_source.collect(notes, cfg, "")
        assert.are.equal(6, #tasks)

        local checked_count = 0
        for _, t in ipairs(tasks) do
            if t.checked then
                checked_count = checked_count + 1
            end
        end
        assert.are.equal(2, checked_count)
        assert.is_true(#errs >= 1)
    end)

    it("resolves dates from titles with Portuguese month names (with and without accents)", function()
        local root2 = vim.fn.tempname()
        vim.fn.mkdir(root2, "p")
        vim.fn.mkdir(root2 .. "/journal/daily", "p")

        -- Create notes with both "março" (accented) and "marco" (no accent)
        vim.fn.writefile({ "- [ ] task 1" }, root2 .. "/journal/daily/2026 março 22, domingo.md")
        vim.fn.writefile({ "- [ ] task 2" }, root2 .. "/journal/daily/2026 marco 26, segunda-feira.md")

        local cfg = config.resolve({
            vault_root = root2,
            locale = "pt-BR",
            journal = {
                daily = {
                    subdir = "journal/daily",
                    title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
                },
                weekly = {
                    subdir = "journal/weekly",
                    title_format = "{{iso_year}} semana {{iso_week}}",
                },
                monthly = {
                    subdir = "journal/monthly",
                    title_format = "{{year}} {{month_name}}",
                },
                yearly = {
                    subdir = "journal/yearly",
                    title_format = "{{year}}",
                },
            },
        })
        config.set(cfg)

        local vault_mod = require("nvim-obsidian.model.vault")
        vault_mod.reset()

        vault_mod.upsert_note(path.normalize(root2 .. "/journal/daily/2026 março 22, domingo.md"), {
            relpath = "journal/daily/2026 março 22, domingo.md",
            aliases = {},
            tags = {},
            frontmatter = {},
            note_type = "daily",
        })
        vault_mod.upsert_note(path.normalize(root2 .. "/journal/daily/2026 marco 26, segunda-feira.md"), {
            relpath = "journal/daily/2026 marco 26, segunda-feira.md",
            aliases = {},
            tags = {},
            frontmatter = {},
            note_type = "daily",
        })

        local notes = vault_mod.all_notes()
        local tasks, errs = task_source.collect(notes, cfg, "")

        -- Both notes should be parsed successfully (2 tasks total)
        assert.are.equal(2, #tasks)
        -- No errors should be reported (accents are handled)
        assert.are.equal(0, #errs)

        vim.fn.delete(root2, "rf")
        vault_mod.reset()
    end)

    it("preserves indentation for nested subtasks", function()
        local root2 = vim.fn.tempname()
        vim.fn.mkdir(root2, "p")
        vim.fn.mkdir(root2 .. "/11 Diario/11.01 Diario", "p")

        local source_file = root2 .. "/11 Diario/11.01 Diario/2026 março 26, quinta-feira.md"
        vim.fn.writefile({
            "- [ ] T - Tirar passaporte",
            "\t- [ ] Protocolo 1.2026.0001092228",
            "\t- [ ] Levar: CHN e Certificado Militar",
        }, source_file)

        local cfg = config.resolve({
            vault_root = root2,
            locale = "pt-BR",
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

        local notes = {
            {
                filepath = path.normalize(source_file),
                relpath = "11 Diario/11.01 Diario/2026 março 26, quinta-feira.md",
                note_type = "daily",
                frontmatter = {},
            },
        }

        local tasks, errs = task_source.collect(notes, cfg, "11 Diario/11.01 Diario")
        assert.are.equal(3, #tasks)
        assert.are.equal(0, #errs)
        assert.are.equal("- [ ] T - Tirar passaporte", tasks[1].raw)
        assert.are.equal("\t- [ ] Protocolo 1.2026.0001092228", tasks[2].raw)
        assert.are.equal("\t- [ ] Levar: CHN e Certificado Militar", tasks[3].raw)

        vim.fn.delete(root2, "rf")
    end)
end)
