---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.insert_template")

describe("insert_template use case", function()
    local function base_ctx(overrides)
        local inserted = {}
        local render_calls = {}

        local ctx = {
            resolve_template_content = function()
                return "# {{title}}"
            end,
            fs_io = {
                read_file = function(_path)
                    return "# from-file"
                end,
            },
            template = {
                render = function(content, context)
                    table.insert(render_calls, { content = content, context = context })
                    return { rendered = "# rendered " .. context.date }
                end,
            },
            navigation = {
                insert_text_at_cursor = function(text)
                    table.insert(inserted, text)
                    return true
                end,
            },
        }

        if type(overrides) == "table" then
            for k, v in pairs(overrides) do
                ctx[k] = v
            end
        end

        ctx._inserted = inserted
        ctx._render_calls = render_calls
        return ctx
    end

    it("returns invalid_input when navigation inserter is missing", function()
        local out = use_case.execute({}, { query = "tpl.md" })

        assert.is_false(out.ok)
        assert.equals("invalid_input", out.error.code)
    end)

    it("resolves and renders template content before insertion", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, {
            query = "  templates/daily.md  ",
            now = 1700000000,
        })

        assert.is_true(out.ok)
        assert.is_true(out.inserted)
        assert.equals(1, #ctx._render_calls)
        assert.equals(1, #ctx._inserted)
        assert.matches("# rendered", ctx._inserted[1])
    end)

    it("falls back to fs read when resolver does not return content", function()
        local ctx = base_ctx({
            resolve_template_content = function()
                return nil
            end,
            template = {
                render = function(content)
                    return { rendered = content }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            query = "templates/fallback.md",
            now = 1700000000,
        })

        assert.is_true(out.ok)
        assert.equals("# from-file", ctx._inserted[1])
    end)

    it("returns not_found when no template content can be resolved", function()
        local ctx = base_ctx({
            resolve_template_content = function()
                return nil
            end,
            fs_io = {
                read_file = function()
                    return nil
                end,
            },
        })

        local out = use_case.execute(ctx, { query = "missing.md" })

        assert.is_false(out.ok)
        assert.equals("not_found", out.error.code)
    end)

    it("returns internal when insertion fails", function()
        local ctx = base_ctx({
            navigation = {
                insert_text_at_cursor = function()
                    return false, "insert-failed"
                end,
            },
        })

        local out = use_case.execute(ctx, { query = "tpl.md" })

        assert.is_false(out.ok)
        assert.equals("internal", out.error.code)
    end)
end)
