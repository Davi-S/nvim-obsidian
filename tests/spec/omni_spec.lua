local omni = require("nvim-obsidian.picker.omni")

describe("omni entry builder", function()
    it("shows title -> path when query is empty", function()
        local note = {
            title = "My Note",
            aliases = { "alias-a" },
            relpath = "14 UFPR BBC/My Note.md",
        }

        local entry = omni._test_build_entry(note, "")
        assert.are.equal("My Note  ->  14 UFPR BBC/My Note.md", entry.display)
    end)

    it("shows alias -> path when alias matches and title does not", function()
        local note = {
            title = "Universidade Federal do Parana",
            aliases = { "ufpr" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        }

        local entry = omni._test_build_entry(note, "ufpr")
        assert.are.equal("ufpr  ->  14 UFPR BBC/Universidade Federal do Parana.md", entry.display)
    end)

    it("shows title -> path when title matches even if alias also matches", function()
        local note = {
            title = "UFPR Notes",
            aliases = { "ufpr" },
            relpath = "14 UFPR BBC/UFPR Notes.md",
        }

        local entry = omni._test_build_entry(note, "ufpr")
        assert.are.equal("UFPR Notes  ->  14 UFPR BBC/UFPR Notes.md", entry.display)
    end)

    it("ordinal includes title, aliases, and relpath with path last", function()
        local note = {
            title = "Universidade Federal do Parana",
            aliases = { "ufpr", "federal pr" },
            relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
        }

        local entry = omni._test_build_entry(note, "ufpr")
        assert.are.equal(
            "universidade federal do parana ufpr federal pr 14 ufpr bbc/universidade federal do parana.md",
            entry.ordinal
        )
    end)
end)
