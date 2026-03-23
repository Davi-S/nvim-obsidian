local router = require("nvim-obsidian.journal.router")

describe("journal router", function()
    it("classifies note types from input", function()
        local cfg = {
            journal_enabled = true,
            journal = {
                title_formats = {
                    daily = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
                    weekly = "{{iso_year}} semana {{iso_week}}",
                    monthly = "{{year}} {{month_name}}",
                    yearly = "{{year}}",
                },
            },
        }

        local t1 = router.classify_input("2024", cfg)
        local t2 = router.classify_input("2024 semana 16", cfg)
        local t3 = router.classify_input("2024 abril", cfg)
        local t4 = router.classify_input("2026 marco 21, sabado", cfg)
        local t5 = router.classify_input("My Standard Note", cfg)

        assert.are.equal("yearly", t1)
        assert.are.equal("weekly", t2)
        assert.are.equal("monthly", t3)
        assert.are.equal("daily", t4)
        assert.are.equal("standard", t5)
    end)

    it("disables journal type classification when journal is not configured", function()
        local cfg = { journal_enabled = false }
        local note_type = router.classify_input("2024 semana 16", cfg)
        assert.are.equal("standard", note_type)
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
