local omni = require("nvim-obsidian.picker.omni")
local vault = require("nvim-obsidian.model.vault")
local fixtures = require("tests.spec.support.fixtures")

describe("omni picker", function()
    it("prioritizes exact alias before partial alias and path matches", function()
        local original_all_notes = vault.all_notes
        vault.all_notes = function()
            return {
                fixtures.note({
                    title = "Lucas Leal",
                    aliases = { "Lucas (ufpr)" },
                    relpath = "13 Pessoas/Lucas Leal.md",
                    filepath = "/vault/13 Pessoas/Lucas Leal.md",
                }),
                fixtures.note({
                    title = "Universidade Federal do Parana",
                    aliases = { "UFPR" },
                    relpath = "14 UFPR BBC/Universidade Federal do Parana.md",
                    filepath = "/vault/14 UFPR BBC/Universidade Federal do Parana.md",
                }),
                fixtures.note({
                    title = "Some Path Note",
                    aliases = {},
                    relpath = "15 Universidade/Random.md",
                    filepath = "/vault/15 Universidade/Random.md",
                }),
            }
        end

        local entries = omni._test_entries_from_cache("ufpr")
        assert.are.equal("Universidade Federal do Parana", entries[1].value.title)
        assert.are.equal("Lucas Leal", entries[2].value.title)

        vault.all_notes = original_all_notes
    end)
end)
