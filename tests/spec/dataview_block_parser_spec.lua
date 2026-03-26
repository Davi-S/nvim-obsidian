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

    it("parses a TABLE WITHOUT ID query with projections and tag source", function()
        local q, err = parser.parse_query({
            "TABLE WITHOUT ID",
            "file.link AS \"Pessoa\",",
            "nascimento.day AS \"Dia\",",
            "2026 - nascimento.year AS \"Idade\"",
            "FROM #pessoa",
            "WHERE nascimento.month = 03 AND !óbito",
            "SORT nascimento.day ASC",
        })

        assert.is_nil(err)
        assert.are.equal("TABLE", q.kind)
        assert.are.equal("tag", q.from_kind)
        assert.are.equal("pessoa", q.from)
        assert.are.equal(3, #q.projections)
        assert.are.equal("Pessoa", q.projections[1].label)
        assert.are.equal("nascimento.day", q.sort_field)
    end)
end)
