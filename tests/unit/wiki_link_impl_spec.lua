---@diagnostic disable: undefined-global

local wiki = require("nvim_obsidian.core.domains.wiki_link.impl")

describe("wiki link domain implementation", function()
    it("parses wikilink under cursor with alias and heading", function()
        local line = "See [[Target Note#Heading|Alias]] now"
        local parsed = wiki.parse_at_cursor(line, 8)

        assert.is_nil(parsed.error)
        assert.is_not_nil(parsed.target)
        assert.are.equal("Target Note", parsed.target.note_ref)
        assert.are.equal("Heading", parsed.target.anchor)
        assert.are.equal(nil, parsed.target.block_id)
        assert.are.equal("Alias", parsed.target.display_alias)
    end)

    it("parses block-id and heading-only links", function()
        local block_line = "- [[Daily Note#^abc123|Task Ref]]"
        local block_parsed = wiki.parse_at_cursor(block_line, 6)
        assert.are.equal("Daily Note", block_parsed.target.note_ref)
        assert.are.equal("abc123", block_parsed.target.block_id)
        assert.is_nil(block_parsed.target.anchor)

        local heading_only = wiki.parse_at_cursor("[[#Objectives]]", 4)
        assert.are.equal("", heading_only.target.note_ref)
        assert.are.equal("Objectives", heading_only.target.anchor)
    end)

    it("returns nil target when cursor is not inside a wikilink", function()
        local parsed = wiki.parse_at_cursor("plain text only", 4)
        assert.is_nil(parsed.error)
        assert.is_nil(parsed.target)
    end)

    it("resolves target by title, alias, and path token", function()
        local notes = {
            { title = "Target", aliases = { "T" },     path = "notes/Target.md" },
            { title = "Other",  aliases = { "Alias" }, path = "notes/Other.md" },
        }

        local by_title = wiki.resolve_target({ note_ref = "Target" }, notes)
        assert.are.equal("resolved", by_title.status)
        assert.are.equal("notes/Target.md", by_title.resolved_path)

        local by_alias = wiki.resolve_target({ note_ref = "Alias" }, notes)
        assert.are.equal("resolved", by_alias.status)
        assert.are.equal("notes/Other.md", by_alias.resolved_path)

        local by_path = wiki.resolve_target({ note_ref = "notes/Target" }, notes)
        assert.are.equal("resolved", by_path.status)
        assert.are.equal("notes/Target.md", by_path.resolved_path)
    end)

    it("returns missing or ambiguous deterministically", function()
        local notes = {
            { title = "foo", aliases = {}, path = "bar/foo.md" },
            { title = "foo", aliases = {}, path = "baz/foo.md" },
        }

        local missing = wiki.resolve_target({ note_ref = "unknown" }, notes)
        assert.are.equal("missing", missing.status)
        assert.is_nil(missing.resolved_path)

        local ambiguous = wiki.resolve_target({ note_ref = "foo" }, notes)
        assert.are.equal("ambiguous", ambiguous.status)
        assert.are.equal(2, #ambiguous.ambiguous_matches)
        assert.are.equal("bar/foo.md", ambiguous.ambiguous_matches[1].path)
        assert.are.equal("baz/foo.md", ambiguous.ambiguous_matches[2].path)
    end)
end)
