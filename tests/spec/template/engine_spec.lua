local template = require("nvim-obsidian.template")

describe("template engine", function()
    before_each(function()
        template._reset_for_tests()
    end)

    it("renders with registered placeholder", function()
        template.register_placeholder("title", function(ctx)
            return ctx.note.title
        end)

        local ctx = template.build_context({
            cfg = { locale = "en-US" },
            title = "My Note",
            note_type = "standard",
            note_abs_path = "/vault/10 Novas notas/My Note.md",
            timestamp = os.time(),
        })

        local out = template.render("# {{title}}", ctx)
        assert.are.equal("# My Note", out)
    end)

    it("keeps unknown placeholders unchanged", function()
        local ctx = template.build_context({
            cfg = { locale = "en-US" },
            title = "My Note",
            note_type = "standard",
            note_abs_path = "/vault/10 Novas notas/My Note.md",
            timestamp = os.time(),
        })

        local out = template.render("{{unknown}}", ctx)
        assert.are.equal("{{unknown}}", out)
    end)
end)
