---@diagnostic disable: undefined-global

describe("public setup api", function()
    local saved_bootstrap
    local saved_init

    before_each(function()
        saved_bootstrap = package.loaded["nvim_obsidian.app.bootstrap"]
        saved_init = package.loaded["nvim_obsidian"]
    end)

    after_each(function()
        package.loaded["nvim_obsidian.app.bootstrap"] = saved_bootstrap
        package.loaded["nvim_obsidian"] = saved_init
    end)

    it("returns cached container for repeated equal setup calls", function()
        local calls = 0
        local first_container = { id = "first" }

        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                calls = calls + 1
                return first_container
            end,
        }
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        local one = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault" })
        local two = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault" })

        assert.equals(1, calls)
        assert.equals(one, two)
        assert.equals(first_container, one)
    end)

    it("restarts wiring when setup options change", function()
        local calls = 0

        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                calls = calls + 1
                return { id = calls }
            end,
        }
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        local one = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault_a" })
        local two = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault_b" })

        assert.equals(2, calls)
        assert.not_equals(one.id, two.id)
    end)
end)
