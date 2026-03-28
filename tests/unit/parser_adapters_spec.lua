---@diagnostic disable: undefined-global

local frontmatter = require("nvim_obsidian.adapters.parser.frontmatter")
local markdown = require("nvim_obsidian.adapters.parser.markdown")

describe("parser adapters", function()
    describe("frontmatter adapter", function()
        it("returns empty metadata when no frontmatter block exists", function()
            local meta, err = frontmatter.parse("# Note\ncontent")
            assert.is_table(meta)
            assert.equals(0, vim.tbl_count(meta))
            assert.is_nil(err)
        end)

        it("parses title and inline aliases list", function()
            local doc = table.concat({
                "---",
                "title: My Note",
                "aliases: [First Alias, Second Alias]",
                "---",
                "body",
            }, "\n")

            local meta, err = frontmatter.parse(doc)
            assert.is_nil(err)
            assert.equals("My Note", meta.title)
            assert.same({ "First Alias", "Second Alias" }, meta.aliases)
        end)

        it("parses multiline aliases list", function()
            local doc = table.concat({
                "---",
                "title: Daily",
                "aliases:",
                "  - Today",
                "  - Journal",
                "---",
            }, "\n")

            local meta, err = frontmatter.parse(doc)
            assert.is_nil(err)
            assert.equals("Daily", meta.title)
            assert.same({ "Today", "Journal" }, meta.aliases)
        end)

        it("does not parse frontmatter when delimiters are not at top", function()
            local doc = table.concat({
                "preface",
                "---",
                "title: Not Frontmatter",
                "---",
            }, "\n")

            local meta, err = frontmatter.parse(doc)
            assert.is_nil(err)
            assert.equals(0, vim.tbl_count(meta))
        end)

        it("returns parse_failure error for unclosed frontmatter", function()
            local doc = table.concat({
                "---",
                "title: Broken",
                "aliases: [A, B]",
            }, "\n")

            local meta, err = frontmatter.parse(doc)
            assert.is_table(meta)
            assert.is_string(err)
            assert.truthy(string.find(err, "parse_failure", 1, true))
        end)
    end)

    describe("markdown adapter", function()
        it("extracts plain wikilinks", function()
            local links = markdown.extract_wikilinks("Before [[Target Note]] after")
            assert.equals(1, #links)
            assert.equals("Target Note", links[1].note_ref)
            assert.is_nil(links[1].alias)
            assert.is_nil(links[1].heading)
            assert.is_nil(links[1].block)
        end)

        it("extracts wikilinks with alias", function()
            local links = markdown.extract_wikilinks("[[Target Note|Shown Label]]")
            assert.equals(1, #links)
            assert.equals("Target Note", links[1].note_ref)
            assert.equals("Shown Label", links[1].alias)
        end)

        it("extracts heading anchors", function()
            local links = markdown.extract_wikilinks("[[Target Note#Section Title]]")
            assert.equals(1, #links)
            assert.equals("Target Note", links[1].note_ref)
            assert.equals("Section Title", links[1].heading)
            assert.is_nil(links[1].block)
        end)

        it("extracts block anchors", function()
            local links = markdown.extract_wikilinks("[[Target Note#^block-id|Label]]")
            assert.equals(1, #links)
            assert.equals("Target Note", links[1].note_ref)
            assert.equals("block-id", links[1].block)
            assert.equals("Label", links[1].alias)
        end)

        it("returns empty list for invalid input", function()
            local links = markdown.extract_wikilinks(nil)
            assert.same({}, links)
        end)
    end)
end)
