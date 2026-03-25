local ranker = require("nvim-obsidian.ranker")
local fixtures = require("tests.spec.support.fixtures")

describe("picker ranker", function()
    it("shows title -> path when query is empty", function()
        local entry = ranker.build_entry(fixtures.note({
            title = "My Note",
            aliases = { "alias-a" },
            relpath = "14 UFPR BBC/My Note.md",
        }), "")

        assert.are.equal("My Note  ->  14 UFPR BBC/My Note.md", entry.display)
    end)

    it("shows alias -> path when alias matches and title does not", function()
        local entry = ranker.build_entry(fixtures.note({
            title = "Universidade Federal do Parana",
            aliases = { "ufpr" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        }), "ufpr")

        assert.are.equal("ufpr  ->  14 UFPR BBC/Universidade Federal do Parana.md", entry.display)
    end)

    it("shows title -> path when title matches even if alias also matches", function()
        local entry = ranker.build_entry(fixtures.note({
            title = "UFPR Notes",
            aliases = { "ufpr" },
            relpath = "14 UFPR BBC/UFPR Notes.md",
        }), "ufpr")

        assert.are.equal("UFPR Notes  ->  14 UFPR BBC/UFPR Notes.md", entry.display)
    end)

    it("ordinal includes title, aliases, and relpath with path last", function()
        local entry = ranker.build_entry(fixtures.note({
            title = "Universidade Federal do Parana",
            aliases = { "ufpr", "federal pr" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        }), "ufpr")

        assert.are.equal(
            "universidade federal do parana ufpr federal pr 14 ufpr bbc/universidade federal do parana.md",
            entry.ordinal
        )
    end)

    it("computes match context for title, alias and path", function()
        local note = fixtures.note({
            title = "Universidade Federal do Parana",
            aliases = { "ufpr", "federal pr" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        })

        local title_ctx = ranker.compute_match_context(note, "universidade")
        assert.is_true(title_ctx.title_match)
        assert.is_false(title_ctx.alias_match)
        assert.is_true(title_ctx.path_match)

        local alias_ctx = ranker.compute_match_context(note, "ufpr")
        assert.is_false(alias_ctx.title_match)
        assert.is_true(alias_ctx.alias_match)
        assert.are.equal("ufpr", alias_ctx.matched_alias)
        assert.is_true(alias_ctx.path_match)

        local path_ctx = ranker.compute_match_context(note, "14 ufpr")
        assert.is_false(path_ctx.title_match)
        assert.is_false(path_ctx.alias_match)
        assert.is_true(path_ctx.path_match)
    end)

    it("ordinal text policy keeps relpath last", function()
        local ordinal = ranker.compute_ordinal_text(fixtures.note({
            title = "A",
            aliases = { "b", "c" },
            relpath = "d/e.md",
        }))

        assert.are.equal("a b c d/e.md", ordinal)
    end)

    it("matches aliases case-insensitively", function()
        local note = fixtures.note({
            title = "Universidade Federal do Parana",
            aliases = { "ufpr" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        })

        local ctx = ranker.compute_match_context(note, "UFPR")
        assert.is_true(ctx.alias_exact)
        assert.is_true(ctx.alias_match)
        assert.are.equal("ufpr", ctx.matched_alias)
    end)
end)
