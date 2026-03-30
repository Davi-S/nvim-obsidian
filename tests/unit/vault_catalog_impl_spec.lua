---@diagnostic disable: undefined-global

local catalog = require("nvim_obsidian.core.domains.vault_catalog.impl")

describe("vault catalog domain implementation", function()
    before_each(function()
        catalog._reset_for_tests()
    end)

    it("upserts and replaces note identity by path", function()
        local first = catalog.upsert_note({
            path = "notes/alpha.md",
            title = "Alpha",
            aliases = { "A" },
        })
        assert.is_true(first.ok)

        local second = catalog.upsert_note({
            path = "notes/alpha.md",
            title = "Alpha v2",
            aliases = { "A2" },
        })
        assert.is_true(second.ok)

        local all = catalog._all_notes_for_tests()
        assert.are.equal(1, #all)
        assert.are.equal("Alpha v2", all[1].title)
        assert.are.same({ "A2" }, all[1].aliases)
    end)

    it("rejects invalid upsert payload", function()
        local bad = catalog.upsert_note({ path = "", title = "Alpha" })
        assert.is_false(bad.ok)
        assert.are.equal("invalid_input", bad.error.code)
    end)

    it("removes notes and returns not_found for missing path", function()
        catalog.upsert_note({ path = "notes/alpha.md", title = "Alpha", aliases = {} })

        local removed = catalog.remove_note("notes/alpha.md")
        assert.is_true(removed.ok)

        local missing = catalog.remove_note("notes/alpha.md")
        assert.is_false(missing.ok)
        assert.are.equal("not_found", missing.error.code)
    end)

    it("finds by exact title and alias with case-sensitive precedence", function()
        catalog.upsert_note({ path = "notes/alpha.md", title = "Alpha", aliases = { "A" } })
        catalog.upsert_note({ path = "notes/other.md", title = "alpha", aliases = { "a" } })

        local exact_title = catalog.find_by_identity_token("Alpha")
        assert.are.equal(1, #exact_title.matches)
        assert.are.equal("notes/alpha.md", exact_title.matches[1].path)

        local exact_alias = catalog.find_by_identity_token("A")
        assert.are.equal(1, #exact_alias.matches)
        assert.are.equal("notes/alpha.md", exact_alias.matches[1].path)
    end)

    it("falls back to case-insensitive exact matching and returns sorted", function()
        catalog.upsert_note({ path = "z/alpha.md", title = "Alpha", aliases = { "Tag" } })
        catalog.upsert_note({ path = "a/alpha.md", title = "alpha", aliases = { "tag" } })

        local ci = catalog.find_by_identity_token("ALPHA")
        assert.are.equal(2, #ci.matches)
        assert.are.equal("a/alpha.md", ci.matches[1].path)
        assert.are.equal("z/alpha.md", ci.matches[2].path)
    end)

    it("matches relpath/path tokens for omni selection", function()
        catalog.upsert_note({ path = "notes/foo.md", title = "Foo", aliases = {} })
        catalog.upsert_note({ path = "notes/bar.md", title = "Bar", aliases = {} })

        local exact_path = catalog.find_by_identity_token("notes/foo.md")
        assert.are.equal(1, #exact_path.matches)
        assert.are.equal("notes/foo.md", exact_path.matches[1].path)

        local ci_path = catalog.find_by_identity_token("NOTES/FOO.MD")
        assert.are.equal(1, #ci_path.matches)
        assert.are.equal("notes/foo.md", ci_path.matches[1].path)
    end)

    it("supports strict case-sensitive lookup mode", function()
        catalog.upsert_note({ path = "notes/foo.md", title = "Foo", aliases = { "Alias" } })

        local strict_miss = catalog.find_by_identity_token("foo", { case_sensitive_only = true })
        assert.are.equal(0, #strict_miss.matches)

        local strict_hit = catalog.find_by_identity_token("Foo", { case_sensitive_only = true })
        assert.are.equal(1, #strict_hit.matches)
        assert.are.equal("notes/foo.md", strict_hit.matches[1].path)
    end)
end)
