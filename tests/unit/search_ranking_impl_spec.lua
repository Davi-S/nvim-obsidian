---@diagnostic disable: undefined-global

local ranking = require("nvim_obsidian.core.domains.search_ranking.impl")

describe("search ranking domain implementation", function()
    local candidates = {
        {
            title = "Universidade Federal do Parana",
            aliases = { "UFPR" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        },
        {
            title = "UFPR Notes",
            aliases = { "Federal PR" },
            relpath = "14 UFPR BBC/UFPR Notes.md",
        },
        {
            title = "Lucas Leal",
            aliases = { "Lucas (ufpr)" },
            relpath = "13 Pessoas/Lucas Leal.md",
        },
        {
            title = "Random",
            aliases = {},
            relpath = "14 UFPR BBC/Random.md",
        },
    }

    it("scores candidates with expected precedence", function()
        local result = ranking.score_candidates("ufpr", candidates)
        local ranked = result.ranked

        assert.are.equal(4, #ranked)
        assert.are.equal("Universidade Federal do Parana", ranked[1].title)
        assert.are.equal(1, ranked[1].rank)
        assert.are.equal("Lucas Leal", ranked[2].title)
        assert.are.equal(2, ranked[2].rank)
        assert.are.equal("UFPR Notes", ranked[3].title)
        assert.are.equal(4, ranked[3].rank)
        assert.are.equal("Random", ranked[4].title)
        assert.are.equal(5, ranked[4].rank)
    end)

    it("returns deterministic alphabetical order for ties", function()
        local result = ranking.score_candidates("notes", {
            { title = "b notes", aliases = {}, relpath = "b/path.md" },
            { title = "a notes", aliases = {}, relpath = "a/path.md" },
        })

        assert.are.equal("a notes", result.ranked[1].title)
        assert.are.equal("b notes", result.ranked[2].title)
    end)

    it("selects alias display when alias matched but title did not", function()
        local label = ranking.select_display("ufpr", {
            title = "Universidade Federal do Parana",
            aliases = { "UFPR" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        }, "->").label

        assert.are.equal("UFPR -> 14 UFPR BBC/Universidade Federal do Parana.md", label)
    end)

    it("keeps title display when title matched", function()
        local label = ranking.select_display("ufpr", {
            title = "UFPR Notes",
            aliases = { "Federal PR" },
            relpath = "14 UFPR BBC/UFPR Notes.md",
        }, "->").label

        assert.are.equal("UFPR Notes -> 14 UFPR BBC/UFPR Notes.md", label)
    end)

    it("uses default separator when missing", function()
        local label = ranking.select_display("", {
            title = "Project Alpha",
            aliases = {},
            relpath = "notes/project-alpha.md",
        }).label

        assert.are.equal("Project Alpha -> notes/project-alpha.md", label)
    end)
end)
