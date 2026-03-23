local frontmatter = require("nvim-obsidian.parser.frontmatter")

describe("frontmatter parser", function()
    it("extracts root-level yaml metadata", function()
        local text = table.concat({
            "---",
            "aliases:",
            "  - A",
            "tags: [x]",
            "---",
            "",
            "# Title",
        }, "\n")

        local yaml = frontmatter.extract_root_yaml(text)
        assert.is_truthy(yaml)
        assert.is_truthy(yaml:find("aliases", 1, true))
    end)

    it("ignores horizontal rules in markdown body", function()
        local text = table.concat({
            "# Title",
            "",
            "---",
            "",
            "Body",
        }, "\n")

        local yaml = frontmatter.extract_root_yaml(text)
        assert.is_nil(yaml)
    end)

    it("normalizes aliases and tags lists", function()
        local text = table.concat({
            "---",
            "aliases: [A, B]",
            "tags:",
            "  - x",
            "  - y",
            "---",
            "# T",
        }, "\n")

        local parsed = frontmatter.parse(text)
        assert.are.same({ "A", "B" }, parsed.aliases)
        assert.are.same({ "x", "y" }, parsed.tags)
    end)
end)
