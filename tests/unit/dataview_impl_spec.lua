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
        assert.equals("notes", out.blocks[2].query.from_value)
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
                where_title_eq = nil,
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
        assert.equals("- [ ] [[2024-01-01]]", out.result.rendered_lines[1])
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
                where_title_eq = "Alpha",
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
end)
