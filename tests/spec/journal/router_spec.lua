local router = require("nvim-obsidian.journal.router")
local fixtures = require("tests.spec.support.fixtures")
local journal_registry = require("nvim-obsidian.journal.placeholder_registry")

describe("journal router", function()
    before_each(function()
        journal_registry.reset_for_tests()
    end)

    it("routes standard and journal files to expected folders", function()
        local cfg = fixtures.journal_cfg("/vault")

        assert.are.equal(
            "/vault/10 Novas notas/Minha Nota.md",
            router.path_for_type("standard", "Minha Nota", cfg)
        )

        assert.are.equal(
            "/vault/11 Diario/11.01 Diario/2026 marco 21, sabado.md",
            router.path_for_type("daily", "2026 marco 21, sabado", cfg)
        )
    end)
end)
