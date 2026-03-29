local dataview = require("nvim_obsidian.core.domains.dataview.impl")

describe("dataview domain impl", function()
    it("parses multiple dataview fenced blocks", function()
        local markdown = table.concat({
            "# Note",
            "",
            "```dataview",
            "TASK",
            "FROM \"journal\"",
            "```",
            "",
            "```dataview",
            "TABLE WITHOUT ID",
            'file.link AS "Title",',
            'file.path AS "Path"',
            "FROM \"notes\"",
            "```",
        }, "\n")

        local out = dataview.parse_blocks(markdown)
        assert.is_nil(out.error)
        assert.equals(2, #out.blocks)
        assert.equals("task", out.blocks[1].query.kind)
        assert.equals("table", out.blocks[2].query.kind)
    end)

    it("returns parse failure for invalid query", function()
        local markdown = table.concat({
            "```dataview",
            "LIST",
            "FROM \"journal\"",
            "```",
        }, "\n")

        local out = dataview.parse_blocks(markdown)
        assert.is_not_nil(out.error)
        assert.equals("parse_failure", out.error.code)
    end)

    it("executes TASK query with deterministic ordering", function()
        local block = {
            query = {
                kind = "task",
                from_kind = "path",
                from_value = "journal",
                where_expr = nil,
                sort_field = nil,
                sort_dir = "ASC",
            },
        }

        local notes = {
            { path = "journal/2024-01-02.md", title = "2024-01-02" },
            { path = "misc/a.md",             title = "Ignore" },
            { path = "journal/2024-01-01.md", title = "2024-01-01" },
        }

        local out = dataview.execute_query(block, notes)
        assert.is_nil(out.error)
        assert.equals("task", out.result.kind)
        assert.equals(2, #out.result.rows)
        assert.equals("journal/2024-01-01.md", out.result.rows[1].file.path)
    end)

    it("executes TABLE query with WHERE and SORT", function()
        local block = {
            query = {
                kind = "table",
                from_kind = "path",
                from_value = "notes",
                projections = {
                    { expr = "file.link", label = "Title" },
                    { expr = "file.path", label = "Path" },
                },
                where_expr = "title = Alpha",
                sort_field = "title",
                sort_dir = "DESC",
            },
        }

        local notes = {
            { path = "notes/a.md", title = "Alpha" },
            { path = "notes/b.md", title = "Beta" },
            { path = "other/c.md", title = "Alpha" },
        }

        local out = dataview.execute_query(block, notes)
        assert.is_nil(out.error)
        assert.equals("table", out.result.kind)
        assert.equals(1, #out.result.rows)
        assert.same({ "Alpha", "notes/a.md" }, out.result.rows[1])
    end)

    it("validates execute_query input", function()
        local out = dataview.execute_query("bad", {})
        assert.is_not_nil(out.error)
        assert.equals("invalid_input", out.error.code)
    end)

    it("filters deterministically for FROM #tag", function()
        local block = {
            query = {
                kind = "task",
                from_kind = "tag",
                from_value = "work",
                where_expr = nil,
                sort_field = nil,
                sort_dir = "ASC",
            },
        }

        local notes = {
            { path = "notes/1.md", title = "A", tags = { "#work" } },
            { path = "notes/2.md", title = "B", tags = { "home" } },
            { path = "notes/3.md", title = "C", tags = { "work", "x" } },
            { path = "notes/4.md", title = "D" },
        }

        local out = dataview.execute_query(block, notes)
        assert.is_nil(out.error)
        assert.equals("task", out.result.kind)
        assert.equals(2, #out.result.rows)
        assert.equals("notes/1.md", out.result.rows[1].file.path)
        assert.equals("notes/3.md", out.result.rows[2].file.path)
    end)

    it("parses TASK query with where/group/sort clauses", function()
        local markdown = table.concat({
            "```dataview",
            "TASK",
            "FROM \"11 Diario/11.01 Diario\"",
            "WHERE !checked AND file.link.date > date(2026-03-29) AND file.link.date < date(2026-04-05)",
            "GROUP BY file.link AS foo",
            "SORT foo.date ASC",
            "```",
        }, "\n")

        local out = dataview.parse_blocks(markdown)
        assert.is_nil(out.error)
        assert.equals(1, #out.blocks)
        assert.equals("task", out.blocks[1].query.kind)
        assert.equals("file.link", out.blocks[1].query.group_by)
        assert.equals("foo", out.blocks[1].query.group_alias)
        assert.equals("foo.date", out.blocks[1].query.sort_field)
    end)

    it("executes TASK where/group/sort with checked and date filters", function()
        local block = {
            query = {
                kind = "task",
                from_kind = "path",
                from_value = "11 Diario/11.01 Diario",
                where_expr = "!checked AND file.link.date > date(2026-03-29) AND file.link.date < date(2026-04-05)",
                group_by = "file.link",
                group_alias = "foo",
                sort_field = "foo.date",
                sort_dir = "ASC",
            },
        }

        local notes = {
            {
                checked = false,
                text = "Task A",
                raw = "- [ ] Task A",
                file = {
                    path = "/vault/11 Diario/11.01 Diario/2026-03-30.md",
                    title = "2026-03-30",
                    link = { date = os.time({ year = 2026, month = 3, day = 30, hour = 12 }) },
                },
            },
            {
                checked = false,
                text = "Task B",
                raw = "- [ ] Task B",
                file = {
                    path = "/vault/11 Diario/11.01 Diario/2026-04-02.md",
                    title = "2026-04-02",
                    link = { date = os.time({ year = 2026, month = 4, day = 2, hour = 12 }) },
                },
            },
            {
                checked = true,
                text = "Task done",
                raw = "- [x] Task done",
                file = {
                    path = "/vault/11 Diario/11.01 Diario/2026-03-31.md",
                    title = "2026-03-31",
                    link = { date = os.time({ year = 2026, month = 3, day = 31, hour = 12 }) },
                },
            },
            {
                checked = false,
                text = "Outside folder",
                raw = "- [ ] Outside folder",
                file = {
                    path = "/vault/other/2026-03-31.md",
                    title = "2026-03-31",
                    link = { date = os.time({ year = 2026, month = 3, day = 31, hour = 12 }) },
                },
            },
        }

        local out = dataview.execute_query(block, notes)
        assert.is_nil(out.error)
        assert.equals("task", out.result.kind)
        assert.equals(2, #out.result.rows)
        assert.equals("/vault/11 Diario/11.01 Diario/2026-03-30.md", out.result.rows[1].file.path)
        assert.equals("/vault/11 Diario/11.01 Diario/2026-04-02.md", out.result.rows[2].file.path)
        -- Check rendered_lines include file header and tasks with highlights
        assert.equals("2026-03-30", out.result.rendered_lines[1].text)
        assert.equals("header", out.result.rendered_lines[1].highlight)
        assert.equals("", out.result.rendered_lines[2].text)
        assert.equals("task_text", out.result.rendered_lines[2].highlight)
        assert.equals("- [ ] Task A", out.result.rendered_lines[3].text)
        assert.equals("task_text", out.result.rendered_lines[3].highlight)
        assert.equals("", out.result.rendered_lines[4].text)
        assert.equals("task_text", out.result.rendered_lines[4].highlight)
        assert.equals("2026-04-02", out.result.rendered_lines[5].text)
        assert.equals("header", out.result.rendered_lines[5].highlight)
        assert.equals("", out.result.rendered_lines[6].text)
        assert.equals("task_text", out.result.rendered_lines[6].highlight)
        assert.equals("- [ ] Task B", out.result.rendered_lines[7].text)
        assert.equals("task_text", out.result.rendered_lines[7].highlight)
    end)
end)
