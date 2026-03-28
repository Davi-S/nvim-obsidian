---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.vault_search")

describe("vault_search use case", function()
    local function base_ctx(overrides)
        local called_payload = nil

        local ctx = {
            config = { vault_root = "vault" },
            navigation = {
                open_path = function()
                    return true
                end,
            },
            telescope = {
                open_search = function(payload)
                    called_payload = payload
                    return true
                end,
            },
        }

        if type(overrides) == "table" then
            for k, v in pairs(overrides) do
                ctx[k] = v
            end
        end

        ctx._payload = function()
            return called_payload
        end

        return ctx
    end

    it("returns invalid_input when telescope search adapter is missing", function()
        local out = use_case.execute({ telescope = {} }, {})

        assert.is_false(out.ok)
        assert.equals("invalid_input", out.error.code)
    end)

    it("passes root, query, and navigation to telescope search", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, { query = "alpha" })

        assert.is_true(out.ok)
        assert.is_true(out.selected)

        local payload = ctx._payload()
        assert.equals("vault", payload.root)
        assert.equals("alpha", payload.query)
        assert.equals(ctx.navigation, payload.navigation)
    end)

    it("returns selected=false when picker returns false", function()
        local ctx = base_ctx({
            telescope = {
                open_search = function()
                    return false
                end,
            },
        })

        local out = use_case.execute(ctx, { query = "beta" })

        assert.is_true(out.ok)
        assert.is_false(out.selected)
    end)
end)
