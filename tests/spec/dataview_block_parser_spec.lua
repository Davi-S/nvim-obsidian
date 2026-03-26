local parser = require("nvim-obsidian.dataview.block_parser")

describe("dataview block parser", function()
    it("finds fenced dataview blocks", function()
        local blocks = parser.find_blocks({
            "# Title",
            "```dataview",
            "TASK",
            "FROM \"11 Diario\"",
            "```",
        })

        assert.are.equal(1, #blocks)
        assert.are.equal(2, blocks[1].start_line)
        assert.are.equal(5, blocks[1].end_line)
    end)

    it("parses a TASK query with where/group/sort", function()
        local q, err = parser.parse_query({
            "TASK",
            "FROM \"11 Diario/11.01 Diario\"",
            "WHERE !checked AND file.link.date > date(2026-03-25)",
            "GROUP BY file.link AS foo",
            "SORT foo.date ASC",
        })

        assert.is_nil(err)
        assert.are.equal("TASK", q.kind)
        assert.are.equal("11 Diario/11.01 Diario", q.from)
        assert.are.equal("foo", q.group_alias)
        assert.are.equal("foo.date", q.sort_field)
    end)
end)
