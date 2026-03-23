local router = require("nvim-obsidian.journal.router")

describe("journal router", function()
    it("classifies note types from input", function()
        local t1 = router.classify_input("2024")
        local t2 = router.classify_input("2024 semana 16")
        local t3 = router.classify_input("2024 abril")
        local t4 = router.classify_input("2026 marco 21, sabado")
        local t5 = router.classify_input("My Standard Note")

        assert.are.equal("yearly", t1)
        assert.are.equal("weekly", t2)
        assert.are.equal("monthly", t3)
        assert.are.equal("daily", t4)
        assert.are.equal("standard", t5)
    end)

    it("routes standard and journal files to expected folders", function()
        local cfg = {
            notes_dir_abs = "/vault/10 Novas notas",
            journal = {
                daily = { dir_abs = "/vault/11 Diario/11.01 Diario" },
                weekly = { dir_abs = "/vault/11 Diario/11.02 Semanal" },
                monthly = { dir_abs = "/vault/11 Diario/11.03 Mensal" },
                yearly = { dir_abs = "/vault/11 Diario/11.04 Anual" },
            },
        }

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
