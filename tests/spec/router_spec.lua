local router = require("nvim-obsidian.journal.router")

describe("journal router", function()
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
