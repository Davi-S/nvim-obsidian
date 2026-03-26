local template = require("nvim-obsidian.template")

describe("template context", function()
    it("builds structured note and time objects", function()
        local ts = os.time({ year = 2026, month = 3, day = 25, hour = 12 })
        local ctx = template.build_context({
            cfg = {
                vault_root = "/vault",
                locale = "pt-BR",
                month_names = { [3] = "março" },
                weekday_names = { [4] = "quarta" },
            },
            title = "Minha Nota",
            note_type = "daily",
            note_abs_path = "/vault/11 Diario/11.01 Diario/Minha Nota.md",
            timestamp = ts,
        })

        assert.are.equal("Minha Nota", ctx.note.title)
        assert.are.equal("daily", ctx.note.type)
        assert.are.equal("11 Diario/11.01 Diario/Minha Nota.md", ctx.note.rel_path)
        assert.are.equal("março", ctx.time.locale.month_name)
        assert.are.equal("2026-03-25", ctx.time.iso.date)
        assert.is_truthy(ctx.time["local"])
        assert.is_truthy(ctx.time.utc)
    end)

    it("exposes config as read-only", function()
        local ctx = template.build_context({
            cfg = {
                vault_root = "/vault",
                locale = "en-US",
            },
            title = "A",
            note_type = "standard",
            note_abs_path = "/vault/A.md",
        })

        local ok = pcall(function()
            ctx.config.locale = "pt-BR"
        end)

        assert.is_false(ok)
    end)
end)
