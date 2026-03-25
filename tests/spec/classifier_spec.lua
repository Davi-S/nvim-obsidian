local classifier = require("nvim-obsidian.journal.classifier")

describe("journal classifier", function()
    it("classifies title input using title formats", function()
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

        local t1 = classifier.classify_title("2024", cfg)
        local t2 = classifier.classify_title("2024 semana 16", cfg)
        local t3 = classifier.classify_title("2024 abril", cfg)
        local t4 = classifier.classify_title("2026 marco 21, sabado", cfg)
        local t5 = classifier.classify_title("My Standard Note", cfg)

        assert.are.equal("yearly", t1)
        assert.are.equal("weekly", t2)
        assert.are.equal("monthly", t3)
        assert.are.equal("daily", t4)
        assert.are.equal("standard", t5)
    end)

    it("returns standard when journal is disabled", function()
        local cfg = { journal_enabled = false }
        local note_type = classifier.classify_title("2024 semana 16", cfg)
        assert.are.equal("standard", note_type)
    end)

    it("classifies note type by path parent directory", function()
        local cfg = {
            journal_enabled = true,
            journal = {
                daily = { dir_abs = "/vault/11 Diario/11.01 Diario" },
                weekly = { dir_abs = "/vault/11 Diario/11.02 Semanal" },
                monthly = { dir_abs = "/vault/11 Diario/11.03 Mensal" },
                yearly = { dir_abs = "/vault/11 Diario/11.04 Anual" },
            },
        }

        assert.are.equal("daily", classifier.note_type_for_path("/vault/11 Diario/11.01 Diario/Today.md", cfg))
        assert.are.equal("weekly", classifier.note_type_for_path("/vault/11 Diario/11.02 Semanal/Week.md", cfg))
        assert.are.equal("monthly", classifier.note_type_for_path("/vault/11 Diario/11.03 Mensal/Month.md", cfg))
        assert.are.equal("yearly", classifier.note_type_for_path("/vault/11 Diario/11.04 Anual/2026.md", cfg))
        assert.are.equal("standard", classifier.note_type_for_path("/vault/10 Novas notas/Note.md", cfg))
    end)
end)