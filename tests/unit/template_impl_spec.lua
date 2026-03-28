---@diagnostic disable: undefined-global

local template = require("nvim_obsidian.core.domains.template.impl")

describe("template domain implementation", function()
    before_each(function()
        template._reset_for_tests()
    end)

    it("registers placeholder resolvers", function()
        local result = template.register_placeholders({
            title = function(ctx)
                return ctx.note_title
            end,
        })

        assert.is_true(result.ok)
        assert.is_nil(result.error)
    end)

    it("rejects invalid placeholder registration", function()
        local bad_name = template.register_placeholders({
            ["bad-name"] = function()
                return "x"
            end,
        })

        assert.is_false(bad_name.ok)
        assert.are.equal("invalid_input", bad_name.error.code)

        local bad_resolver = template.register_placeholders({
            title = "not-a-function",
        })

        assert.is_false(bad_resolver.ok)
        assert.are.equal("invalid_input", bad_resolver.error.code)
    end)

    it("renders registered placeholders using context", function()
        template.register_placeholders({
            title = function(ctx)
                return ctx.note_title
            end,
            date = function(ctx)
                return ctx.iso_date
            end,
        })

        local result = template.render("# {{title}}\nDate: {{date}}", {
            note_title = "Project Alpha",
            iso_date = "2026-03-28",
        })

        assert.are.equal("# Project Alpha\nDate: 2026-03-28", result.rendered)
        assert.are.same({}, result.unresolved)
    end)

    it("keeps unresolved placeholders and reports them once", function()
        template.register_placeholders({
            known = function()
                return "ok"
            end,
        })

        local result = template.render("{{known}} {{missing}} {{missing}}", {})

        assert.are.equal("ok {{missing}} {{missing}}", result.rendered)
        assert.are.same({ "missing" }, result.unresolved)
    end)

    it("treats resolver failures as unresolved", function()
        template.register_placeholders({
            unsafe = function()
                error("boom")
            end,
        })

        local result = template.render("Value: {{unsafe}}", {})

        assert.are.equal("Value: {{unsafe}}", result.rendered)
        assert.are.same({ "unsafe" }, result.unresolved)
    end)
end)
