local source = require("nvim-obsidian.cmp.source")
local vault = require("nvim-obsidian.model.vault")

describe("integration cmp source and vault", function()
    before_each(function()
        vault.reset()
        vault.upsert_note("/tmp/vault/Target Note.md", {
            aliases = { "Target Alias" },
            tags = { "x" },
            relpath = "Target Note.md",
            frontmatter = {},
            note_type = "standard",
        })
    end)

    after_each(function()
        vault.reset()
    end)

    it("returns title and alias completion items from vault notes", function()
        local cmp_source = source.new()
        local result = nil

        cmp_source:complete({ context = { cursor_before_line = "[[Tar" } }, function(payload)
            result = payload
        end)

        assert.is_table(result)
        assert.is_table(result.items)

        local has_title = false
        local has_alias = false
        for _, item in ipairs(result.items) do
            if item.label == "Target Note" and item.insertText == "Target Note]]" then
                has_title = true
            end
            if item.label == "Target Note | Target Alias" and item.insertText == "Target Note|Target Alias]]" then
                has_alias = true
            end
        end

        assert.is_true(has_title)
        assert.is_true(has_alias)
    end)
end)
